# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Преобразование proto Quotation ↔ Float/BigDecimal/Ruby-типы для запросов и ответов.
    #
    # В API T-Bank Invest числа с дробной частью передаются как Quotation (units + nano).
    # Используется для цен, комиссий, курсов и других десятичных значений в контрактах.
    #
    # @see TbankGrpc::Models::Core::ValueObjects::Quotation value object для моделей ответов
    # @see https://developer.tbank.ru/invest/intro/intro/faq_custom_types Quotation в контрактах
    module Quotation
      # Преобразует proto Quotation в Float (units + nano/1e9).
      #
      # @param quotation [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil]
      # @return [Float, nil] число или nil при nil
      # @example
      #   Quotation.to_f(response.price_quote)  # => 123.45
      def self.to_f(quotation)
        return unless quotation

        UnitsNano.to_f(quotation.units, quotation.nano)
      end

      # Преобразует proto Quotation в BigDecimal (для точных расчётов).
      #
      # @param quotation [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil]
      # @return [BigDecimal] при nil возвращает 0
      # @example
      #   Quotation.to_decimal(quote)  # => #<BigDecimal:...>
      def self.to_decimal(quotation)
        return BigDecimal('0') unless quotation

        UnitsNano.to_decimal(quotation.units, quotation.nano)
      end

      # Собирает proto Quotation из десятичного числа (для исходящих запросов).
      #
      # @param decimal [BigDecimal, Numeric, String]
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::Quotation]
      # @example
      #   Quotation.decimal_to_pb(100.5)  # => Quotation(units: 100, nano: 500_000_000)
      def self.decimal_to_pb(decimal)
        Tinkoff::Public::Invest::Api::Contract::V1::Quotation.new(**UnitsNano.from_decimal(decimal))
      end

      # Нормализует любое значение в proto Quotation (для запросов).
      # Принимает: nil, proto Quotation, ValueObjects::Quotation, Numeric/String.
      #
      # @param value [Tinkoff::Public::Invest::Api::Contract::V1::Quotation,
      #   TbankGrpc::Models::Core::ValueObjects::Quotation, Numeric, String, nil]
      # @return [Tinkoff::Public::Invest::Api::Contract::V1::Quotation, nil] nil только если value nil
      # @example proto — возвращается как есть
      #   Quotation.to_pb(grpc_quotation)  # => тот же объект
      # @example Numeric/String — конвертация через BigDecimal
      #   Quotation.to_pb(99.99)   # => Quotation(units: 99, nano: 990_000_000)
      #   Quotation.to_pb("0.01")  # => Quotation(units: 0, nano: 10_000_000)
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
