# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Размер гарантийного обеспечения фьючерса (`GetFuturesMargin`).
      class FuturesMargin < BaseModel
        grpc_money :initial_margin_on_buy, :initial_margin_on_sell
        grpc_quotation :min_price_increment, :min_price_increment_amount

        inspectable_attrs :initial_margin_on_buy, :initial_margin_on_sell,
                          :min_price_increment, :min_price_increment_amount
      end
    end
  end
end
