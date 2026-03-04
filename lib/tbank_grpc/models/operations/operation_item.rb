# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Элемент ответа GetOperationsByCursor (OperationItem).
      class OperationItem < BaseModel
        grpc_simple :cursor, :broker_account_id, :id, :parent_operation_id, :name, :type,
                    :description, :state, :instrument_uid, :figi, :instrument_type,
                    :instrument_kind, :position_uid, :ticker, :class_code,
                    :quantity, :quantity_rest, :quantity_done, :cancel_reason, :asset_uid
        grpc_timestamp :date, :cancel_date_time
        grpc_money :payment, :price, :commission, :yield, :accrued_int
        grpc_quotation :yield_relative
        serializable_attr :trades, :child_operations

        inspectable_attrs :id, :type, :state, :date, :payment, :figi

        # Сделки по операции курсора.
        #
        # @return [Array<Hash>]
        def trades
          operation_trades = @pb&.trades_info
          return [] unless operation_trades

          @trades ||= Array(operation_trades.trades).map { |trade| trade_to_h(trade) }
        end

        # Дочерние операции.
        #
        # @return [Array<Hash>]
        def child_operations
          @child_operations ||= Array(@pb&.child_operations).map { |item| child_operation_to_h(item) }
        end

        private

        def trade_to_h(trade)
          {
            num: trade.num,
            date: trade.date ? timestamp_to_time(trade.date) : nil,
            quantity: trade.quantity,
            price: Core::ValueObjects::Money.from_grpc(trade.price),
            yield: Core::ValueObjects::Money.from_grpc(trade.yield),
            yield_relative: Core::ValueObjects::Quotation.from_grpc(trade.yield_relative)
          }.compact
        end

        def child_operation_to_h(item)
          {
            instrument_uid: item.instrument_uid,
            payment: Core::ValueObjects::Money.from_grpc(item.payment)
          }.compact
        end
      end
    end
  end
end
