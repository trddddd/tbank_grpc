# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Канонизация символа CandleInterval для API (GetCandles и др.).
    # В proto CandleInterval только CANDLE_INTERVAL_HOUR, алиаса CANDLE_INTERVAL_1_HOUR нет.
    module CandleInterval
      ALIASES = { CANDLE_INTERVAL_1_HOUR: :CANDLE_INTERVAL_HOUR }.freeze

      # @param value [Symbol, String, nil]
      # @return [Symbol, nil] канонический символ интервала или nil
      def self.normalize(value)
        return value if value.nil?

        key = value.to_s.upcase.to_sym
        ALIASES[key] || key
      end
    end
  end
end
