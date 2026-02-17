# frozen_string_literal: true

module TbankGrpc
  module Converters
    module Timestamp
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
