# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Допустимые глубины стакана для GetOrderBook и подписок на стакан (MarketDataStream).
    module OrderBookDepth
      ALLOWED_DEPTHS = [1, 10, 20, 30, 40, 50].freeze

      # @param depth [Integer, #to_i]
      # @return [Integer] ближайшее допустимое значение
      def self.normalize(depth)
        ALLOWED_DEPTHS.min_by { |allowed| (allowed - depth.to_i).abs }
      end
    end
  end
end
