# frozen_string_literal: true

module TbankGrpc
  # Клиент T-Bank Invest API. Точка входа для сервисов и хелперов.
  #
  # Unary-сервисы (users, instruments, market_data) используют общий {#channel_manager}.
  # Стримы (market_data_stream) — отдельный менеджер через {#stream_channel_manager};
  # один channel технически мог бы обслуживать и unary, и стримы; разделение нужно для
  # изоляции lifecycle, reconnect и пулов.
  #
  # @example
  #   TbankGrpc.configure do |c|
  #     c.token = ENV['TBANK_TOKEN']
  #     c.app_name = 'trddddd.tbank_grpc'
  #   end
  #   client = TbankGrpc::Client.new
  #   instrument = client.instruments.get_instrument_by(id_type: :figi, id: 'BBG004730N88')
  # rubocop:disable Metrics/ClassLength
  class Client
    # @return [Hash] конфигурация клиента (token, app_name, timeout и т.д.)
    attr_reader :config
    # @return [ChannelManager] менеджер gRPC-каналов
    attr_reader :channel_manager

    # @param config [Hash] переопределение конфигурации (объединяется с TbankGrpc.configuration)
    # @raise [ConfigurationError] если не заданы token или app_name
    def initialize(config = {})
      merge_and_validate_config(config)

      @thread_pool_size = @config[:thread_pool_size] || 4
      @channel_manager = ChannelManager.new(@config)
      @interceptors = build_interceptors
      @services_mutex = Mutex.new
      @stream_channel_managers_mutex = Mutex.new
      @stream_channel_managers = {}

      TbankGrpc.logger.debug(
        'Client channel manager bound',
        purpose: 'unary',
        manager: @channel_manager.manager_id
      )

      TbankGrpc.logger.info(
        'TbankGrpc client initialized',
        app_name: @config[:app_name],
        sandbox: @config[:sandbox],
        thread_pool_size: @thread_pool_size
      )
    end

    # Доступ к сервису пользователя.
    #
    # @return [Services::UsersService]
    def users
      @services_mutex.synchronize do
        @users ||= Services::UsersService.new(
          @channel_manager.channel,
          @config,
          interceptors: @interceptors
        )
      end
    end

    # Доступ к сервису инструментов.
    #
    # @return [Services::InstrumentsService]
    def instruments
      @services_mutex.synchronize do
        @instruments ||= Services::InstrumentsService.new(
          @channel_manager.channel,
          @config,
          interceptors: @interceptors
        )
      end
    end

    # Доступ к сервису рыночных данных.
    #
    # @return [Services::MarketDataService]
    def market_data
      @services_mutex.synchronize do
        @market_data ||= Services::MarketDataService.new(
          @channel_manager.channel,
          @config,
          interceptors: @interceptors
        )
      end
    end

    # Доступ к сервису операций (портфель, позиции, операции, отчёты).
    #
    # @return [Services::OperationsService]
    def operations
      @services_mutex.synchronize do
        @operations ||= Services::OperationsService.new(
          @channel_manager.channel,
          @config,
          interceptors: @interceptors
        )
      end
    end

    # Доступ к bidirectional stream сервиса рыночных данных.
    # Использует отдельный ChannelManager (stream_channel_manager(:market_data)), не общий пул unary.
    #
    # @return [Services::MarketDataStreamService]
    def market_data_stream
      @services_mutex.synchronize do
        @market_data_stream ||= Services::MarketDataStreamService.new(
          channel_manager: stream_channel_manager(:market_data),
          config: @config,
          interceptors: @interceptors,
          thread_pool_size: @thread_pool_size
        )
      end
    end

    # Подписка на стакан по одному инструменту.
    #
    # @param instrument_id [String]
    # @param depth [Integer]
    # @param order_book_type [Symbol, Integer]
    # @return [void]
    def stream_orderbook(instrument_id:, depth: 20, order_book_type: :ORDERBOOK_TYPE_ALL)
      market_data_stream.subscribe_orderbook(
        instrument_id: instrument_id,
        depth: depth,
        order_book_type: order_book_type
      )
    end

    # Подписка на свечи.
    #
    # @param instrument_id [String]
    # @param interval [Symbol, Integer]
    # @param waiting_close [Boolean]
    # @param candle_source_type [Symbol, Integer, nil]
    # @return [void]
    def stream_candles(instrument_id:, interval:, waiting_close: false, candle_source_type: nil)
      market_data_stream.subscribe_candles(
        instrument_id: instrument_id,
        interval: interval,
        waiting_close: waiting_close,
        candle_source_type: candle_source_type
      )
    end

    # Подписка на сделки.
    #
    # @param instrument_ids [Array<String>]
    # @param trade_source [Symbol, Integer]
    # @param with_open_interest [Boolean]
    # @return [void]
    def stream_trades(*instrument_ids, trade_source: :TRADE_SOURCE_ALL, with_open_interest: false)
      market_data_stream.subscribe_trades(
        *instrument_ids,
        trade_source: trade_source,
        with_open_interest: with_open_interest
      )
    end

    # Подписка на trading status.
    #
    # @param instrument_ids [Array<String>]
    # @return [void]
    def stream_info(*instrument_ids)
      market_data_stream.subscribe_info(*instrument_ids)
    end

    # Подписка на last price.
    #
    # @param instrument_ids [Array<String>]
    # @return [void]
    def stream_last_price(*instrument_ids)
      market_data_stream.subscribe_last_price(*instrument_ids)
    end

    # Асинхронный запуск стрима в фоновом потоке.
    #
    # @return [Thread]
    def listen_to_stream_async
      market_data_stream.listen_async
    end

    # Синхронный блокирующий запуск стрима.
    #
    # @return [void]
    def listen_to_stream
      market_data_stream.listen
    end

    # Остановка запущенного стрима.
    #
    # @return [void]
    def stop_stream
      market_data_stream.stop_async
    end

    # Общая статистика и метрики стрима.
    #
    # Если `stream_metrics_enabled = false`, возвращается zero-shape:
    # те же ключи, но нулевые/пустые значения.
    #
    # @return [Hash]
    def stream_metrics
      market_data_stream.stats
    end

    # Метрики по типу события.
    #
    # Если `stream_metrics_enabled = false`, возвращается zero-shape:
    # те же ключи, но нулевые значения.
    #
    # @param event_type [Symbol]
    # @return [Hash]
    def stream_event_stats(event_type)
      market_data_stream.event_stats(event_type)
    end

    # Фасад прикладных helper-утилит.
    #
    # @return [Helpers::Facade]
    def helpers
      @services_mutex.synchronize do
        @helpers ||= Helpers::Facade.new(self)
      end
    end

    # Проверка наличия готового gRPC-канала.
    # @return [Boolean]
    def connected?
      @channel_manager.connected?
    end

    # Закрывает все gRPC-каналы. После вызова для новых запросов нужен {#reconnect}.
    # @return [void]
    def close
      TbankGrpc.logger.info('Closing TbankGrpc client')
      close_all_channel_managers
    end

    # Пересоздаёт канал и кэш сервисов после close. Нужен только если канал был явно закрыт.
    # В обычной работе gRPC сам переподключается.
    # После reconnect активные итерации по market_data stream могут упасть — запускайте стрим заново.
    def reconnect
      stop_active_streams
      close_all_channel_managers
      clear_service_cache
      clear_stream_channel_managers

      @channel_manager = ChannelManager.new(@config)

      TbankGrpc.logger.debug(
        'Client channel manager bound',
        purpose: 'unary',
        manager: @channel_manager.manager_id
      )

      TbankGrpc.logger.info('TbankGrpc client reconnected')
    end

    private

    def clear_service_cache
      @services_mutex.synchronize do
        @users = nil
        @instruments = nil
        @market_data = nil
        @market_data_stream = nil
        @operations = nil
        @helpers = nil
      end
    end

    def clear_stream_channel_managers
      @stream_channel_managers_mutex&.synchronize do
        @stream_channel_managers = nil
      end
    end

    def stop_active_streams
      active_stream = @services_mutex.synchronize { @market_data_stream }
      {
        market_data_stream: active_stream
      }.each do |(name, service)|
        next unless service

        service.stop_async
      rescue StandardError => e
        TbankGrpc.logger.warn("Failed to stop #{name} before reconnect", error: e.message)
      end
    end

    # Ленивый пул ChannelManager по ключу стрима (:market_data и т.д.).
    # @param stream_key [Symbol, String]
    # @return [ChannelManager]
    def stream_channel_manager(stream_key)
      key = stream_key.to_sym
      @stream_channel_managers_mutex.synchronize do
        @stream_channel_managers ||= {}
        @stream_channel_managers[key] ||= begin
          manager = ChannelManager.new(@config)
          TbankGrpc.logger.debug(
            'Client channel manager bound',
            purpose: "stream:#{key}",
            manager: manager.manager_id
          )
          manager
        end
      end
    end

    def close_all_channel_managers
      stream_managers = @stream_channel_managers_mutex.synchronize do
        (@stream_channel_managers || {}).values.dup
      end
      managers = [@channel_manager]
      managers.concat(stream_managers)
      managers.compact.uniq.each do |manager|
        manager.close
      rescue StandardError => e
        TbankGrpc.logger.warn('Failed to close channel manager', error: e.message)
      end
    end

    def merge_and_validate_config(user_config)
      global_config = TbankGrpc.configuration.to_h
      @config = global_config.merge(user_config)

      validate_required_fields!
    end

    def validate_required_fields!
      if @config[:token].nil? || @config[:token].to_s.strip.empty?
        raise ConfigurationError, 'Token is required. Set via TbankGrpc.configure or initialization parameter'
      end

      return unless @config[:app_name].nil? || @config[:app_name].to_s.strip.empty?

      raise ConfigurationError, 'App name is required. Set via TbankGrpc.configure or initialization parameter'
    end

    def build_interceptors
      [
        Interceptors::Metadata.new(token: @config[:token], app_name: @config[:app_name]),
        Interceptors::Logging.new
      ]
    end
  end
  # rubocop:enable Metrics/ClassLength
end
