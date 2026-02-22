# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Runtime
        class ReconnectionError < StandardError; end

        # Exponential backoff при реконнекте стрима.
        # @api private
        class ReconnectionStrategy
          WAIT_CHUNK_SEC = 0.25

          # @param max_attempts [Integer] максимум попыток (при attempt > max_attempts — ReconnectionError)
          # @param base_delay [Float] базовая задержка (сек) для экспоненты
          def initialize(max_attempts: 5, base_delay: 1.0)
            @max_attempts = max_attempts.to_i
            @base_delay = base_delay.to_f
          end

          # @param attempt [Integer] номер попытки, начиная с 1
          # @yield [void] abort_check — если блок вернёт true, ожидание прерывается
          # @return [void]
          # @raise [ReconnectionError] когда attempt > max_attempts
          def call(attempt, &)
            raise ReconnectionError, 'Max reconnection attempts reached' if attempt.to_i > @max_attempts

            wait_with_abort(backoff_delay(attempt), &)
          end

          private

          def backoff_delay(attempt)
            exponential = @base_delay * (2**(attempt.to_i - 1))
            (exponential * jitter_multiplier).round(3)
          end

          def jitter_multiplier
            rand(0.5..1.5)
          end

          def wait_with_abort(delay)
            started_at = monotonic_time
            loop do
              break if block_given? && yield
              break if monotonic_time - started_at >= delay

              remaining = delay - (monotonic_time - started_at)
              sleep([WAIT_CHUNK_SEC, remaining].min)
            end
          end

          def monotonic_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
        end
      end
    end
  end
end
