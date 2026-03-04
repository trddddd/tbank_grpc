# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Результат отмены заявки (CancelOrder).
      class CancelOrderResponse < BaseModel
        grpc_timestamp :time

        inspectable_attrs :time
      end
    end
  end
end
