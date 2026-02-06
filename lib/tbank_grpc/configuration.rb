# frozen_string_literal: true

module TbankGrpc
  class Configuration
    attr_accessor :token, :sandbox, :app_name, :endpoint, :timeout, :retry_attempts,
                  :log_level, :logger, :cert_path, :stream_idle_timeout, :stream_watchdog_interval_sec,
                  :channel_pool_size, :logger, :cert_path, :stream_idle_timeout,
                  :stream_watchdog_interval_sec, :channel_pool_size, :keepalive_time_ms,
                  :keepalive_timeout_ms, :min_time_between_pings_ms, :max_connection_idle_ms,
                  :max_connection_age_ms, :client_idle_timeout_ms

    def initialize
      @token = nil
      @sandbox = false
      @app_name = 'trddddd.tbank_grpc'
      @endpoint = nil
      @timeout = 30
      @retry_attempts = 3
      @log_level = :info
      @stream_idle_timeout = nil
      @stream_watchdog_interval_sec = nil
      @channel_pool_size = 1
      @cert_path = nil
      @keepalive_time_ms = nil
      @keepalive_timeout_ms = nil
      @min_time_between_pings_ms = nil
      @max_connection_idle_ms = nil
      @max_connection_age_ms = nil
      @client_idle_timeout_ms = nil
      @logger = nil
    end

    def logger
      @logger ||= setup_default_logger
    end

    def to_h
      {
        token: @token,
        sandbox: @sandbox,
        app_name: @app_name,
        endpoint: @endpoint,
        timeout: @timeout,
        retry_attempts: @retry_attempts,
        log_level: @log_level,
        cert_path: @cert_path,
        stream_idle_timeout: @stream_idle_timeout,
        stream_watchdog_interval_sec: @stream_watchdog_interval_sec,
        channel_pool_size: @channel_pool_size,
        keepalive_time_ms: @keepalive_time_ms,
        keepalive_timeout_ms: @keepalive_timeout_ms,
        min_time_between_pings_ms: @min_time_between_pings_ms,
        max_connection_idle_ms: @max_connection_idle_ms,
        max_connection_age_ms: @max_connection_age_ms,
        client_idle_timeout_ms: @client_idle_timeout_ms
      }
    end

    private

    def setup_default_logger
      require 'logger'
      raw = Logger.new($stdout)
      raw.level = level_constant(@log_level)
      LoggerWrapper.new(raw)
    end

    def level_constant(level)
      levels = { debug: Logger::DEBUG, info: Logger::INFO, warn: Logger::WARN, error: Logger::ERROR }
      levels[level.to_sym] || Logger::INFO
    end
  end

  class LoggerWrapper
    def initialize(logger)
      @logger = logger
    end

    %i[debug info warn error].each do |level|
      define_method(level) do |msg, **meta|
        out = meta.empty? ? msg : "#{msg} #{meta.map { |k, v| "#{k}=#{v}" }.join(' ')}"
        @logger.public_send(level, "[TbankGrpc] #{out}")
      end
    end
  end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration
      @configuration = Configuration.new
    end

    def logger
      configuration.logger
    end
  end

  configure
end
