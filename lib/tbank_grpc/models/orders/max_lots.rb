# frozen_string_literal: true

module TbankGrpc
  module Models
    module Orders
      # Лимиты доступных лотов для покупки/продажи из GetMaxLots.
      class MaxLots < BaseModel
        # Вложенная модель buy-limits view.
        class BuyLimitsView < BaseModel
          grpc_quotation :buy_money_amount
          grpc_simple :buy_max_lots, :buy_max_market_lots

          inspectable_attrs :buy_max_lots, :buy_max_market_lots
        end

        # Вложенная модель sell-limits view.
        class SellLimitsView < BaseModel
          grpc_simple :sell_max_lots

          inspectable_attrs :sell_max_lots
        end

        grpc_simple :currency
        serializable_attr :buy_limits, :buy_margin_limits, :sell_limits, :sell_margin_limits,
                          :buy_available_lots, :buy_available_market_lots,
                          :buy_available_margin_lots, :buy_available_margin_market_lots,
                          :sell_available_lots, :sell_available_margin_lots

        inspectable_attrs :currency, :buy_available_lots, :sell_available_lots

        def buy_limits
          @buy_limits ||= build_buy_limits(@pb&.buy_limits)
        end

        def buy_margin_limits
          @buy_margin_limits ||= build_buy_limits(@pb&.buy_margin_limits)
        end

        def sell_limits
          @sell_limits ||= build_sell_limits(@pb&.sell_limits)
        end

        def sell_margin_limits
          @sell_margin_limits ||= build_sell_limits(@pb&.sell_margin_limits)
        end

        # Совместимость с существующим ручным сценарием.
        def buy_limits_response
          buy_limits
        end

        # Совместимость с существующим ручным сценарием.
        def sell_limits_response
          sell_limits
        end

        # Совместимость с существующим ручным сценарием.
        def buy_margin_limits_response
          buy_margin_limits
        end

        # Совместимость с существующим ручным сценарием.
        def sell_margin_limits_response
          sell_margin_limits
        end

        def buy_available_lots
          buy_limits&.buy_max_lots
        end

        def buy_available_market_lots
          buy_limits&.buy_max_market_lots
        end

        def buy_available_margin_lots
          buy_margin_limits&.buy_max_lots
        end

        def buy_available_margin_market_lots
          buy_margin_limits&.buy_max_market_lots
        end

        def sell_available_lots
          sell_limits&.sell_max_lots
        end

        def sell_available_margin_lots
          sell_margin_limits&.sell_max_lots
        end

        private

        def build_buy_limits(proto)
          proto ? BuyLimitsView.from_grpc(proto) : nil
        end

        def build_sell_limits(proto)
          proto ? SellLimitsView.from_grpc(proto) : nil
        end
      end
    end
  end
end
