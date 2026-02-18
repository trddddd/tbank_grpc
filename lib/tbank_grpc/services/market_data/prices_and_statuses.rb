# frozen_string_literal: true

module TbankGrpc
  module Services
    module MarketData
      # Цены последних сделок.
      module PricesAndStatuses
        # Цены последних сделок по инструментам. GetLastPrices. instrument_id — строка или массив.
        #
        # @param instrument_id [String, Array<String>]
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::MarketData::LastPrice>, Response]
        # @raise [TbankGrpc::Error]
        def get_last_prices(instrument_id:, return_metadata: false)
          ids = resolve_instrument_ids(instrument_id: instrument_id)

          handle_request(method_name: 'MarketDataService/GetLastPrices',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::GetLastPricesRequest.new(instrument_id: ids)

            response = call_rpc(@stub, :get_last_prices, request, return_metadata: return_op)
            next response if return_metadata

            response.last_prices.map { |lp| Models::MarketData::LastPrice.from_grpc(lp) }
          end
        end
      end
    end
  end
end
