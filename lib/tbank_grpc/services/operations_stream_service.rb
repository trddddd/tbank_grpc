# frozen_string_literal: true

module TbankGrpc
  module Services
    # Фасад server-side стримов OperationsStreamService:
    # PortfolioStream, PositionsStream, OperationsStream.
    class OperationsStreamService
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
        @server_stream_service = Streaming::Operations::ServerStreamService.new(
          channel_manager: channel_manager,
          config: config,
          interceptors: interceptors
        )
      end

      # @see Streaming::Operations::ServerStreamService#portfolio_stream
      def portfolio_stream(account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, as: :proto, &)
        @server_stream_service.portfolio_stream(
          account_ids: account_ids,
          account_id: account_id,
          accounts: accounts,
          ping_delay_ms: ping_delay_ms,
          as: as,
          &
        )
      end

      # @see Streaming::Operations::ServerStreamService#positions_stream
      # rubocop:disable Metrics/ParameterLists
      def positions_stream(
        account_ids: nil,
        account_id: nil,
        accounts: nil,
        with_initial_positions: false,
        ping_delay_ms: nil,
        as: :proto,
        &
      )
        @server_stream_service.positions_stream(
          account_ids: account_ids,
          account_id: account_id,
          accounts: accounts,
          with_initial_positions: with_initial_positions,
          ping_delay_ms: ping_delay_ms,
          as: as,
          &
        )
      end
      # rubocop:enable Metrics/ParameterLists

      # @see Streaming::Operations::ServerStreamService#operations_stream
      def operations_stream(account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, as: :proto, &)
        @server_stream_service.operations_stream(
          account_ids: account_ids,
          account_id: account_id,
          accounts: accounts,
          ping_delay_ms: ping_delay_ms,
          as: as,
          &
        )
      end
    end
  end
end
