# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Пакет сделок по заявке из TradesStream.
      class OrderTrades < BaseModel
        grpc_simple :order_id, :direction, :figi, :account_id, :instrument_uid
        grpc_timestamp :created_at
        serializable_attr :trades

        inspectable_attrs :order_id, :direction, :account_id, :trades

        # Список сделок в пакете.
        #
        # @return [Array<Hash>]
        def trades
          @trades ||= Array(@pb&.trades).map { |trade| trade_to_h(trade) }
        end

        private

        def trade_to_h(trade)
          {
            date_time: trade.date_time ? timestamp_to_time(trade.date_time) : nil,
            price: Core::ValueObjects::Quotation.from_grpc(trade.price),
            quantity: trade.quantity,
            trade_id: trade.trade_id
          }.compact
        end
      end
    end
  end
end
