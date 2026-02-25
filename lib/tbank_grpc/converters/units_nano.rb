# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Converters
    # Общая схема units + nano/1e9 для Quotation и MoneyValue.
    # Преобразование пары (units, nano) ↔ Float/BigDecimal без привязки к типу proto.
    module UnitsNano
      # @param units [Integer, nil]
      # @param nano [Integer, nil]
      # @return [Float] units + nano/1e9 (nil трактуется как 0)
      def self.to_f(units, nano)
        (units || 0) + ((nano || 0) / Constants::NANO_DIVISOR)
      end

      # @param units [Integer, nil]
      # @param nano [Integer, nil]
      # @return [BigDecimal]
      def self.to_decimal(units, nano)
        BigDecimal(units || 0) + (BigDecimal(nano || 0) / Constants::NANO_DIVISOR_BD)
      end

      # @param decimal [BigDecimal, Numeric, String]
      # @return [Hash{Symbol => Integer}] { units:, nano: }
      def self.from_decimal(decimal)
        d = BigDecimal(decimal.to_s)
        units = d.to_i
        nano = ((d - units) * Constants::NANO_DIVISOR_BD).to_i
        { units: units, nano: nano }
      end
    end
  end
end
