# frozen_string_literal: true

require_relative 'lib/tbank_grpc/version'

Gem::Specification.new do |spec|
  spec.name = 'tbank_grpc'
  spec.version = TbankGrpc::VERSION
  spec.authors = ['Roman Kirpichnikov']
  spec.email = []

  spec.summary = 'T-Bank Invest API gRPC Ruby Client'
  spec.description = 'Ruby client for T-Bank Invest API (formerly Tinkoff Invest) using gRPC. ' \
                     'Provides access to trading operations, market data, and portfolio management.'
  spec.homepage = 'https://github.com/trddddd/tbank_grpc'
  spec.license = 'MIT'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues"
  }

  spec.files = Dir['lib/**/*', 'proto/**/*', 'bin/**/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0.0'

  spec.add_dependency 'google-protobuf', '~> 3.24'
  spec.add_dependency 'grpc', '~> 1.60'
  spec.add_dependency 'semantic_logger', '~> 4.13'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'grpc-tools', '~> 1.60'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-mocks', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'vcr', '~> 6.1'
  spec.add_development_dependency 'webmock', '~> 3.19'
end
