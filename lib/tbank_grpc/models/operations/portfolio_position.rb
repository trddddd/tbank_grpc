# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Позиция в портфеле (PortfolioPosition из GetPortfolio / PortfolioStream).
      class PortfolioPosition < BaseModel
        grpc_simple :figi, :instrument_type, :position_uid, :instrument_uid, :ticker, :class_code, :blocked
        grpc_money :average_position_price, :current_nkd, :current_price,
                   :average_position_price_fifo, :var_margin, :daily_yield
        grpc_quotation :quantity, :expected_yield, :blocked_lots, :expected_yield_fifo

        inspectable_attrs :figi, :instrument_type, :ticker, :quantity, :current_price
      end
    end
  end
end
