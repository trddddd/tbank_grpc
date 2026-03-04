# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Событие состояния заявки из OrderStateStream.
      class OrderStreamState < BaseModel
        grpc_simple :order_id, :order_request_id, :client_code, :execution_report_status, :status_info,
                    :ticker, :class_code, :lot_size, :direction, :time_in_force, :order_type,
                    :account_id, :trade_order_id, :currency,
                    :lots_requested, :lots_executed, :lots_left, :lots_cancelled,
                    :marker, :exchange, :instrument_uid
        grpc_timestamp :created_at, :completion_time
        grpc_money :initial_order_price, :order_price, :amount, :executed_order_price
        serializable_attr :trades

        inspectable_attrs :order_id, :execution_report_status, :account_id, :lots_requested, :lots_executed, :lots_left

        # Исполнения, пришедшие в событии.
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
