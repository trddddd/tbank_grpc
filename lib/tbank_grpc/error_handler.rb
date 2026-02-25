# frozen_string_literal: true

module TbankGrpc
  # Преобразует GRPC::BadStatus в подкласс {Error} с контекстом.
  # @api private
  class ErrorHandler
    # @param grpc_error [GRPC::BadStatus]
    # @param context [Hash] доп. контекст (method и т.д.)
    # @return [Error] экземпляр InvalidArgumentError, NotFoundError и т.д.
    def self.wrap_grpc_error(grpc_error, context = {})
      tracking_id = begin
        Grpc::TrackingId.extract(grpc_error.metadata) || 'unknown'
      rescue StandardError
        "unknown-#{SecureRandom.hex(4)}"
      end

      grpc_message = extract_message(grpc_error)
      details = grpc_error.details.to_s

      context[:grpc_code] = grpc_error.code
      context[:tracking_id] = tracking_id
      context[:message] = grpc_message if grpc_message
      context[:details] = details

      error_class = Error.grpc_code_map[grpc_error.code] || Error
      message = build_message(grpc_message: grpc_message, details: details)
      error_class.new(message, context)
    end

    def self.build_message(grpc_message:, details:)
      text = grpc_message.to_s.strip
      text = details if text.empty?
      code = details.to_s.strip

      if !code.empty? && text != code
        "#{text} (#{code})"
      else
        text
      end
    end

    def self.extract_message(grpc_error)
      raw = grpc_error.metadata&.dig('message')
      return raw.first if raw.is_a?(Array) && raw.first

      raw
    rescue StandardError
      nil
    end
  end
end
