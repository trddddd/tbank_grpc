# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Последняя цена инструмента из ответа GetLastPrices или стрима.
      #
      # @see BaseModel атрибуты и from_grpc
      class LastPrice < BaseModel
        grpc_simple :figi, :instrument_uid, :ticker, :class_code, :last_price_type
        grpc_quotation :price
        grpc_timestamp :time

        inspectable_attrs :figi, :ticker, :class_code, :price, :time, :last_price_type
      end
    end
  end
end
