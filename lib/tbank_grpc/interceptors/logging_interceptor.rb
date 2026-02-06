# frozen_string_literal: true

require 'securerandom'

module TbankGrpc
  module Interceptors
    class LoggingInterceptor < GRPC::ClientInterceptor
      def request_response(request:, call:, method:, metadata:)
        tracking_id = generate_or_extract_tracking_id(call, metadata)
        start_time = Time.now

        log_request(method, tracking_id, metadata)

        begin
          response = yield

          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :success)

          response
        rescue GRPC::BadStatus => e
          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :error, error: e)
          raise
        end
      end

      def client_streamer(requests:, call:, method:, metadata:)
        tracking_id = generate_or_extract_tracking_id(call, metadata)
        start_time = Time.now

        log_request(method, tracking_id, metadata)

        begin
          response = yield
          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :success)
          response
        rescue GRPC::BadStatus => e
          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :error, error: e)
          raise
        end
      end

      def server_streamer(request:, call:, method:, metadata:)
        tracking_id = generate_or_extract_tracking_id(call, metadata)
        start_time = Time.now
        log_request(method, tracking_id, metadata)

        error_raised = false
        begin
          yield
        rescue GRPC::BadStatus => e
          error_raised = true
          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :error, error: e)
          raise
        ensure
          unless error_raised
            duration = Time.now - start_time
            log_response(method, tracking_id, duration, :success)
          end
        end
      end

      def bidi_streamer(requests:, call:, method:, metadata:)
        tracking_id = generate_or_extract_tracking_id(call, metadata)
        start_time = Time.now
        log_request(method, tracking_id, metadata)

        error_raised = false
        begin
          yield
        rescue GRPC::BadStatus => e
          error_raised = true
          duration = Time.now - start_time
          log_response(method, tracking_id, duration, :error, error: e)
          raise
        ensure
          unless error_raised
            duration = Time.now - start_time
            log_response(method, tracking_id, duration, :success)
          end
        end
      end

      private

      def generate_or_extract_tracking_id(_call, metadata)
        (metadata && (metadata['x-tracking-id'] || metadata[:'x-tracking-id'])) ||
          SecureRandom.uuid
      end

      def log_request(method, tracking_id, _metadata)
        TbankGrpc.logger.debug(
          'gRPC request',
          method: method,
          tracking_id: tracking_id
        )
      end

      def log_response(method, tracking_id, duration, status, error: nil)
        if status == :success
          TbankGrpc.logger.debug(
            'gRPC response',
            method: method,
            tracking_id: tracking_id,
            duration_ms: (duration * 1000).round(2)
          )
        else
          TbankGrpc.logger.error(
            'gRPC error',
            method: method,
            tracking_id: tracking_id,
            duration_ms: (duration * 1000).round(2),
            error_code: error.code,
            error_message: error.details
          )
        end
      end
    end
  end
end
