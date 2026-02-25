# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Нормализация instrument_id / instrument_ids: валидация, strip, опционально uniq для списка.
    # Используется в unary-сервисах и в стриминге (ParamsNormalizer).
    module InstrumentIdNormalizer
      # @param instrument_id [String, #to_s]
      # @param strip [Boolean] убирать пробелы по краям (по умолчанию true)
      # @return [String]
      # @raise [InvalidArgumentError] если пустая строка после обработки
      def self.normalize_single(instrument_id, strip: true)
        id = instrument_id.to_s
        id = id.strip if strip
        raise InvalidArgumentError, 'instrument_id is required' if id.empty?

        id
      end

      # @param instrument_ids [Array, String, #to_s] один id или массив
      # @param strip [Boolean] убирать пробелы (по умолчанию true)
      # @param uniq [Boolean] убирать дубликаты (по умолчанию false для совместимости с unary)
      # @return [Array<String>]
      # @raise [InvalidArgumentError] если после обработки массив пуст
      def self.normalize_list(instrument_ids, strip: true, uniq: false)
        ids = Array(instrument_ids).flatten.map do |item|
          s = item.to_s
          strip ? s.strip : s
        end.reject(&:empty?)
        ids = ids.uniq if uniq
        raise InvalidArgumentError, 'instrument_id is required' if ids.empty?

        ids
      end
    end
  end
end
