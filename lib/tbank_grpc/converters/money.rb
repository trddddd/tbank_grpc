# frozen_string_literal: true

module TbankGrpc
  module Converters
    module Money
      def self.to_f(money_value)
        return unless money_value

        (money_value.units || 0) + ((money_value.nano || 0) / Constants::NANO_DIVISOR)
      end

      def self.to_decimal(money_value)
        return BigDecimal('0') unless money_value

        BigDecimal(money_value.units || 0) + (BigDecimal(money_value.nano || 0) / Constants::NANO_DIVISOR_BD)
      end

      def self.decimal_to_pb(decimal, currency)
        d = BigDecimal(decimal.to_s)
        units = d.to_i
        nano = ((d - units) * Constants::NANO_DIVISOR_BD).to_i
        Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue.new(currency: currency.to_s, units: units, nano: nano)
      end

      # Нормализует любое значение в proto MoneyValue (для запросов).
      # Принимает: nil, proto MoneyValue, Models::Core::ValueObjects::Money, Numeric/String (требуется currency).
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
