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
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetLastPricesRequest.new(instrument_id: ids)
          execute_list_rpc(
            method_name: :get_last_prices,
            request: request,
            response_collection: :last_prices,
            model_class: Models::MarketData::LastPrice,
            return_metadata: return_metadata
          )
        end
      end
    end
  end
end
