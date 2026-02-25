# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Models
    module Core
      module ValueObjects
        # Денежная сумма (units + nano/10^9), одна валюта.
        # Соответствует google.type.Money: nano в [-999_999_999, 999_999_999], согласованность знаков.
        # Основа — Data.define (Ruby 3.2+): иммутабельно, to_h/==/hash встроены; to_h переопределён для сериализации.
        #
        # Точность: используйте {#to_d} для расчётов.
        # {#to_f} — только для отображения; возможна потеря точности.
        Money = Data.define(:units, :nano, :currency) do
          include ValueObjects::UnitsNano

          def self.from_grpc(proto)
            return unless proto

            u = (proto.units || 0).to_i
            n = (proto.nano || 0).to_i
            u, n = UnitsNano.normalize_units_nano(u, n)
            u, n = UnitsNano.apply_sign_consistency(u, n)
            new(units: u, nano: n, currency: proto.currency.to_s)
          end

          def self.from_value(value, currency)
            from_decimal(BigDecimal(value.to_s), currency.to_s)
          end

          # @param decimal [BigDecimal, Numeric] значение в полных единицах
          # @param currency [String]
          # @return [Money] значение округлено до 9 знаков (ROUND_HALF_EVEN), нормализовано
          def self.from_decimal(decimal, currency)
            units, nano = UnitsNano.parse_decimal_to_units_nano(decimal)
            new(units: units, nano: nano, currency: currency.to_s)
          end

          def self.from_string(value, currency)
            from_decimal(BigDecimal(value), currency.to_s)
          end

          def initialize(units:, nano:, currency:)
            u = units.to_i
            n = nano.to_i
            c = currency.to_s

            UnitsNano.validate_units_nano!(u, n)
            super(units: u, nano: n, currency: c)
          end

          def value
            to_f
          end

          def to_s
            currency ? "#{to_d.to_s('F')} #{currency}" : to_d.to_s('F')
          end

          def to_h(precision: nil)
            val = precision == :big_decimal ? to_d : to_f
            { value: val, currency: currency }
          end

          def inspect
            "#<#{self.class.name.split('::').last} #{self}>"
          end

          def +(other)
            case other
            when self.class
              raise ArgumentError, 'Currency mismatch' unless currency == other.currency

              add_same_class(other)
            when BigDecimal, Integer
              self.class.from_decimal(to_d + other, currency)
            else
              self.class.from_decimal(to_d + BigDecimal(other.to_s), currency)
            end
          end

          def -(other)
            case other
            when self.class
              raise ArgumentError, 'Currency mismatch' unless currency == other.currency

              subtract_same_class(other)
            when BigDecimal, Integer
              self.class.from_decimal(to_d - other, currency)
            else
              self.class.from_decimal(to_d - BigDecimal(other.to_s), currency)
            end
          end

          def *(other)
            result = to_d * BigDecimal(other.to_s)
            self.class.from_decimal(result.round(UnitsNano::PRECISION, UnitsNano::ROUNDING), currency)
          end

          def /(other)
            result = to_d / BigDecimal(other.to_s)
            self.class.from_decimal(result.round(UnitsNano::PRECISION, UnitsNano::ROUNDING), currency)
          end

          def abs
            return self if units.positive? || (units.zero? && nano >= 0)

            self.class.new(units: -units, nano: -nano, currency: currency)
          end

          private

          def add_same_class(other)
            u, n = add_units_nano(other)
            self.class.new(units: u, nano: n, currency: currency)
          end

          def subtract_same_class(other)
            u, n = subtract_units_nano(other)
            self.class.new(units: u, nano: n, currency: currency)
          end
        end
      end
    end
  end
end
