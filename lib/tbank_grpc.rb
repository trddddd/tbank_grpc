# frozen_string_literal: true

require 'grpc'
require 'zeitwerk'

require_relative 'tbank_grpc/errors'

loader = Zeitwerk::Loader.for_gem
loader.ignore(File.expand_path('tbank_grpc/errors.rb', __dir__))
loader.setup

module TbankGrpc
  class << self
    def version
      VERSION
    end
  end
end

loader.eager_load
