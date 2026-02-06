# frozen_string_literal: true

module TbankGrpc
  class Client
    attr_reader :config, :channel_manager

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

    def connected?
      @channel_manager.connected?
    end

    def close
      TbankGrpc.logger.info('Closing TbankGrpc client')
      @channel_manager.close
    end

    private

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
        Interceptors::AuthInterceptor.new(@config[:token]),
        Interceptors::AppNameInterceptor.new(@config[:app_name]),
        Interceptors::LoggingInterceptor.new
      ]
    end
  end
end
