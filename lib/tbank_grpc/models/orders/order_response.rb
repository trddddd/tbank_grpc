# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Результат выставления/замены заявки (PostOrder / ReplaceOrder).
      class OrderResponse < BaseModel
        grpc_simple :order_id, :execution_report_status, :lots_requested, :lots_executed,
                    :figi, :direction, :order_type, :message,
                    :instrument_uid, :ticker, :class_code, :order_request_id
        grpc_money :initial_order_price, :executed_order_price, :total_order_amount,
                   :initial_commission, :executed_commission, :aci_value, :initial_security_price
        grpc_quotation :initial_order_price_pt

        inspectable_attrs :order_id, :execution_report_status, :lots_requested, :lots_executed, :order_request_id
      end
    end
  end
end
