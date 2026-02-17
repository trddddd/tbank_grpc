# frozen_string_literal: true

require 'grpc'
require 'zeitwerk'

require_relative 'tbank_grpc/errors'
require_relative 'tbank_grpc/proto/common_pb'

loader = Zeitwerk::Loader.for_gem
loader.ignore(File.expand_path('tbank_grpc/errors.rb', __dir__))
loader.ignore(File.expand_path('tbank_grpc/proto', __dir__))

loader.enable_reloading
loader.setup

# Клиент и конфигурация для T-Bank Invest API (gRPC).
#
# @see https://developer.tbank.ru/invest/api
module TbankGrpc
  class << self
    # @return [Zeitwerk::Loader] загрузчик автолоада гема
    def loader
      LOADER
    end

    # @return [String] версия гема (SemVer)
    def version
      VERSION
    end

    # Перезагружает константы гема (удобно при разработке).
    # @return [void]
    def reload
      LOADER.reload
    end
  end
end

TbankGrpc::LOADER = loader
loader.eager_load
