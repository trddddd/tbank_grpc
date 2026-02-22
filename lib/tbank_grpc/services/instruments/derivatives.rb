# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Методы по деривативам.
      module Derivatives
        # Размер гарантийного обеспечения по фьючерсу. GetFuturesMargin.
        #
        # @param instrument_id [String] UID/FIGI/другой `instrument_id` фьючерса
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Instruments::FuturesMargin, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_futures_margin(instrument_id:, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetFuturesMarginRequest.new(
            instrument_id: instrument_id
          )
          execute_rpc(method_name: :get_futures_margin, request: request,
                      return_metadata: return_metadata) do |response|
            Models::Instruments::FuturesMargin.from_grpc(response)
          end
        end
      end
    end
  end
end
