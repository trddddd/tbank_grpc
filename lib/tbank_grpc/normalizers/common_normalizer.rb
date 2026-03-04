# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Общие нормалайзеры для простых примитивов (строки, uid, числа).
    # Используются в сервисах и хелперах для единообразных сообщений об ошибках.
    module CommonNormalizer
      # @param value [Object]
      # @param field_name [String]
      # @return [String]
      # @raise [InvalidArgumentError] если после trim строка пустая
      def self.non_empty_string(value, field_name:)
        normalized = value.to_s.strip
        raise InvalidArgumentError, "#{field_name} is required" if normalized.empty?

        normalized
      end

      # @param value [Object]
      # @param field_name [String]
      # @param max_length [Integer]
      # @return [String]
      # @raise [InvalidArgumentError] если пусто или длина больше max_length
      def self.uid(value, field_name:, max_length:)
        uid = non_empty_string(value, field_name: field_name)
        raise InvalidArgumentError, "#{field_name} must be at most #{max_length} characters" if uid.length > max_length

        uid
      end

      # @param value [Object]
      # @param field_name [String]
      # @return [Integer]
      # @raise [InvalidArgumentError] если не integer или <= 0
      def self.positive_integer(value, field_name:)
        int_value = Integer(value)
        raise InvalidArgumentError, "#{field_name} must be positive" if int_value <= 0

        int_value
      rescue ArgumentError, TypeError
        raise InvalidArgumentError, "#{field_name} must be an integer"
      end
    end
  end
end
