# frozen_string_literal: true

module TbankGrpc
  module Converters
    module Enum
      # Преобразует символ/строку в константу enum модуля (proto).
      # value: Symbol, String или Integer (как есть). prefix: опциональный префикс константы (например 'ORDER_DIRECTION').
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
