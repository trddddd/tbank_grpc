# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    # gRPC-интерсептор: логирование запросов и ответов (debug), при ошибках — уровень error с tracking_id.
    #
    # Реализует все четыре хука GRPC::ClientInterceptor: request_response, client_streamer,
    # server_streamer, bidi_streamer — логирует запрос, выполняет block, при GRPC::BadStatus
    #   логирует ошибку с x-tracking-id.
    #
    # @note tracking_id приходит от T-Bank в ответе (x-tracking-id). В клиентском интерсепторе до ответа его нет;
    #   в логе успеха tracking_id будет nil. При ошибке берём из e.metadata.
    class Logging < GRPC::ClientInterceptor
      # @!method request_response(**kwargs, &block)
      # @!method client_streamer(**kwargs, &block)
      # @!method server_streamer(**kwargs, &block)
      # @!method bidi_streamer(**kwargs, &block)
      #   Хуки GRPC::ClientInterceptor: логируют запрос (debug), вызывают block, при ошибке логируют с tracking_id.

      %i[request_response client_streamer server_streamer bidi_streamer].each do |rpc_type|
        define_method(rpc_type) do |**kwargs, &block|
          method = kwargs[:method]
          start_time = Time.now

          TbankGrpc.logger.debug('gRPC request', method: method)

          begin
            result = block.call
            log_success(method, nil, Time.now - start_time)
            result
          rescue GRPC::BadStatus => e
            tracking_id = TbankGrpc::TrackingId.extract(e.metadata)
            log_error(method, tracking_id, Time.now - start_time, e)
            raise
          end
        end
      end

      private

      # @param method [String] полное имя gRPC-метода
      # @param tracking_id [String, nil]
      # @param duration [Float] время в секундах
      # @return [void]
      def log_success(method, tracking_id, duration)
        TbankGrpc.logger.debug(
          'gRPC response',
          method: method,
          tracking_id: tracking_id,
          duration_ms: (duration * 1000).round(2)
        )
      end

      # @param method [String] полное имя gRPC-метода
      # @param tracking_id [String, nil]
      # @param duration [Float] время в секундах
      # @param error [GRPC::BadStatus]
      # @return [void]
      def log_error(method, tracking_id, duration, error)
        TbankGrpc.logger.debug(
          'gRPC error',
          method: method,
          tracking_id: tracking_id,
          duration_ms: (duration * 1000).round(2),
          code: error.code,
          details: error.details
        )
      end
    end
  end
end
