# frozen_string_literal: true

module TbankGrpc
  module Converters
    # Преобразование proto Timestamp ↔ Time.
    module Timestamp
      # @param timestamp [Google::Protobuf::Timestamp, nil]
      # @return [Time, nil] локальное время или nil при ошибке парсинга
      def self.to_time(timestamp)
        return unless timestamp

        Time.at(timestamp.seconds, timestamp.nanos / 1000.0)
      rescue StandardError => e
        TbankGrpc.logger&.warn('Failed to parse timestamp', error: e.message)
        nil
      end
    end
  end
end
