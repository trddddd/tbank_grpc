# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      # Базовый lifecycle для bidirectional stream RPC: запуск/остановка, reconnect, watchdog, async/sync listen.
      #
      # Подклассы реализуют {#stream_key}, {#open_stream}, {#dispatch_response}, {#build_event_loop}.
      # rubocop:disable Metrics/ClassLength
      class BaseBidiStreamService
        # @return [ChannelManager]
        attr_reader :channel_manager
        # @return [Hash] конфиг (token, app_name, stream_idle_timeout и т.д.)
        attr_reader :config
        # @return [Streaming::Core::Dispatch::EventLoop]
        attr_reader :event_loop
        # @return [Streaming::Core::Runtime::ReconnectionStrategy]
        attr_reader :reconnection_strategy

        # @param channel_manager [ChannelManager]
        # @param config [Hash]
        # @param interceptors [Array<GRPC::ClientInterceptor>]
        # @param thread_pool_size [Integer] размер пула для обработки событий
        def initialize(channel_manager:, config:, interceptors:, thread_pool_size: 4)
          @channel_manager = channel_manager
          @config = config
          @interceptors = interceptors
          @event_loop = build_event_loop(thread_pool_size: thread_pool_size)
          @reconnection_strategy = build_reconnection_strategy
          @async_listener = nil
          @async_mutex = Mutex.new
          @state_mutex = Mutex.new
          @running = false
          @reconnects = 0
          @last_event_at = nil
        end

        # @return [Streaming::Core::Observability::Metrics, nil]
        def metrics
          @event_loop.metrics
        end

        # @return [Hash] metrics, reconnects, last_event_at, listening, async_status
        def stats
          {
            metrics: @event_loop.stats,
            reconnects: reconnects,
            last_event_at: last_event_at,
            listening: listening?,
            async_status: async_listener_status
          }
        end

        # Запуск стрима в фоне (неблокирующий). Остановка — {#stop_async}.
        #
        # @return [Streaming::Core::Runtime::AsyncListener]
        # @raise [InvalidArgumentError] если стрим уже запущен
        def listen_async
          listener = @async_mutex.synchronize do
            raise InvalidArgumentError, 'Stream already running' if running? || @async_listener&.running?

            @async_listener = ::TbankGrpc::Streaming::Core::Runtime::AsyncListener.new(self)
          end
          listener.start
        rescue StandardError
          clear_async_listener(listener) if listener
          raise
        end

        # Останавливает асинхронный стрим, запущенный через {#listen_async}.
        # @return [void]
        def stop_async
          listener = @async_mutex.synchronize do
            current = @async_listener
            @async_listener = nil
            current
          end
          listener&.stop
        end

        # Синхронный listen (алиас для {#listen}).
        # @return [void]
        def listen_sync
          listen
        end

        # Синхронный запуск стрима. Блокирует до Interrupt или ошибки; reconnect по стратегии.
        #
        # @raise [Streaming::Core::Runtime::ReconnectionError] при превышении лимита переподключений
        # @return [void]
        def listen
          start_listening!
          @event_loop.start
          watchdog = start_watchdog
          build_listen_loop.run
        rescue ::TbankGrpc::Streaming::Core::Runtime::ReconnectionError => e
          TbankGrpc.logger.error('Stream failed: max reconnection attempts exceeded', error: e.message)
          raise
        rescue Interrupt
          TbankGrpc.logger.info('Stream stopped by interrupt', stream: stream_key)
        rescue StandardError => e
          TbankGrpc.logger.error('Stream failure', error: e.message, stream: stream_key)
          raise
        ensure
          watchdog&.stop
          stop
        end

        # Останавливает стрим и event loop.
        # @return [void]
        def stop
          self.running = false
          @event_loop.stop if @event_loop.alive?
        end

        # Принудительный сброс канала и переподключение (если стрим запущен).
        # @return [void]
        def force_reconnect
          requested = @state_mutex.synchronize do
            next false unless @running

            true
          end
          return unless requested

          @channel_manager.reset(source: stream_key, reason: 'force_reconnect')
        end

        # @return [Boolean] стрим запущен и event loop жив
        def listening?
          running? && @event_loop.alive?
        end

        # @return [Time, nil] время последнего полученного события
        def last_event_at
          @state_mutex.synchronize { @last_event_at }
        end

        private

        def dispatch_and_track(response)
          touch_last_event
          dispatch_response(response)
        end

        def start_watchdog
          watchdog = build_watchdog
          watchdog&.start
          watchdog
        end

        def stream_key
          raise NotImplementedError, 'Subclasses must implement stream_key'
        end

        def open_stream
          raise NotImplementedError, 'Subclasses must implement open_stream'
        end

        def dispatch_response(_response)
          raise NotImplementedError, 'Subclasses must implement dispatch_response'
        end

        def build_event_loop(thread_pool_size:)
          raise NotImplementedError, 'Subclasses must implement build_event_loop'
        end

        def build_reconnection_strategy
          ::TbankGrpc::Streaming::Core::Runtime::ReconnectionStrategy.new
        end

        def build_watchdog
          timeout_sec = @config[:stream_idle_timeout].to_f
          return if timeout_sec <= 0

          check_interval = @config[:stream_watchdog_interval_sec] ||
                           ::TbankGrpc::Streaming::Core::Runtime::StreamWatchdog::DEFAULT_CHECK_INTERVAL_SEC
          ::TbankGrpc::Streaming::Core::Runtime::StreamWatchdog.new(
            service: self,
            timeout_sec: timeout_sec,
            check_interval_sec: check_interval
          )
        end

        def build_listen_loop
          ::TbankGrpc::Streaming::Core::Session::ListenLoop.new(
            channel_manager: @channel_manager,
            reconnection_strategy: @reconnection_strategy,
            open_stream: method(:open_stream),
            running: method(:running?),
            stop_running: -> { self.running = false },
            dispatch_response: method(:dispatch_and_track),
            increment_reconnects: method(:increment_reconnects),
            stream_name: stream_key
          )
        end

        def running?
          @state_mutex.synchronize { @running }
        end

        def running=(value)
          @state_mutex.synchronize { @running = value }
        end

        def reconnects
          @state_mutex.synchronize { @reconnects }
        end

        def increment_reconnects
          @state_mutex.synchronize { @reconnects += 1 }
        end

        def touch_last_event
          @state_mutex.synchronize { @last_event_at = Time.now }
        end

        def start_listening!
          @state_mutex.synchronize do
            raise InvalidArgumentError, 'Stream already running' if @running

            @running = true
            @reconnects = 0
          end
        end

        def async_listener_status
          @async_mutex.synchronize { @async_listener&.status }
        end

        def clear_async_listener(listener)
          @async_mutex.synchronize do
            @async_listener = nil if @async_listener.equal?(listener)
          end
        end

        def stream_deadline(method_full_name)
          overrides = @config[:deadline_overrides] || {}
          seconds = overrides[method_full_name] ||
                    overrides[method_full_name.to_s] ||
                    overrides[method_full_name.to_sym]
          return nil if seconds.nil?

          Time.now + seconds.to_f
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
