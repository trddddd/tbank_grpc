# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task default: [:spec]

desc 'Compile proto files'
task :compile_proto do
  # TODO: Implement proto compilation

  puts '✅ Proto compiled'
end

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/**/*_spec.rb'
  task.rspec_opts = '--color --format progress'
end
