# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Core
      module Dispatch
        # Асинхронный event loop c пулом worker-потоков для callback'ов.
        # @api private
        # rubocop:disable Metrics/ClassLength
        class EventLoop
          DEFAULT_THREAD_POOL_SIZE = 4
          STOP_SIGNAL = Object.new
          JOIN_TIMEOUT_SEC = 5

          attr_reader :metrics

          # @param thread_pool_size [Integer] размер пула воркеров (минимум 1)
          # @param metrics [Core::Observability::Metrics] бэкенд метрик
          def initialize(thread_pool_size: DEFAULT_THREAD_POOL_SIZE, metrics: Core::Observability::Metrics.new)
            @thread_pool_size = [thread_pool_size.to_i, 1].max
            @callbacks = {}
            @callbacks_mutex = Mutex.new
            @lifecycle_mutex = Mutex.new
            @running = false
            @runtime_seq = 0
            @runtime = nil
            @thread = nil
            @workers = []
            @metrics = metrics
          end

          # @param event_type [Symbol] тип события (например :orderbook, :candle)
          # @param as [Symbol] :proto или :model — формат payload в callback
          # @yieldparam payload [Object] proto-сообщение или модель в зависимости от as
          # @return [void]
          # @raise [InvalidArgumentError] если блок не передан
          def on(event_type, as: :proto, &block)
            raise InvalidArgumentError, 'Block is required for callback registration' unless block

            callback = { as: as.to_sym, block: block }
            @callbacks_mutex.synchronize do
              @callbacks[event_type.to_sym] ||= []
              @callbacks[event_type.to_sym] << callback
            end
          end

          # @param event_type [Symbol]
          # @return [Boolean] есть ли хотя бы один callback с as: :model
          def needs_model_payload?(event_type)
            @callbacks_mutex.synchronize do
              (@callbacks[event_type.to_sym] || []).any? { |callback| callback[:as] == :model }
            end
          end

          # @return [Thread, nil] поток event loop или nil при повторном вызове без остановки
          def start
            @lifecycle_mutex.synchronize do
              return @thread if @running && @thread&.alive?

              setup_runtime
              @thread
            end
          end

          # @return [void]
          def stop
            runtime = @lifecycle_mutex.synchronize do
              next nil unless @running || @thread

              @running = false
              current_runtime = @runtime
              t = @thread
              workers = @workers
              @thread = nil
              @workers = []
              @runtime = nil
              { runtime: current_runtime, thread: t, workers: workers }
            end
            return unless runtime

            runtime[:runtime][:queue] << STOP_SIGNAL if runtime[:runtime]
            join_thread(runtime[:thread], timeout_sec: JOIN_TIMEOUT_SEC, role: 'event loop')
            stop_workers(runtime[:workers], runtime[:runtime]&.dig(:worker_queue))
          end

          # @param event_type [Symbol]
          # @param proto_payload [Object] proto-сообщение
          # @param model_payload [Object, nil] опциональная модель (если есть callback as: :model)
          # @return [void] ничего не делает, если loop не запущен
          def emit(event_type, proto_payload:, model_payload: nil)
            runtime = @lifecycle_mutex.synchronize do
              next nil unless @running && @runtime

              @runtime
            end
            return unless runtime

            @metrics.track_event_emitted(event_type)
            runtime[:queue] << {
              event_type: event_type.to_sym,
              proto_payload: proto_payload,
              model_payload: model_payload,
              enqueued_at: monotonic_time
            }
          end

          # @return [Boolean]
          def alive?
            @lifecycle_mutex.synchronize { @running && @thread&.alive? }
          end

          # @return [Boolean]
          def running?
            @lifecycle_mutex.synchronize { @running }
          end

          # @return [Hash] метрики + queue_depth, worker_queue_depth, thread_pool_size, generation (если loop запущен)
          def stats
            runtime = @lifecycle_mutex.synchronize { @runtime }
            queue_depth = runtime ? runtime[:queue].length : 0
            worker_queue_depth = runtime ? runtime[:worker_queue].length : 0
            base = @metrics.to_h(queue_depth: queue_depth, worker_queue_depth: worker_queue_depth)
                           .merge(thread_pool_size: @thread_pool_size)
            runtime ? base.merge(generation: runtime[:generation]) : base
          end

          private

          def setup_runtime
            @runtime_seq += 1
            generation = @runtime_seq
            queue = Queue.new
            worker_queue = Queue.new
            @runtime = {
              generation: generation,
              queue: queue,
              worker_queue: worker_queue
            }
            @running = true
            @workers = start_workers(worker_queue: worker_queue, generation: generation)
            @thread = Thread.new { run(queue: queue, worker_queue: worker_queue, generation: generation) }
          end

          def run(queue:, worker_queue:, generation:)
            TbankGrpc.logger.info('EventLoop started', thread_pool_size: @thread_pool_size)
            loop do
              event = queue.pop
              break if stop_signal?(event)
              break unless runtime_active?(generation)

              process_event(event, worker_queue: worker_queue, generation: generation)
            end
          rescue StandardError => e
            TbankGrpc.logger.error('EventLoop error', error: e.message)
          ensure
            TbankGrpc.logger.info('EventLoop stopped', metrics: stats)
          end

          def process_event(event, worker_queue:, generation:)
            event_type = event[:event_type]
            callbacks = callbacks_for(event_type)
            return if callbacks.empty?

            @metrics.track_event_processed(event_type)
            callbacks.each do |callback|
              break unless runtime_active?(generation)

              payload = callback[:as] == :model ? event[:model_payload] : event[:proto_payload]
              worker_queue << {
                callback: callback[:block],
                payload: payload,
                event_type: event_type,
                enqueued_at: event[:enqueued_at]
              }
            end
          end

          def callbacks_for(event_type)
            @callbacks_mutex.synchronize { (@callbacks[event_type] || []).dup }
          end

          def start_workers(worker_queue:, generation:)
            Array.new(@thread_pool_size) do
              Thread.new do
                worker_loop(worker_queue: worker_queue, generation: generation)
              end
            end
          end

          def stop_workers(workers, worker_queue)
            return if workers.empty?

            workers.length.times { worker_queue << STOP_SIGNAL } if worker_queue
            workers.each do |worker|
              next if worker == Thread.current
              next if worker.join(JOIN_TIMEOUT_SEC)

              TbankGrpc.logger.warn('EventLoop worker did not stop in time; continuing shutdown without force kill')
            end
          end

          def worker_loop(worker_queue:, generation:)
            loop do
              break unless runtime_active?(generation)

              job = worker_queue.pop
              break if stop_signal?(job)

              execute_callback(job)
            rescue StandardError => e
              TbankGrpc.logger.error('EventLoop worker error', error: e.message)
              break unless runtime_active?(generation)
            end
          end

          def execute_callback(job)
            job[:callback].call(job[:payload])
            @metrics.track_callback_success(job[:event_type])
          rescue StandardError => e
            @metrics.track_callback_error(job[:event_type], e)
            TbankGrpc.logger.error('EventLoop callback error', event_type: job[:event_type], error: e.message)
          ensure
            @metrics.track_callback_latency(job[:event_type], elapsed_ms_since(job[:enqueued_at])) if job[:enqueued_at]
          end

          def elapsed_ms_since(started_at)
            elapsed = monotonic_time - started_at
            (elapsed * 1000).round(2)
          end

          def monotonic_time
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end

          def stop_signal?(value)
            value.equal?(STOP_SIGNAL)
          end

          def join_thread(thread, timeout_sec:, role:)
            return unless thread
            return if thread == Thread.current
            return if thread.join(timeout_sec)

            TbankGrpc.logger.warn("EventLoop #{role} did not stop in time; continuing shutdown without force kill")
          end

          def runtime_active?(generation)
            @lifecycle_mutex.synchronize do
              @running && @runtime && @runtime[:generation] == generation
            end
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
