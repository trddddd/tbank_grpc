# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Предварительная стоимость заявки (GetOrderPrice).
      class OrderPrice < BaseModel
        grpc_simple :lots_requested
        grpc_money :total_order_amount, :initial_order_amount, :executed_commission,
                   :executed_commission_rub, :service_commission, :deal_commission
        serializable_attr :extra_bond, :extra_future

        inspectable_attrs :lots_requested, :total_order_amount, :executed_commission

        # Дополнительные поля для облигаций.
        #
        # @return [Hash]
        def extra_bond
          bond = @pb&.extra_bond
          return {} unless bond

          {
            aci_value: Core::ValueObjects::Money.from_grpc(bond.aci_value),
            nominal_conversion_rate: Core::ValueObjects::Quotation.from_grpc(bond.nominal_conversion_rate)
          }.compact
        end

        # Дополнительные поля для фьючерсов.
        #
        # @return [Hash]
        def extra_future
          future = @pb&.extra_future
          return {} unless future

          {
            initial_margin: Core::ValueObjects::Money.from_grpc(future.initial_margin)
          }.compact
        end
      end
    end
  end
end
