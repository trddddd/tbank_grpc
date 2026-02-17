# frozen_string_literal: true

module TbankGrpc
  # Клиент T-Bank Invest API. Точка входа для сервисов и хелперов.
  #
  # @example
  #   TbankGrpc.configure do |c|
  #     c.token = ENV['TINKOFF_TOKEN']
  #     c.app_name = 'my_app'
  #   end
  #   client = TbankGrpc::Client.new
  #   instrument = client.instruments.get_instrument_by(id_type: :figi, id: 'BBG004730N88')
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
      @users ||= Services::UsersService.new(
        @channel_manager.channel,
        @config,
        interceptors: @interceptors
      )
    end

    # Доступ к сервису инструментов.
    #
    # @return [Services::InstrumentsService]
    def instruments
      @instruments ||= Services::InstrumentsService.new(
        @channel_manager.channel,
        @config,
        interceptors: @interceptors
      )
    end

    # Доступ к сервису рыночных данных.
    #
    # @return [Services::MarketDataService]
    def market_data
      @market_data ||= Services::MarketDataService.new(
        @channel_manager.channel,
        @config,
        interceptors: @interceptors
      )
    end

    # Фасад прикладных helper-утилит.
    #
    # @return [Helpers::Facade]
    def helpers
      @helpers ||= Helpers::Facade.new(self)
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
      @channel_manager.close
    end

    # Пересоздаёт канал и кэш сервисов после close. Нужен только если канал был явно закрыт.
    # В обычной работе gRPC сам переподключается;
    def reconnect
      close
      clear_service_cache

      @channel_manager = ChannelManager.new(@config)

      TbankGrpc.logger.info('TbankGrpc client reconnected')
    end

    private

    def clear_service_cache
      @users = nil
      @instruments = nil
      @market_data = nil
      @helpers = nil
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
end
