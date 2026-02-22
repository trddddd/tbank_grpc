# frozen_string_literal: true

module TbankGrpc
  module Normalizers
    # Нормализация account_id / account_ids: валидация, strip, опционально uniq для списка.
    # Используется в UsersService (GetMarginAttributes) и при портировании операций/ордеров/стримов.
    module AccountIdNormalizer
      # @param account_id [String, #to_s]
      # @param strip [Boolean] убирать пробелы по краям (по умолчанию true)
      # @return [String]
      # @raise [InvalidArgumentError] если пустая строка после обработки
      def self.normalize_single(account_id, strip: true)
        id = account_id.to_s
        id = id.strip if strip
        raise InvalidArgumentError, 'account_id is required' if id.empty?

        id
      end

      # @param account_ids [Array, String, #to_s] один id или массив
      # @param strip [Boolean] убирать пробелы (по умолчанию true)
      # @param uniq [Boolean] убирать дубликаты (по умолчанию false)
      # @return [Array<String>]
      # @raise [InvalidArgumentError] если после обработки массив пуст
      def self.normalize_list(account_ids, strip: true, uniq: false)
        ids = Array(account_ids).flatten.map do |item|
          s = item.to_s
          strip ? s.strip : s
        end.reject(&:empty?)
        ids = ids.uniq if uniq
        raise InvalidArgumentError, 'account_id is required' if ids.empty?

        ids
      end
    end
  end
end
