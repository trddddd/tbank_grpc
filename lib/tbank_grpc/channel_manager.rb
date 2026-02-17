# frozen_string_literal: true

require 'json'

module TbankGrpc
  # Пул gRPC-каналов (round-robin), создание канала с SSL/keepalive.
  # @api private
  class ChannelManager
    ENDPOINTS = {
      production: 'invest-public-api.tbank.ru:443',
      sandbox: 'sandbox-invest-public-api.tbank.ru:443'
    }.freeze

    # @param config [Hash] конфигурация (endpoint, cert_path, channel_pool_size и т.д.)
    def initialize(config)
      @config = config
      @pool_size = [@config.fetch(:channel_pool_size, 1).to_i, 1].max
      @channels = Array.new(@pool_size)
      @round_robin = 0
      @mutex = Mutex.new

      TbankGrpc.logger.debug(
        'ChannelManager initialized',
        sandbox: @config[:sandbox],
        pool_size: @pool_size
      )
    end

    # @return [GRPC::Core::Channel] канал из пула (round-robin)
    def get_channel
      @mutex.synchronize do
        idx = @round_robin % @pool_size
        @round_robin += 1
        @channels[idx] ||= create_channel
      end
    end

    # Закрывает все каналы в пуле.
    # @return [void]
    def close
      @mutex.synchronize do
        @channels.compact.each_with_index do |ch, i|
          TbankGrpc.logger.info("Closing gRPC channel (slot #{i})")
          ch.close
        rescue StandardError => e
          TbankGrpc.logger.warn("Error closing channel: #{e.message}")
        end
        @channels.fill(nil)
      end
    end

    # @return [Boolean] есть ли хотя бы один канал в состоянии IDLE/READY
    def connected?
      @mutex.synchronize do
        @channels.compact.any? { |ch| channel_ready?(ch) }
      end
    rescue StandardError => e
      TbankGrpc.logger.warn('Failed to check connectivity', error: e.message)
      false
    end

    def reset
      close
    end

    private

    def channel_ready?(ch)
      state = ch.connectivity_state(false)
      [
        GRPC::Core::ConnectivityStates::IDLE,
        GRPC::Core::ConnectivityStates::READY
      ].include?(state)
    rescue StandardError => e
      TbankGrpc.logger.debug("Channel state check failed: #{e.message}")
      false
    end

    def create_channel
      endpoint = get_endpoint
      credentials = @config[:insecure] ? :this_channel_is_insecure : build_credentials
      channel_args = build_channel_args

      TbankGrpc.logger.info("Creating gRPC channel to #{endpoint}", sandbox: @config[:sandbox])

      GRPC::Core::Channel.new(endpoint, channel_args, credentials)
    rescue ConfigurationError
      raise
    rescue StandardError => e
      raise ConnectionFailedError.new(
        "Failed to create gRPC channel: #{e.message}",
        error: e
      )
    end

    def get_endpoint
      endpoint = @config[:endpoint] || (@config[:sandbox] ? ENDPOINTS[:sandbox] : ENDPOINTS[:production])

      unless endpoint.match?(/\A[\w.-]+:\d+\z/)
        raise ConfigurationError,
              "Invalid endpoint format: #{endpoint.inspect}. Expected host:port"
      end

      endpoint
    end

    def build_credentials
      cert_path = @config[:cert_path]

      if cert_path.nil? || cert_path == :system
        TbankGrpc.logger.debug('Using system SSL certificates')
        return GRPC::Core::ChannelCredentials.new
      end

      unless File.exist?(cert_path)
        TbankGrpc.logger.warn("Certificate not found at #{cert_path}, using system certs")
        return GRPC::Core::ChannelCredentials.new
      end

      TbankGrpc.logger.debug("Loading certificate from #{cert_path}")
      GRPC::Core::ChannelCredentials.new(File.read(cert_path))
    rescue StandardError => e
      TbankGrpc.logger.error('Failed to load SSL certificate', error: e.message)
      GRPC::Core::ChannelCredentials.new
    end

    def build_channel_args
      {
        # Message size limits for large orderbooks/history
        'grpc.max_receive_message_length' => @config[:max_message_size] || 50_000_000,
        'grpc.max_send_message_length' => @config[:max_message_size] || 50_000_000,

        # Keepalive: prevent idle connection drops
        'grpc.keepalive_time_ms' => @config[:keepalive_time_ms] || 60_000,
        'grpc.keepalive_timeout_ms' => @config[:keepalive_timeout_ms] || 10_000,
        'grpc.keepalive_permit_without_calls' => 1,

        # Connection lifecycle
        'grpc.max_connection_idle_ms' => @config[:max_connection_idle_ms] || 600_000,
        'grpc.max_connection_age_ms' => @config[:max_connection_age_ms] || 3_600_000
      }.merge(retry_config)
    end

    def retry_config
      return {} if @config[:enable_retries] == false

      max_attempts = @config[:retry_attempts] || 3

      {
        'grpc.enable_retries' => 1,
        'grpc.service_config' => JSON.generate({
                                                 'methodConfig' => [{
                                                   'name' => [{}],
                                                   'retryPolicy' => {
                                                     'maxAttempts' => max_attempts,
                                                     'initialBackoff' => '0.1s',
                                                     'maxBackoff' => '1s',
                                                     'backoffMultiplier' => 2,
                                                     'retryableStatusCodes' => ['UNAVAILABLE']
                                                   }
                                                 }]
                                               })
      }
    end
  end
end
