# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Преобразование символа/строки в константу enum модуля (proto).
    module Enum
      # @param enum_module [Module] модуль с константами enum (например OrderDirection)
      # @param value [Symbol, String, Integer, nil] имя константы или целое (возвращается как есть)
      # @param prefix [String, Symbol, nil] опциональный префикс константы (например 'ORDER_DIRECTION')
      # @return [Integer, nil] значение константы enum
      # @raise [TbankGrpc::InvalidArgumentError] при неизвестном value
      def self.resolve(enum_module, value, prefix: nil)
        return if value.nil?
        return value if value.is_a?(Integer)

        key = value.to_s.upcase
        key = "#{prefix}_#{key}" if prefix && !key.start_with?(prefix.to_s)

        enum_module.const_get(key)
      rescue NameError
        raise TbankGrpc::InvalidArgumentError, "Unknown enum value: #{value}"
      end
    end
  end
end
