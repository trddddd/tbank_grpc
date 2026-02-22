# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Subscriptions
        # Ограничение частоты мутаций подписок (subscribe/unsubscribe) в скользящем окне.
        class MutationLimiter
          # @param max_mutations [Integer] максимум операций в окне
          # @param window_sec [Float, Integer] длина окна в секундах
          def initialize(max_mutations:, window_sec:)
            @max_mutations = max_mutations.to_i
            @window_sec = window_sec.to_f
            @timestamps = []
          end

          # Регистрирует одну мутацию. Вызывать перед каждой subscribe/unsubscribe.
          # @return [void]
          # @raise [InvalidArgumentError] при превышении лимита (например 100/мин)
          def register!
            now = monotonic_time
            cutoff = now - @window_sec
            @timestamps.reject! { |timestamp| timestamp < cutoff }

            if @timestamps.length >= @max_mutations
              raise InvalidArgumentError, 'Subscription mutation limit exceeded: 100 requests/min'
            end

            @timestamps << now
          end

          private

          def monotonic_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
        end
      end
    end
  end
end
