# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Нормализация тикера: to_s, strip, upcase. Единое представление для поиска и сравнения.
    module TickerNormalizer
      # @param value [String, #to_s]
      # @return [String]
      def self.normalize(value)
        value.to_s.strip.upcase
      end
    end
  end
end
