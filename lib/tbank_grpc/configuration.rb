# frozen_string_literal: true

module TbankGrpc
  # Конфигурация клиента: токен, эндпоинт, таймауты, SSL, логирование.
  # Задаётся через {TbankGrpc.configure} или при создании {Client}.
  class Configuration
    # @!attribute [rw] token
    #   @return [String, nil] OAuth-токен T-Bank Invest API
    # @!attribute [rw] sandbox
    #   @return [Boolean] использовать sandbox (по умолчанию false)
    # @!attribute [rw] app_name
    #   @return [String] имя приложения (обязательно)
    # @!attribute [rw] endpoint
    #   @return [String, nil] host:port (по умолчанию берётся из sandbox)
    attr_accessor :token, :sandbox, :app_name, :endpoint

    # @!attribute [rw] timeout
    #   @return [Integer, Float] общий таймаут в секундах (по умолчанию 30)
    # @!attribute [rw] retry_attempts
    #   @return [Integer] число повторов при rate limit (по умолчанию 3)
    # @!attribute [rw] enable_retries
    #   @return [Boolean] включить gRPC retry по UNAVAILABLE
    # @!attribute [rw] deadline_overrides
    #   @return [Hash] переопределение дедлайнов по сервису/методу (секунды)
    attr_accessor :timeout, :retry_attempts, :enable_retries, :deadline_overrides

    # @!attribute [rw] stream_idle_timeout
    # @!attribute [rw] stream_watchdog_interval_sec
    attr_accessor :stream_idle_timeout, :stream_watchdog_interval_sec

    # @!attribute [rw] channel_pool_size
    #   @return [Integer] размер пула каналов (по умолчанию 1)
    # @!attribute [rw] max_message_size
    #   @return [Integer] макс. размер сообщения в байтах (по умолчанию 50MB)
    attr_accessor :channel_pool_size, :max_message_size

    # @!attribute [rw] keepalive_time_ms
    # @!attribute [rw] keepalive_timeout_ms
    # @!attribute [rw] max_connection_idle_ms
    # @!attribute [rw] max_connection_age_ms
    attr_accessor :keepalive_time_ms, :keepalive_timeout_ms,
                  :max_connection_idle_ms, :max_connection_age_ms

    # @!attribute [rw] cert_path
    #   @return [String, nil] путь к PEM сертификата или :system
    # @!attribute [rw] insecure
    #   @return [Boolean] отключить SSL (только для отладки)
    attr_accessor :cert_path, :insecure

    # @!attribute [rw] log_level
    #   @return [Symbol] :debug, :info, :warn, :error
    # @!attribute [rw] logger
    #   @return [Logger, nil] кастомный логгер
    attr_accessor :log_level
    attr_writer :logger

    # Создаёт конфигурацию с дефолтными значениями.
    def initialize
      # Core
      @token = nil
      @sandbox = false
      @app_name = 'trddddd.tbank_grpc'
      @endpoint = nil

      # Timeouts & retries
      @timeout = 30
      @retry_attempts = 3
      @enable_retries = true
      @deadline_overrides = {}

      # Streaming
      @stream_idle_timeout = nil
      @stream_watchdog_interval_sec = nil

      # Channel
      @channel_pool_size = 1
      @max_message_size = 50_000_000 # 50MB default

      # Connection tuning (nil = use gRPC defaults)
      @keepalive_time_ms = nil
      @keepalive_timeout_ms = nil
      @max_connection_idle_ms = nil
      @max_connection_age_ms = nil

      # SSL
      @cert_path = nil
      @insecure = false

      # Logging
      @log_level = :info
      @logger = nil
    end

    # @return [Logger] логгер (по умолчанию stdout с префиксом [TbankGrpc])
    def logger
      @logger ||= setup_default_logger
    end

    # @return [Hash] конфигурация в виде Hash (для передачи в клиент/канал)
    def to_h
      {
        token: @token,
        sandbox: @sandbox,
        app_name: @app_name,
        endpoint: @endpoint,
        timeout: @timeout,
        retry_attempts: @retry_attempts,
        enable_retries: @enable_retries,
        deadline_overrides: @deadline_overrides,
        stream_idle_timeout: @stream_idle_timeout,
        stream_watchdog_interval_sec: @stream_watchdog_interval_sec,
        channel_pool_size: @channel_pool_size,
        max_message_size: @max_message_size,
        keepalive_time_ms: @keepalive_time_ms,
        keepalive_timeout_ms: @keepalive_timeout_ms,
        max_connection_idle_ms: @max_connection_idle_ms,
        max_connection_age_ms: @max_connection_age_ms,
        cert_path: @cert_path,
        insecure: @insecure,
        log_level: @log_level
      }
    end

    private

    def setup_default_logger
      require 'logger'

      raw = Logger.new($stdout)

      raw.level = {
        debug: Logger::DEBUG,
        info: Logger::INFO,
        warn: Logger::WARN,
        error: Logger::ERROR
      }[@log_level.to_sym] || Logger::INFO

      LoggerWrapper.new(raw)
    end
  end

  # Обёртка логгера с префиксом [TbankGrpc] и поддержкой keyword-аргументов.
  # @api private
  class LoggerWrapper
    # @param logger [Logger]
    def initialize(logger)
      @logger = logger
    end

    %i[debug info warn error].each do |level|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{level}(msg, **meta)
          out = meta.empty? ? msg : "\#{msg} \#{meta.map { |k, v| "\#{k}=\#{v}" }.join(' ')}"
          @logger.public_send(:#{level}, "[TbankGrpc] \#{out}")
        end
      RUBY
    end
  end

  class << self
    # @return [Configuration, nil]
    attr_accessor :configuration

    # Глобальная настройка. Блок опционален.
    # @yield [configuration] блок для установки полей конфигурации
    # @return [Configuration]
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Сбрасывает конфигурацию к дефолтам.
    # @return [Configuration]
    def reset_configuration
      @configuration = Configuration.new
    end

    # @return [Logger] логгер из текущей конфигурации
    def logger
      configuration.logger
    end
  end

  configure
end
