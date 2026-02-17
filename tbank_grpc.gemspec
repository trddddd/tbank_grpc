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
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*', 'proto/**/*', 'bin/**/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0.0'

  spec.add_dependency 'bigdecimal', '>= 3.0'
  spec.add_dependency 'google-protobuf', '~> 3.24'
  spec.add_dependency 'grpc', '~> 1.60'
  spec.add_dependency 'logger', '~> 1.5'
  spec.add_dependency 'zeitwerk', '~> 2.6'
end
