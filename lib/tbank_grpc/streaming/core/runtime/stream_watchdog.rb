# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Runtime
        # Watchdog: при длительном idle инициирует reconnect текущего stream.
        # @api private
        class StreamWatchdog
          DEFAULT_CHECK_INTERVAL_SEC = 5

          # @param service [Object] объект с #listening?, #last_event_at, #force_reconnect
          # @param timeout_sec [Float, Integer] порог idle (сек), после которого вызывается force_reconnect
          # @param check_interval_sec [Float] интервал проверки (сек)
          def initialize(service:, timeout_sec:, check_interval_sec: DEFAULT_CHECK_INTERVAL_SEC)
            @service = service
            @timeout_sec = timeout_sec.to_f
            @check_interval_sec = check_interval_sec.to_f
            @mutex = Mutex.new
            @running = false
            @thread = nil
          end

          # @return [void]
          def start
            @mutex.synchronize do
              return if @running && @thread&.alive?

              @running = true
              @thread = Thread.new { watch }
            end
          end

          # @return [void]
          def stop
            thread_to_join = @mutex.synchronize do
              @running = false
              t = @thread
              @thread = nil
              t
            end
            thread_to_join&.join(1)
          end

          private

          def watch
            while current_thread_active?
              sleep(@check_interval_sec)
              break unless current_thread_active?

              check_idle_timeout
            end
          rescue StandardError => e
            TbankGrpc.logger.error('StreamWatchdog error', error: e.message)
          end

          def check_idle_timeout
            return unless @service.listening?

            last_event_at = @service.last_event_at
            return unless last_event_at

            idle_time = Time.now - last_event_at
            return if idle_time <= @timeout_sec

            TbankGrpc.logger.warn(
              'Stream idle timeout exceeded, forcing reconnect',
              idle_seconds: idle_time.round(2),
              timeout_seconds: @timeout_sec
            )
            @service.force_reconnect
          end

          def current_thread_active?
            @mutex.synchronize { @running && @thread == Thread.current }
          end
        end
      end
    end
  end
end
