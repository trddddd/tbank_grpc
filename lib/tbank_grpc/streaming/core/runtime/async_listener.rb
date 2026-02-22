# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Runtime
        # Запуск stream-listener в фоновом потоке.
        # @api private
        class AsyncListener
          JOIN_TIMEOUT_SEC = 3

          attr_reader :service

          # @param service [Object] сервис с методами #listen и #stop
          def initialize(service)
            @service = service
            @mutex = Mutex.new
            @running = false
            @thread = nil
            @started_at = nil
          end

          # @return [Thread] поток, в котором выполняется service.listen
          # @raise [InvalidArgumentError] если listener уже запущен
          def start
            @mutex.synchronize do
              raise InvalidArgumentError, 'Async listener already running' if @running

              @running = true
              @started_at = Time.now
              @thread = Thread.new { run }
            end
            @thread
          rescue StandardError
            @mutex.synchronize do
              @running = false
              @thread = nil
            end
            raise
          end

          # @return [void]
          def stop
            thread = @mutex.synchronize do
              @running = false
              current_thread = @thread
              @thread = nil
              current_thread
            end
            @service.stop
            return unless thread

            return if thread == Thread.current
            return if thread.join(JOIN_TIMEOUT_SEC)

            TbankGrpc.logger.warn('Async stream listener did not stop in time; continuing without force kill')
          end

          # @return [Boolean]
          def listening?
            thread = @mutex.synchronize { @thread }
            running? && thread&.alive?
          end

          # @return [Boolean]
          def running?
            @mutex.synchronize { @running }
          end

          # @return [Hash] running:, listening:, thread_alive:, thread_id:, uptime_seconds:
          def status
            thread = @mutex.synchronize { @thread }
            {
              running: running?,
              listening: listening?,
              thread_alive: thread&.alive?,
              thread_id: thread&.object_id,
              uptime_seconds: uptime
            }
          end

          private

          def run
            TbankGrpc.logger.info('Async stream listener started', thread_id: Thread.current.object_id)
            @service.listen
          rescue StandardError => e
            TbankGrpc.logger.error('Async stream listener error', error: e.message)
            raise
          ensure
            @mutex.synchronize do
              @running = false
              @thread = nil if @thread == Thread.current
            end
            TbankGrpc.logger.info('Async stream listener stopped', uptime_seconds: uptime)
          end

          def uptime
            return 0 unless @started_at

            (Time.now - @started_at).round(2)
          end
        end
      end
    end
  end
end
