# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Models
    module Core
      module ValueObjects
        # Общая логика для типов units + nano/10^9 (google.type.Money, Quotation).
        # Включается в Money и Quotation.
        module UnitsNano
          NANO_DIVISOR = 1_000_000_000.0
          NANO_BD = BigDecimal('1000000000')
          NANO_INT = 1_000_000_000
          NANO_MAX = 999_999_999
          PRECISION = 9
          ROUNDING = BigDecimal::ROUND_HALF_EVEN

          class << self
            # Нормализация units/nano: nano в [-999_999_999, 999_999_999], перенос переполнения в units
            def normalize_units_nano(units, nano)
              u = units.to_i
              n = nano.to_i
              while n >= NANO_INT
                u += 1
                n -= NANO_INT
              end
              while n <= -NANO_INT
                u -= 1
                n += NANO_INT
              end
              [u, n]
            end

            # Округлённые units и nano из decimal (для from_decimal в подклассах)
            def parse_decimal_to_units_nano(decimal)
              d = BigDecimal(decimal.to_s).round(PRECISION, ROUNDING)
              units = d.to_i
              nano = ((d - units) * NANO_BD).to_i
              normalize_units_nano(units, nano)
            end

            # Согласование знаков units/nano (google.type.Money)
            def apply_sign_consistency(units, nano)
              units = units.to_i
              nano = nano.to_i
              if units.positive? && nano.negative?
                units -= 1
                nano += NANO_INT
              elsif units.negative? && nano.positive?
                units += 1
                nano -= NANO_INT
              end
              [units, nano]
            end
          end

          # @deprecated Use {#to_d} for calculations; to_f может терять точность
          def to_f
            units.to_f + (nano / NANO_DIVISOR)
          end

          # @return [BigDecimal] точное значение для расчётов
          def to_d
            BigDecimal(units) + (BigDecimal(nano) / NANO_BD)
          end

          private

          def apply_sign_consistency(units, nano)
            UnitsNano.apply_sign_consistency(units, nano)
          end

          def add_units_nano(other)
            normalized_units, normalized_nano = UnitsNano.normalize_units_nano(units + other.units, nano + other.nano)
            UnitsNano.apply_sign_consistency(normalized_units, normalized_nano)
          end

          def subtract_units_nano(other)
            normalized_units, normalized_nano = UnitsNano.normalize_units_nano(units - other.units, nano - other.nano)
            UnitsNano.apply_sign_consistency(normalized_units, normalized_nano)
          end
        end
      end
    end
  end
end
