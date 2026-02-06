# frozen_string_literal: true

module TbankGrpc
  class ChannelManager
    ENDPOINTS = {
      production: 'invest-public-api.tbank.ru:443',
      sandbox: 'sandbox-invest-public-api.tbank.ru:443',
    }.freeze

    attr_reader :channel

    def initialize(config)
      @config = config
      @pool_size = [1, (@config[:channel_pool_size] || 1).to_i].max
      @channel = nil
      @channels = @pool_size > 1 ? Array.new(@pool_size) : nil
      @round_robin = 0
      @mutex = Mutex.new

      TbankGrpc.logger.debug(
        'ChannelManager initialized',
        sandbox: @config[:sandbox],
        pool_size: @pool_size
      )
    end

    def get_channel
      @mutex.synchronize do
        if @pool_size > 1
          idx = @round_robin % @pool_size
          @round_robin += 1
          ch = @channels[idx]
          @channels[idx] = ch if ch && channel_ready?(ch)
          @channels[idx] ||= create_channel
        else
          @channel = nil if @channel && !channel_ready?(@channel)
          @channel ||= create_channel
        end
      end
    end

    def close
      @mutex.synchronize do
        if @pool_size > 1
          @channels.each_with_index do |ch, i|
            next unless ch

            TbankGrpc.logger.info("Closing gRPC channel (pool slot #{i})")
            ch.close
          rescue StandardError
            # ignore errors on close for graceful shutdown
          end
          @channels.fill(nil)
        elsif @channel
          begin
            TbankGrpc.logger.info('Closing gRPC channel')
            @channel.close
          rescue StandardError
            # ignore errors on close for graceful shutdown
          ensure
            @channel = nil
          end
        end
      end
    end

    def connected?
      @mutex.synchronize do
        if @pool_size > 1
          @channels.any? { |ch| ch && channel_ready?(ch) }
        else
          return false unless @channel

          channel_ready?(@channel)
        end
      end
    rescue StandardError => e
      TbankGrpc.logger.warn(
        'Failed to check channel connectivity',
        error: e.message
      )
      false
    end

    def reset
      close
      @channel = nil
      @channels&.fill(nil)
    end

    private

    def channel_ready?(ch)
      state = ch.connectivity_state(false)
      [
        GRPC::Core::ConnectivityStates::IDLE,
        GRPC::Core::ConnectivityStates::READY
      ].include?(state)
    rescue StandardError => e
      TbankGrpc.logger.warn("Failed to check channel state: #{e.message}")
      false
    end

    def create_channel
      TbankGrpc.logger.info('Creating gRPC channel', sandbox: @config[:sandbox])

      credentials = build_credentials
      channel_args = build_channel_args
      endpoint = get_endpoint

      TbankGrpc.logger.debug("Connecting to #{endpoint}")

      GRPC::Core::Channel.new(
        endpoint,
        channel_args,
        credentials
      )
    rescue GRPC::Core::CallError => e
      raise ConnectionFailedError.new(
        "Failed to create gRPC channel: #{e.message}",
        error: e
      )
    end

    def get_endpoint
      endpoint = @config[:endpoint] || default_endpoint
      validate_endpoint!(endpoint)
      endpoint
    end

    def default_endpoint
      @config[:sandbox] ? ENDPOINTS[:sandbox] : ENDPOINTS[:production]
    end

    def validate_endpoint!(endpoint)
      return if endpoint.match?(/\A[\w.-]+:\d+\z/)

      raise ConfigurationError, "Invalid endpoint format: #{endpoint.inspect}. Expected host:port"
    end

    def build_credentials
      cert_path = @config[:cert_path]

      if cert_path.nil? || cert_path == :system
        TbankGrpc.logger.debug('Using system SSL certificates')
        return GRPC::Core::ChannelCredentials.new
      end

      unless File.exist?(cert_path)
        TbankGrpc.logger.warn(
          "Certificate file not found at #{cert_path}, falling back to system certs"
        )
        return GRPC::Core::ChannelCredentials.new
      end

      TbankGrpc.logger.debug("Loading certificate from #{cert_path}")
      cert_data = File.read(cert_path)
      GRPC::Core::ChannelCredentials.new(cert_data)
    rescue StandardError => e
      TbankGrpc.logger.error(
        'Failed to load SSL certificate, using system certs',
        error: e.message
      )
      GRPC::Core::ChannelCredentials.new
    end

    def build_channel_args
      {
        # Message size limits (avoid unbounded memory; Tbank can return large orderbooks/history)
        'grpc.max_send_message_length' => @config[:max_send_message_length] || 10 * 1024 * 1024,      # 10MB
        'grpc.max_receive_message_length' => @config[:max_receive_message_length] || 100 * 1024 * 1024, # 100MB
        # Keepalive: 2 min interval, min_time_between_pings >= keepalive_time to avoid too_many_pings
        'grpc.keepalive_time_ms' => @config[:keepalive_time_ms] || 120_000,
        'grpc.keepalive_timeout_ms' => @config[:keepalive_timeout_ms] || 20_000,
        'grpc.http2.min_time_between_pings_ms' => @config[:min_time_between_pings_ms] || 120_000,
        'grpc.keepalive_permit_without_calls' => 1,
        # Lifecycle: idle 10 min, max age 60 min, 30 s grace to finish RPCs before close
        'grpc.max_connection_idle_ms' => @config[:max_connection_idle_ms] || 600_000,
        'grpc.max_connection_age_ms' => @config[:max_connection_age_ms] || 3_600_000,
        'grpc.max_connection_age_grace_ms' => @config[:max_connection_age_grace_ms] || 30_000,
        'grpc.client_idle_timeout_ms' => @config[:client_idle_timeout_ms] || 600_000
      }
    end
  end
end
