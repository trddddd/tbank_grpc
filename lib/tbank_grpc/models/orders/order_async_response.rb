# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Результат асинхронного выставления заявки (PostOrderAsync).
      class OrderAsyncResponse < BaseModel
        grpc_simple :order_request_id, :execution_report_status, :trade_intent_id

        inspectable_attrs :order_request_id, :execution_report_status, :trade_intent_id
      end
    end
  end
end
