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
        compact_key = build_compact_key(key, prefix: prefix)
        return enum_module.const_get(compact_key) if compact_key && enum_module.const_defined?(compact_key)

        raise TbankGrpc::InvalidArgumentError, "Unknown enum value: #{value}"
      end

      # В некоторых enum'ах контракт и дока/клиентский код расходятся по подчёркиваниям:
      # пример: EXECUTION_REPORT_STATUS_PARTIALLYFILL (proto) vs :partially_fill (из доки).
      # Эта функция пытается «скомпактить» ключ (убрать подчёркивания), чтобы такие кейсы
      # разрешались без ручных алиасов в каждом enum'е.
      def self.build_compact_key(key, prefix:)
        return if key.nil? || !key.include?('_')

        prefix_key = prefix&.to_s&.upcase
        if prefix_key && key.start_with?("#{prefix_key}_")
          suffix = key[(prefix_key.length + 1)..]
          return "#{prefix_key}_#{suffix.delete('_')}"
        end

        key.delete('_')
      end
      private_class_method :build_compact_key
    end
  end
end
