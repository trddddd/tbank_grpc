# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Преобразование proto MoneyValue ↔ Float/BigDecimal/Ruby-типы для запросов и ответов.
    module Money
      # @param money_value [Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue, nil]
      # @return [Float, nil] units + nano/1e9 или nil
      def self.to_f(money_value)
        return unless money_value

        UnitsNano.to_f(money_value.units, money_value.nano)
      end

      # Публичный API: преобразование proto MoneyValue → BigDecimal для точных расчётов.
      # Используйте вместо to_f, когда нужна фиксированная точность (например, суммы, комиссии).
      #
      # @param money_value [Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue, nil]
      # @return [BigDecimal]
      def self.to_decimal(money_value)
        return BigDecimal('0') unless money_value

        UnitsNano.to_decimal(money_value.units, money_value.nano)
      end

      # @param decimal [BigDecimal, Numeric, String]
      # @param currency [String, Symbol]
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue]
      def self.decimal_to_pb(decimal, currency)
        Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue.new(
          currency: currency.to_s,
          **UnitsNano.from_decimal(decimal)
        )
      end

      # Нормализует любое значение в proto MoneyValue (для запросов).
      # Принимает: nil, proto MoneyValue, Models::Core::ValueObjects::Money, Numeric/String (требуется currency).
      #
      # @param value [Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue,
      #   Models::Core::ValueObjects::Money, Numeric, String, nil]
      # @param currency [String, Symbol, nil] обязателен, если value — Numeric/String
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue, nil]
      def self.to_pb(value, currency: nil)
        return if value.nil?
        return value if value.is_a?(Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue)

        if value.is_a?(Models::Core::ValueObjects::Money)
          return Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue.new(
            units: value.units,
            nano: value.nano,
            currency: value.currency || currency.to_s
          )
        end

        raise ArgumentError, 'currency required when amount is numeric' if currency.to_s.empty?

        decimal_to_pb(BigDecimal(value.to_s), currency.to_s)
      end
    end
  end
end
