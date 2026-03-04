# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Состояние заявки из GetOrderState / GetOrders.
      class OrderState < BaseModel
        grpc_simple :order_id, :execution_report_status, :lots_requested, :lots_executed,
                    :figi, :direction, :currency, :order_type,
                    :instrument_uid, :order_request_id, :ticker, :class_code
        grpc_money :initial_order_price, :executed_order_price, :total_order_amount,
                   :average_position_price, :initial_commission, :executed_commission,
                   :initial_security_price, :service_commission
        grpc_timestamp :order_date
        serializable_attr :stages

        inspectable_attrs :order_id, :ticker, :direction, :order_type, :execution_report_status, :lots_requested, :lots_executed,
                          :initial_order_price, :order_date

        # Этапы исполнения заявки.
        #
        # @return [Array<Hash>]
        def stages
          @stages ||= Array(@pb&.stages).map { |stage| stage_to_h(stage) }
        end

        private

        def stage_to_h(stage)
          {
            price: Core::ValueObjects::Money.from_grpc(stage.price),
            quantity: stage.quantity,
            trade_id: stage.trade_id,
            execution_time: stage.execution_time ? timestamp_to_time(stage.execution_time) : nil
          }.compact
        end
      end
    end
  end
end
