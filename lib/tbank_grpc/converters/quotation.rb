# frozen_string_literal: true

module TbankGrpc
  module Converters
    module Quotation
      def self.to_f(quotation)
        return unless quotation

        (quotation.units || 0) + ((quotation.nano || 0) / Constants::NANO_DIVISOR)
      end

      def self.to_decimal(quotation)
        return BigDecimal('0') unless quotation

        BigDecimal(quotation.units || 0) + (BigDecimal(quotation.nano || 0) / Constants::NANO_DIVISOR_BD)
      end

      def self.decimal_to_pb(decimal)
        d = BigDecimal(decimal.to_s)
        units = d.to_i
        nano = ((d - units) * Constants::NANO_DIVISOR_BD).to_i
        Tinkoff::Public::Invest::Api::Contract::V1::Quotation.new(units: units, nano: nano)
      end

      # Нормализует любое значение в proto Quotation (для запросов).
      # Принимает: nil, proto Quotation, Models::Core::ValueObjects::Quotation, Numeric/String.
      def self.to_pb(value)
        return if value.nil?
        return value if value.is_a?(Tinkoff::Public::Invest::Api::Contract::V1::Quotation)

        if value.is_a?(Models::Core::ValueObjects::Quotation)
          return Tinkoff::Public::Invest::Api::Contract::V1::Quotation.new(
            units: value.units,
            nano: value.nano
          )
        end

        decimal_to_pb(BigDecimal(value.to_s))
      end

      def self.to_floats(quotations)
        return [] unless quotations

        quotations.map { |q| to_f(q) }
      end

      def self.to_decimals(quotations)
        return [] unless quotations

        quotations.map { |q| to_decimal(q) }
      end
    end
  end
end
