# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Модель фьючерса.
      #
      # Может возвращаться как конкретный тип при FutureBy, Futures, GetInstrumentBy.
      # @see Instrument базовые поля
      class Future < Instrument
        grpc_simple :futures_type, :asset_type, :basic_asset, :sector, :country_of_risk,
                    :country_of_risk_name, :basic_asset_position_uid
        grpc_money :initial_margin_on_buy, :initial_margin_on_sell
        grpc_quotation :basic_asset_size, :min_price_increment_amount, :dlong_client, :dshort_client
        grpc_timestamp :expiration_date, :first_trade_date, :last_trade_date,
                       :first_1min_candle_date, :first_1day_candle_date

        inspectable_attrs :futures_type, :expiration_date, :basic_asset_size
      end
    end
  end
end
