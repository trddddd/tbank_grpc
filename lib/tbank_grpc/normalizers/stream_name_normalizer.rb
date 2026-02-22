# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Нормализация имени стрима: to_s, strip; если пусто — default 'stream'.
    # Используется в стриминге (ListenLoop) для идентификации потока.
    module StreamNameNormalizer
      DEFAULT = 'stream'

      # @param value [String, #to_s]
      # @param default [String] подставляется при пустой строке после strip (по умолчанию 'stream')
      # @return [String]
      def self.normalize(value, default: DEFAULT)
        name = value.to_s.strip
        name.empty? ? default : name
      end
    end
  end
end
