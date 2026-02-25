# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Session
        # Универсальный цикл stream-listen с reconnect/backoff.
        # @api private
        class ListenLoop
          # rubocop:disable Metrics/ParameterLists
          def initialize(
            channel_manager:,
            reconnection_strategy:,
            open_stream:,
            running:,
            stop_running:,
            dispatch_response:,
            increment_reconnects:,
            stream_name: 'stream'
          )
            # rubocop:enable Metrics/ParameterLists
            @channel_manager = channel_manager
            @reconnection_strategy = reconnection_strategy
            @open_stream = open_stream
            @running = running
            @stop_running = stop_running
            @dispatch_response = dispatch_response
            @increment_reconnects = increment_reconnects
            @stream_name = TbankGrpc::Normalizers::StreamNameNormalizer.normalize(stream_name)
            @last_iteration_stream_opened = false
          end

          def run
            consecutive_failures = 0
            loop do
              break unless running?

              consecutive_failures = process_iteration(consecutive_failures)
            end
          end

          private

          def process_iteration(consecutive_failures)
            stream_had_events = process_stream
            return consecutive_failures unless running?

            next_failures = stream_had_events || @last_iteration_stream_opened ? 0 : consecutive_failures + 1
            reconnect_after_iteration(next_failures)
            next_failures
          end

          def process_stream
            received_events = false
            @last_iteration_stream_opened = false
            stream = @open_stream.call
            @last_iteration_stream_opened = true
            stream.each do |response|
              break unless running?

              received_events = true
              @dispatch_response.call(response)
            end
            received_events
          rescue StandardError => e
            process_stream_error!(e, received_events: received_events)
          end

          def process_stream_error!(error, received_events:)
            return received_events if handle_known_stream_error?(error)

            raise error
          end

          def handle_known_stream_error?(error)
            return true if log_stream_cancelled?(error)
            return true if log_stream_disconnected?(error)
            return true if log_stream_internal?(error)
            return true if log_stream_resource_exhausted?(error)
            return true if log_stream_auth_failed?(error)
            return true if log_stream_interrupted?(error)

            false
          end

          def log_stream_cancelled?(error)
            return false unless error.is_a?(GRPC::Cancelled)

            TbankGrpc.logger.debug('Stream cancelled', error: error.message, stream: @stream_name)
            true
          end

          def log_stream_disconnected?(error)
            return false unless disconnected_stream_error?(error)

            TbankGrpc.logger.warn(
              'Stream disconnected',
              error: error.message,
              class: error.class.name,
              stream: @stream_name
            )
            true
          end

          def log_stream_internal?(error)
            return false unless error.is_a?(GRPC::Internal)

            TbankGrpc.logger.warn('Stream internal error', error: error.message, stream: @stream_name)
            true
          end

          def log_stream_resource_exhausted?(error)
            return false unless error.is_a?(GRPC::ResourceExhausted)

            TbankGrpc.logger.warn('Stream resource exhausted', error: error.message, stream: @stream_name)
            sleep(1)
            true
          end

          def log_stream_auth_failed?(error)
            return false unless auth_stream_error?(error)

            TbankGrpc.logger.error(
              'Stream authentication failed',
              error: error.message,
              class: error.class.name,
              stream: @stream_name
            )
            @stop_running.call
            true
          end

          def log_stream_interrupted?(error)
            return false unless error.is_a?(Interrupt)

            TbankGrpc.logger.info('Stream interrupted by signal', stream: @stream_name)
            @stop_running.call
            true
          end

          def reconnect_after_iteration(consecutive_failures)
            attempt = [consecutive_failures, 1].max
            @increment_reconnects.call
            reconnect(attempt)
          end

          def reconnect(attempt)
            TbankGrpc.logger.info('Resetting channel before reconnect', attempt: attempt, stream: @stream_name)
            @channel_manager.reset(source: @stream_name, reason: 'stream_reconnect')
            @reconnection_strategy.call(attempt) { !running? }
            TbankGrpc.logger.info('Reconnecting stream', attempt: attempt, stream: @stream_name) if running?
          end

          def disconnected_stream_error?(error)
            error.is_a?(GRPC::Unavailable) || error.is_a?(GRPC::DeadlineExceeded)
          end

          def auth_stream_error?(error)
            error.is_a?(GRPC::PermissionDenied) || error.is_a?(GRPC::Unauthenticated)
          end

          def running?
            @running.call
          end
        end
      end
    end
  end
end
