# frozen_string_literal: true

module TbankGrpc
  # Базовое исключение гема. Подклассы соответствуют кодам gRPC (InvalidArgument, NotFound и т.д.).
  class Error < StandardError
    # @return [Integer, Symbol, nil] код gRPC
    attr_reader :grpc_code
    # @return [Hash] контекст (grpc_code, tracking_id, message, details)
    attr_reader :context
    # @return [String, nil] x-tracking-id из ответа API
    attr_reader :tracking_id
    # @return [String, nil] сообщение из gRPC metadata
    attr_reader :grpc_message
    # @return [String] текст ошибки (то же, что to_s без суффикса)
    attr_reader :message

    # @return [Hash] маппинг GRPC::Core::StatusCodes => класс исключения
    def self.grpc_code_map
      @grpc_code_map ||= {
        GRPC::Core::StatusCodes::INVALID_ARGUMENT => InvalidArgumentError,
        GRPC::Core::StatusCodes::NOT_FOUND => NotFoundError,
        GRPC::Core::StatusCodes::ALREADY_EXISTS => AlreadyExistsError,
        GRPC::Core::StatusCodes::PERMISSION_DENIED => PermissionDeniedError,
        GRPC::Core::StatusCodes::UNAUTHENTICATED => InvalidTokenError,
        GRPC::Core::StatusCodes::DEADLINE_EXCEEDED => DeadlineExceededError,
        GRPC::Core::StatusCodes::UNIMPLEMENTED => UnimplementedError,
        GRPC::Core::StatusCodes::INTERNAL => InternalError,
        GRPC::Core::StatusCodes::UNAVAILABLE => UnavailableError
      }.freeze
    end

    # @param message [String] текст ошибки
    # @param context [Hash] опционально: grpc_code, tracking_id, message
    def initialize(message, context = {})
      @message = message
      @grpc_code = context[:grpc_code]
      @tracking_id = context[:tracking_id]
      @context = context
      @grpc_message = context[:message]
      super(message)
    end

    # Создаёт экземпляр ошибки по gRPC-исключению.
    # @param error [GRPC::BadStatus]
    # @return [Error] экземпляр соответствующего подкласса (InvalidArgumentError и т.д.)
    def self.from_grpc_error(error)
      error_class = grpc_code_map[error.code] || Error
      error_class.new(error.details.to_s, grpc_code: error.code, message: error.details.to_s)
    end

    # @return [String] сообщение с опциональными grpc_message, tracking_id, code
    def to_s
      msg = @message
      msg += " [grpc_message: #{@grpc_message}]" if @grpc_message
      msg += " [tracking_id: #{@tracking_id}]" if @tracking_id
      msg += " [code: #{@grpc_code}]" if @grpc_code
      msg
    end
  end

  # 4xx-подобные коды gRPC
  class ClientError < Error; end
  class InvalidArgumentError < ClientError; end
  class NotFoundError < ClientError; end
  class InvalidTokenError < ClientError; end
  class PermissionDeniedError < ClientError; end
  class AlreadyExistsError < ClientError; end

  # 5xx-подобные коды gRPC
  class ServerError < Error; end
  class InternalError < ServerError; end
  class UnavailableError < ServerError; end
  class DeadlineExceededError < ServerError; end
  class UnimplementedError < ServerError; end

  # ошибки соединения до gRPC
  class ConnectionError < Error; end
  class ConnectionFailedError < ConnectionError; end
  class TLSError < ConnectionError; end
  # неверная конфигурация (token, app_name, endpoint)
  class ConfigurationError < Error; end
end
