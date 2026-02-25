# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Торговый статус инструмента из MarketData stream или GetTradingStatus.
      #
      # @see BaseModel атрибуты и from_grpc
      class TradingStatus < BaseModel
        grpc_simple :figi, :instrument_uid, :ticker, :class_code, :trading_status,
                    :limit_order_available_flag, :market_order_available_flag,
                    :api_trade_available_flag, :bestprice_order_available_flag, :only_best_price
        grpc_timestamp :time

        inspectable_attrs :figi, :ticker, :trading_status,
                          :limit_order_available_flag, :market_order_available_flag
      end
    end
  end
end
