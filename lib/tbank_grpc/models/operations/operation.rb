# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Одна операция из GetOperations (покупка, продажа, вывод и т.д.).
      class Operation < BaseModel
        grpc_simple :id, :parent_operation_id, :currency, :state, :quantity, :quantity_rest,
                    :figi, :instrument_type, :type, :operation_type,
                    :asset_uid, :position_uid, :instrument_uid
        grpc_money :payment, :price
        grpc_timestamp :date
        serializable_attr :trades

        inspectable_attrs :id, :type, :state, :date, :payment, :figi

        # Сделки по операции (лениво).
        #
        # @return [Array<Hash>]
        def trades
          @trades ||= Array(@pb&.trades).map { |t| trade_to_h(t) }
        end

        private

        def trade_to_h(trade)
          {
            trade_id: trade.trade_id,
            date_time: trade.date_time ? timestamp_to_time(trade.date_time) : nil,
            quantity: trade.quantity,
            price: trade.price ? Core::ValueObjects::Money.from_grpc(trade.price) : nil
          }.compact
        end
      end
    end
  end
end
