# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module ValueObjects
        # Котировка/число с фиксированной точностью (units + nano/10^9).
        # Для цен и объёмов в стакане; валидация nano и sign consistency как у google.type.Money.
        # Основа — Data.define (Ruby 3.2+): иммутабельно, to_h/==/hash встроены.
        # Сырые members: { units:, nano: } — через deconstruct_keys([:units, :nano]).
        #
        # Точность: используйте {#to_d} для расчётов.
        # {#to_f} — только для отображения; возможна потеря точности.
        Quotation = Data.define(:units, :nano) do
          include Comparable
          include ValueObjects::UnitsNano

          # Явно делегируем в семантику Data (сравнение по members), чтобы не полагаться на MRO с Comparable#==
          def ==(other)
            other.is_a?(self.class) && units == other.units && nano == other.nano
          end

          def self.from_grpc(proto)
            return unless proto

            u = (proto.units || 0).to_i
            n = (proto.nano || 0).to_i
            u, n = UnitsNano.normalize_units_nano(u, n)
            u, n = UnitsNano.apply_sign_consistency(u, n)
            new(units: u, nano: n)
          end

          # @param decimal [BigDecimal, Numeric]
          # @return [Quotation] значение округлено до 9 знаков (ROUND_HALF_EVEN)
          def self.from_decimal(decimal)
            units, nano = UnitsNano.parse_decimal_to_units_nano(decimal)
            new(units: units, nano: nano)
          end

          def initialize(units: 0, nano: 0)
            u = units.to_i
            n = nano.to_i

            UnitsNano.validate_units_nano!(u, n)
            super(units: u, nano: n)
          end

          def to_s
            to_d.to_s('F')
          end

          # Единообразный интерфейс с Money: { value: Float|BigDecimal }.
          # precision: :big_decimal — value как BigDecimal, иначе to_f.
          def to_h(precision: nil)
            val = precision == :big_decimal ? to_d : to_f
            { value: val }
          end

          def inspect
            "#<#{self.class.name.split('::').last} #{self}>"
          end

          def <=>(other)
            return nil unless other.is_a?(self.class)

            cmp = units <=> other.units
            return cmp unless cmp&.zero?

            nano <=> other.nano
          end

          def positive?
            units.positive? || (units.zero? && nano.positive?)
          end

          def negative?
            units.negative? || (units.zero? && nano.negative?)
          end

          def zero?
            units.zero? && nano.zero?
          end

          def abs
            return self if positive? || zero?

            self.class.new(units: -units, nano: -nano)
          end

          # Округление до шага цены (tick_size), например 0.01 для акций MOEX
          # @param tick_size_decimal [BigDecimal, Numeric]
          # @return [Quotation]
          def round_to_tick(tick_size_decimal)
            tick = BigDecimal(tick_size_decimal.to_s)
            ticks = (to_d / tick).round(0, UnitsNano::ROUNDING)
            self.class.from_decimal(ticks * tick)
          end

          def +(other)
            case other
            when self.class
              add_same_class(other)
            else
              val = other.respond_to?(:to_d) ? other.to_d : BigDecimal(other.to_s)
              self.class.from_decimal(to_d + val)
            end
          end

          def -(other)
            case other
            when self.class
              subtract_same_class(other)
            else
              val = other.respond_to?(:to_d) ? other.to_d : BigDecimal(other.to_s)
              self.class.from_decimal(to_d - val)
            end
          end

          private

          def add_same_class(other)
            u, n = add_units_nano(other)
            self.class.new(units: u, nano: n)
          end

          def subtract_same_class(other)
            u, n = subtract_units_nano(other)
            self.class.new(units: u, nano: n)
          end
        end
      end
    end
  end
end
