# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    # gRPC-интерсептор: добавляет в метаданные authorization (Bearer token) и x-app-name.
    #
    # Реализует все четыре хука GRPC::ClientInterceptor: request_response, client_streamer,
    # server_streamer, bidi_streamer — одинаково: обогащает metadata и передаёт управление дальше.
    class Metadata < GRPC::ClientInterceptor
      # @param token [String] токен доступа T-Bank
      # @param app_name [String] имя приложения (например trddddd.tbank_grpc)
      def initialize(token:, app_name:)
        @token = token
        @app_name = app_name
        super()
      end

      %i[request_response client_streamer server_streamer bidi_streamer].each do |rpc_type|
        define_method(rpc_type) do |**kwargs, &block|
          enrich_metadata(kwargs[:metadata])
          block.call
        end
      end

      # @!method request_response(**kwargs, &block)
      # @!method client_streamer(**kwargs, &block)
      # @!method server_streamer(**kwargs, &block)
      # @!method bidi_streamer(**kwargs, &block)
      #   Хуки GRPC::ClientInterceptor: добавляют authorization и x-app-name в kwargs[:metadata], затем вызывают block.

      private

      # @param metadata [Hash] метаданные запроса (модифицируется на месте)
      # @return [void]
      def enrich_metadata(metadata)
        metadata['authorization'] = "Bearer #{@token}"
        metadata['x-app-name'] = @app_name.to_s
        # x-tracking-id не отправляем: T-Bank добавляет его в ответы сам
      end
    end
  end
end
