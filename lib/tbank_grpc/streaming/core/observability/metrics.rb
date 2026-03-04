# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Observability
        # Метрики обработки stream-событий (event loop).
        # При enabled: false все track_* — no-op, to_h/event_stats возвращают ту же структуру с нулями/пустыми хешами.
        #
        # Ограничения роста (длительный uptime): история латентностей и ошибок ограничена по размеру и (опционально) по TTL.
        # rubocop:disable Metrics/ClassLength
        class Metrics
          # @param enabled [Boolean]
          # @param max_latency_samples [Integer] максимум значений латентности на тип события (скользящее окно)
          # @param max_errors_per_type [Integer] максимум записей об ошибках на тип события
          # @param error_ttl_seconds [Integer, Float, nil] если задан — записи об ошибках старше этого возраста (сек)
          #   удаляются при добавлении новой
          def initialize(enabled: true, max_latency_samples: 1000, max_errors_per_type: 100, error_ttl_seconds: nil)
            @enabled = enabled
            @max_latency_samples = max_latency_samples
            @max_errors_per_type = max_errors_per_type
            @error_ttl_seconds = error_ttl_seconds
            @mutex = Mutex.new
            @events_emitted = Hash.new(0)
            @events_processed = Hash.new(0)
            @callbacks_success = Hash.new(0)
            @callbacks_error = Hash.new(0)
            @latencies = Hash.new { |h, k| h[k] = [] }
            @errors = Hash.new { |h, k| h[k] = [] }
            @started_at = Time.now
          end

          # @param event_type [Symbol]
          # @return [void]
          def track_event_emitted(event_type)
            return unless @enabled

            @mutex.synchronize { @events_emitted[event_type] += 1 }
          end

          # @param event_type [Symbol]
          # @param latency_ms [Float, nil]
          # @return [void]
          def track_event_processed(event_type, latency_ms = nil)
            return unless @enabled

            @mutex.synchronize do
              @events_processed[event_type] += 1
              store_latency(event_type, latency_ms) if latency_ms
            end
          end

          # @param event_type [Symbol]
          # @param latency_ms [Float]
          # @return [void]
          def track_callback_latency(event_type, latency_ms)
            return unless @enabled
            return if latency_ms.nil?

            @mutex.synchronize { store_latency(event_type, latency_ms) }
          end

          # @param event_type [Symbol]
          # @return [void]
          def track_callback_success(event_type)
            return unless @enabled

            @mutex.synchronize { @callbacks_success[event_type] += 1 }
          end

          # @param event_type [Symbol]
          # @param error [Exception]
          # @return [void]
          def track_callback_error(event_type, error)
            return unless @enabled

            @mutex.synchronize do
              @callbacks_error[event_type] += 1
              store_error(event_type, error)
            end
          end

          # @param queue_depth [Integer, nil]
          # @param worker_queue_depth [Integer, nil]
          # @return [Hash] uptime_seconds, events_emitted, events_processed, callbacks_success,
          #   callbacks_error, latency_stats, error_count
          def to_h(queue_depth: nil, worker_queue_depth: nil)
            unless @enabled
              data = zero_shape_to_h
              data[:queue_depth] = queue_depth unless queue_depth.nil?
              data[:worker_queue_depth] = worker_queue_depth unless worker_queue_depth.nil?
              return data
            end

            @mutex.synchronize do
              data = {
                uptime_seconds: (Time.now - @started_at).round(2),
                events_emitted: @events_emitted.dup,
                events_processed: @events_processed.dup,
                callbacks_success: @callbacks_success.dup,
                callbacks_error: @callbacks_error.dup,
                latency_stats: latency_stats,
                error_count: @errors.values.sum(&:length)
              }
              data[:queue_depth] = queue_depth unless queue_depth.nil?
              data[:worker_queue_depth] = worker_queue_depth unless worker_queue_depth.nil?
              data
            end
          end

          # Сброс агрегированных счётчиков и истории (латентности, ошибки).
          # @param reset_started_at [Boolean] сбросить @started_at (uptime и throughput_per_sec начнут считаться заново)
          # @return [void]
          def reset_aggregates!(reset_started_at: true)
            return unless @enabled

            @mutex.synchronize do
              @events_emitted.clear
              @events_processed.clear
              @callbacks_success.clear
              @callbacks_error.clear
              @latencies.each_value(&:clear)
              @errors.each_value(&:clear)
              @started_at = Time.now if reset_started_at
            end
          end

          # @param event_type [Symbol]
          # @return [Hash] emitted, processed, success, errors, avg_latency_ms, p95_latency_ms,
          #   p99_latency_ms, throughput_per_sec
          def event_stats(event_type)
            return zero_shape_event_stats(event_type) unless @enabled

            @mutex.synchronize do
              {
                emitted: @events_emitted[event_type],
                processed: @events_processed[event_type],
                success: @callbacks_success[event_type],
                errors: @callbacks_error[event_type],
                avg_latency_ms: avg_latency(event_type),
                p95_latency_ms: percentile(@latencies[event_type], 95),
                p99_latency_ms: percentile(@latencies[event_type], 99),
                throughput_per_sec: throughput(event_type)
              }
            end
          end

          private

          def zero_shape_to_h
            {
              uptime_seconds: 0.0,
              events_emitted: {},
              events_processed: {},
              callbacks_success: {},
              callbacks_error: {},
              latency_stats: {},
              error_count: 0
            }
          end

          def zero_shape_event_stats(_event_type)
            {
              emitted: 0,
              processed: 0,
              success: 0,
              errors: 0,
              avg_latency_ms: 0,
              p95_latency_ms: 0,
              p99_latency_ms: 0,
              throughput_per_sec: 0
            }
          end

          def store_latency(event_type, latency_ms)
            values = @latencies[event_type]
            values << latency_ms
            excess = values.length - @max_latency_samples
            values.shift(excess) if excess.positive?
          end

          def store_error(event_type, error)
            values = @errors[event_type]
            now = Time.now
            prune_errors_by_ttl!(values) if @error_ttl_seconds
            values << { message: error.message, timestamp: now }
            excess = values.length - @max_errors_per_type
            values.shift(excess) if excess.positive?
          end

          def prune_errors_by_ttl!(values)
            cutoff = Time.now - @error_ttl_seconds
            values.reject! { |e| e[:timestamp] < cutoff }
          end

          def latency_stats
            @latencies.each_with_object({}) do |(event_type, values), result|
              result[event_type] = {
                min: values.min,
                max: values.max,
                avg: avg_latency(event_type),
                p95: percentile(values, 95),
                p99: percentile(values, 99),
                count: values.length
              }
            end
          end

          def avg_latency(event_type)
            values = @latencies[event_type]
            return 0 if values.empty?

            (values.sum / values.length.to_f).round(2)
          end

          def percentile(values, percentile_rank)
            return 0 if values.empty?

            sorted = values.sort
            index = ((percentile_rank / 100.0) * sorted.length).ceil - 1
            sorted[[index, 0].max] || sorted.last
          end

          def throughput(event_type)
            uptime = Time.now - @started_at
            return 0 if uptime < 1

            (@events_processed[event_type] / uptime).round(2)
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
