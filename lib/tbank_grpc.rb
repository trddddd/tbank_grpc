# frozen_string_literal: true

require 'grpc'
require 'zeitwerk'

require_relative 'tbank_grpc/errors'

loader = Zeitwerk::Loader.for_gem
loader.ignore(File.expand_path('tbank_grpc/errors.rb', __dir__))
loader.enable_reloading
loader.setup

module TbankGrpc
  class << self
    def loader
      LOADER
    end

    def version
      VERSION
    end

    def reload
      LOADER.reload
    end
  end
end

TbankGrpc::LOADER = loader
loader.eager_load
