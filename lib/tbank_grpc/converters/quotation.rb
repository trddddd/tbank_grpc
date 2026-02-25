# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Преобразование proto Quotation ↔ Float/BigDecimal/Ruby-типы для запросов и ответов.
    module Quotation
      # @param quotation [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil]
      # @return [Float, nil] units + nano/1e9 или nil
      def self.to_f(quotation)
        return unless quotation

        UnitsNano.to_f(quotation.units, quotation.nano)
      end

      # @param quotation [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil]
      # @return [BigDecimal]
      def self.to_decimal(quotation)
        return BigDecimal('0') unless quotation

        UnitsNano.to_decimal(quotation.units, quotation.nano)
      end

      # @param decimal [BigDecimal, Numeric, String]
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::Quotation]
      def self.decimal_to_pb(decimal)
        Tinkoff::Public::Invest::Api::Contract::V1::Quotation.new(**UnitsNano.from_decimal(decimal))
      end

      # Нормализует любое значение в proto Quotation (для запросов).
      # Принимает: nil, proto Quotation, Models::Core::ValueObjects::Quotation, Numeric/String.
      #
      # @param value [Tinkoff::Public::Invest::Api::Contract::V1::Quotation,
      #   Models::Core::ValueObjects::Quotation, Numeric, String, nil]
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil]
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
    end
  end
end
