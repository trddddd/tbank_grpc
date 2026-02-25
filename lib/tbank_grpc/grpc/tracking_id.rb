# frozen_string_literal: true

module TbankGrpc
  module Grpc
    # Извлечение x-tracking-id из gRPC metadata (ответы T-Bank Invest API).
    # T-Bank возвращает x-tracking-id в ответах unary-методов; при ошибках — в e.metadata.
    # @api private
    module TrackingId
      # @param metadata [Hash, nil] gRPC metadata (ключи строка или символ)
      # @return [String, nil] извлечённый ID или nil
      def self.extract(metadata)
        return unless metadata

        value = metadata['x-tracking-id'] || metadata[:'x-tracking-id']
        return if value.nil? || value.to_s.strip.empty?

        value.is_a?(Array) ? value.first.to_s.strip : value.to_s.strip
      end
    end
  end
end
