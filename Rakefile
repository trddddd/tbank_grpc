# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'fileutils'
require 'net/http'
require 'uri'

task default: [:spec]

PROTO_BASE_URL = 'https://opensource.tbank.ru/invest/invest-contracts/-/raw/master/src/docs/contracts'
PROTO_ROOT = File.expand_path('proto', __dir__)
PROTO_DIR = PROTO_ROOT
PROTO_FILES = %w[
  common.proto marketdata.proto instruments.proto users.proto
  operations.proto orders.proto stoporders.proto sandbox.proto signals.proto
].freeze

# Версия из репозитория TBank для консистентности с их контрактами
GOOGLE_API_FIELD_BEHAVIOR_URL = 'https://opensource.tbank.ru/invest/invest-contracts/-/raw/master/src/docs/contracts/google/api/field_behavior.proto'
PROTO_OUTPUT_DIR = ENV.fetch('OUTPUT_DIR', File.expand_path('lib/tbank_grpc/proto', __dir__))

def download_file(url, path, timeout: 30)
  uri = URI.parse(url)
  response = Net::HTTP.start(uri.host, uri.port,
                             use_ssl: uri.scheme == 'https',
                             read_timeout: timeout,
                             open_timeout: timeout) do |http|
    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

  File.write(path, response.body)
end

desc 'Download proto files from TBank invest-contracts'
task :download_proto do
  google_api_dir = File.join(PROTO_ROOT, 'google', 'api')

  FileUtils.mkdir_p(google_api_dir)

  puts 'TbankGrpc: downloading proto from opensource.tbank.ru/invest/invest-contracts'
  success = true

  PROTO_FILES.each do |filename|
    url = "#{PROTO_BASE_URL}/#{filename}"
    path = File.join(PROTO_DIR, filename)

    print "  #{filename}... "

    begin
      download_file(url, path)
      puts 'OK'
    rescue StandardError => e
      puts "FAILED: #{e.message}"
      success = false
    end
  end

  print '  google/api/field_behavior.proto... '

  begin
    download_file(GOOGLE_API_FIELD_BEHAVIOR_URL, File.join(google_api_dir, 'field_behavior.proto'))
    puts 'OK'
  rescue StandardError => e
    puts "FAILED: #{e.message}"
    success = false
  end

  unless success
    puts 'Some downloads failed.'
    exit 1
  end

  puts 'Done. Run: bundle exec rake compile_proto'
end

desc 'Check if grpc_tools_ruby_protoc is available'
task :check_protoc do
  unless system('which grpc_tools_ruby_protoc > /dev/null 2>&1')
    puts 'ERROR: grpc_tools_ruby_protoc not found.'
    puts 'Install: gem install grpc-tools'
    exit 1
  end
end

desc 'Compile proto files (requires grpc_tools_ruby_protoc)'
task compile_proto: :check_protoc do
  output_dir = PROTO_OUTPUT_DIR
  FileUtils.mkdir_p(output_dir)

  proto_files = Dir.glob("#{PROTO_DIR}/*.proto")

  if proto_files.empty?
    puts "No proto files in #{PROTO_DIR}. Run: bundle exec rake download_proto"

    exit 1
  end

  proto_files.each do |proto_file|
    puts "Compiling #{File.basename(proto_file)}..."

    system(
      'grpc_tools_ruby_protoc',
      '-I', PROTO_DIR,
      '--ruby_out', output_dir,
      '--grpc_out', output_dir,
      proto_file
    ) || raise("Failed to compile #{proto_file}")
  end

  puts 'Proto compiled successfully.'
end

desc 'Clean generated proto Ruby files'
task :clean_proto do
  Dir.glob("#{PROTO_OUTPUT_DIR}/*_pb.rb").each { |f| FileUtils.rm_f(f) }
  puts 'Cleaned generated proto files.'
end

desc 'Autoupdate proto'
task autoupdate_proto: %i[clean_proto download_proto compile_proto check_protoc]

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/**/*_spec.rb'
  task.rspec_opts = '--color --format progress'
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new(:doc)
rescue LoadError
  desc 'Generate YARD documentation (requires yard gem)'
  task :doc do
    abort 'yard is not installed. Run: bundle install'
  end
end
