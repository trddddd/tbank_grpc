# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module ValueObjects
        # Денежная сумма (units + nano/10^9), одна валюта.
        # Соответствует google.type.Money: nano в [-999_999_999, 999_999_999], согласованность знаков.
        #
        # Точность: используйте {#to_d} для расчётов.
        # {#to_f} — только для отображения; возможна потеря точности.
        class Money < Base
          include ValueObjects::UnitsNano

          NANO_INT = UnitsNano::NANO_INT
          NANO_MAX = UnitsNano::NANO_MAX
          PRECISION = UnitsNano::PRECISION
          ROUNDING = UnitsNano::ROUNDING

          attr_reader :units, :nano, :currency

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
            validate!(units, nano)
            @units = units
            @nano = nano
            @currency = currency
            freeze
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
            self.class.from_decimal(result.round(PRECISION, ROUNDING), currency)
          end

          def /(other)
            result = to_d / BigDecimal(other.to_s)
            self.class.from_decimal(result.round(PRECISION, ROUNDING), currency)
          end

          # Модуль суммы (для P&L, комиссий от оборота и т.п.)
          def abs
            return self if units.positive? || (units.zero? && nano >= 0)

            self.class.new(units: -units, nano: -nano, currency: currency)
          end

          private

          def validate!(units, nano)
            unless nano.abs <= NANO_MAX
              raise ArgumentError,
                    "nano must be in [-#{NANO_MAX}, #{NANO_MAX}], got: #{nano}"
            end
            if units.positive? && nano.negative?
              raise ArgumentError,
                    "units=#{units} is positive but nano=#{nano} is negative"
            end
            return unless units.negative? && nano.positive?

            raise ArgumentError,
                  "units=#{units} is negative but nano=#{nano} is positive"
          end

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
