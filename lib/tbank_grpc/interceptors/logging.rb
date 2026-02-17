# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    class Logging < GRPC::ClientInterceptor
      # tracking_id приходит от T-Bank в ответе (x-tracking-id). В клиентском
      # интерсепторе до ответа его нет; из kwargs[:call] в gRPC Ruby доступен
      # только :deadline (InterceptableView), поэтому в логе успеха tracking_id
      # будет nil. При ошибке берём из e.metadata.
      %i[request_response client_streamer server_streamer bidi_streamer].each do |rpc_type|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{rpc_type}(**kwargs)
            method = kwargs[:method]
            start_time = Time.now

            TbankGrpc.logger.debug('gRPC request', method: method)

            begin
              result = yield
              log_success(method, nil, Time.now - start_time)
              result
            rescue GRPC::BadStatus => e
              tracking_id = e.metadata && (e.metadata['x-tracking-id'] || e.metadata[:'x-tracking-id'])
              tracking_id = tracking_id.first if tracking_id.is_a?(Array)
              log_error(method, tracking_id, Time.now - start_time, e)
              raise
            end
          end
        RUBY
      end

      private

      def log_success(method, tracking_id, duration)
        TbankGrpc.logger.debug(
          'gRPC response',
          method: method,
          tracking_id: tracking_id,
          duration_ms: (duration * 1000).round(2)
        )
      end

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
