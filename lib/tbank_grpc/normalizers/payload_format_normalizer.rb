# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Нормализация формата ответа стрима: :proto или :model.
    # Используется в server-side streaming (BaseServerStreamService).
    module PayloadFormatNormalizer
      ALLOWED = %i[proto model].freeze

      # @param format [Symbol, String]
      # @return [Symbol] :proto или :model
      # @raise [InvalidArgumentError] если значение не из ALLOWED
      def self.normalize(format)
        value = format.to_sym
        return value if ALLOWED.include?(value)

        raise InvalidArgumentError, "Unsupported payload format: #{format.inspect}"
      end
    end
  end
end
