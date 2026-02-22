# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Событие дивидендной выплаты (`GetDividends`).
      class Dividend < BaseModel
        grpc_simple :dividend_type, :regularity
        grpc_money :dividend_net, :close_price
        grpc_quotation :yield_value
        grpc_timestamp :payment_date, :declared_date, :last_buy_date, :record_date, :created_at

        inspectable_attrs :dividend_net, :payment_date, :record_date, :dividend_type, :yield_value
      end
    end
  end
end
