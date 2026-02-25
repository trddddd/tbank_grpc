# frozen_string_literal: true

module TbankGrpc
  module Grpc
    # Формирование полного имени RPC "ServiceName/MethodName" из stub и имени метода.
    # Используется для deadline_overrides, логов, rate limit.
    # @api private
    module MethodName
      # @param stub [Object] gRPC stub (класс вида ...::ServiceName::Stub)
      # @param rpc_method [Symbol, String] имя RPC в snake_case (например :get_asset_by, :market_data_stream)
      # @return [String] "ServiceName/MethodCamelCase", например "InstrumentsService/GetAssetBy"
      def self.full_name(stub, rpc_method)
        service_short = stub.class.name.split('::')[-2]
        method_camel = rpc_method.to_s.split('_').map(&:capitalize).join
        "#{service_short}/#{method_camel}"
      end
    end
  end
end
