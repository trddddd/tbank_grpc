# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Обновление операции из OperationsStream (OperationData).
      class OperationData < BaseModel
        grpc_simple :broker_account_id, :id, :parent_operation_id, :name, :type, :state,
                    :instrument_uid, :figi, :instrument_type, :instrument_kind,
                    :position_uid, :ticker, :class_code
        grpc_money :payment
        grpc_timestamp :date

        inspectable_attrs :id, :type, :state, :date, :payment, :figi
      end
    end
  end
end
