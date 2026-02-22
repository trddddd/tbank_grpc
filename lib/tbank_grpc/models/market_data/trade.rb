# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Обезличенная сделка из MarketData stream или GetLastTrades.
      #
      # @see BaseModel атрибуты и from_grpc
      class Trade < BaseModel
        grpc_simple :figi, :instrument_uid, :ticker, :class_code, :direction, :trade_source, :quantity
        grpc_quotation :price
        grpc_timestamp :time

        inspectable_attrs :figi, :ticker, :direction, :price, :quantity, :time, :trade_source
      end
    end
  end
end
