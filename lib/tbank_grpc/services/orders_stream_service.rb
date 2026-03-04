# frozen_string_literal: true

module TbankGrpc
  module Services
    # Фасад server-side stream сервиса ордеров.
    #
    # Доступны два потока:
    # - {#order_state_stream} — статусы заявок
    # - {#trades_stream} — сделки пользователя по заявкам
    class OrdersStreamService
      # @return [ChannelManager]
      attr_reader :channel_manager
      # @return [Hash]
      attr_reader :config

      # @param channel_manager [ChannelManager]
      # @param config [Hash]
      # @param interceptors [Array<GRPC::ClientInterceptor>]
      def initialize(channel_manager:, config:, interceptors:)
        @channel_manager = channel_manager
        @config = config
        @server_stream_service = Streaming::Orders::ServerStreamService.new(
          channel_manager: channel_manager,
          config: config,
          interceptors: interceptors
        )
      end

      # @param as [Symbol] :proto или :model
      # @param account_ids [Array<String>, String, nil]
      # @param account_id [String, nil]
      # @param accounts [Array<String>, String, nil]
      # @param ping_delay_ms [Integer, nil] alias для ping_delay_millis
      # @param ping_delay_millis [Integer, nil] 1000..120000 (OrderStateStream)
      # @yield [payload] при as: :model обязателен
      # @return [Enumerator, nil]
      # rubocop:disable Metrics/ParameterLists
      def order_state_stream(
        as: :proto,
        account_ids: nil,
        account_id: nil,
        accounts: nil,
        ping_delay_ms: nil,
        ping_delay_millis: nil,
        &
      )
        @server_stream_service.order_state_stream(
          as: as,
          account_ids: account_ids,
          account_id: account_id,
          accounts: accounts,
          ping_delay_ms: ping_delay_ms,
          ping_delay_millis: ping_delay_millis,
          &
        )
      end
      # rubocop:enable Metrics/ParameterLists

      # @param as [Symbol] :proto или :model
      # @param account_ids [Array<String>, String, nil]
      # @param account_id [String, nil]
      # @param accounts [Array<String>, String, nil]
      # @param ping_delay_ms [Integer, nil] 5000..180000
      # @yield [payload] при as: :model обязателен
      # @return [Enumerator, nil]
      def trades_stream(as: :proto, account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, &)
        @server_stream_service.trades_stream(
          as: as,
          account_ids: account_ids,
          account_id: account_id,
          accounts: accounts,
          ping_delay_ms: ping_delay_ms,
          &
        )
      end
    end
  end
end
