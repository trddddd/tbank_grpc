# frozen_string_literal: true

module TbankGrpc
  module Services
    # Фасад поверх bidirectional и server-side stream сервисов рыночных данных.
    #
    # Подробно по семантике и ограничениям:
    # @see docs/market_data_streaming.md
    class MarketDataStreamService
      EVENT_TYPES = Streaming::MarketData::BidiService::EVENT_TYPES
      MODEL_EVENT_TYPES = Streaming::MarketData::BidiService::MODEL_EVENT_TYPES
      REQUEST_POP_TIMEOUT_SEC = Streaming::MarketData::BidiService::REQUEST_POP_TIMEOUT_SEC

      # @return [ChannelManager]
      attr_reader :channel_manager
      # @return [Hash]
      attr_reader :config

      # @param channel_manager [ChannelManager]
      # @param config [Hash]
      # @param interceptors [Array<GRPC::ClientInterceptor>]
      # @param thread_pool_size [Integer]
      def initialize(channel_manager:, config:, interceptors:, thread_pool_size: 4)
        @channel_manager = channel_manager
        @config = config
        @bidi_service = Streaming::MarketData::BidiService.new(
          channel_manager: channel_manager,
          config: config,
          interceptors: interceptors,
          thread_pool_size: thread_pool_size
        )
        @server_stream_service = Streaming::MarketData::ServerStreamService.new(
          channel_manager: channel_manager,
          config: config,
          interceptors: interceptors
        )
      end

      def event_loop
        @bidi_service.event_loop
      end

      def subscription_manager
        @bidi_service.subscription_manager
      end

      def reconnection_strategy
        @bidi_service.reconnection_strategy
      end

      def on(event_type, as: nil, &)
        @bidi_service.on(event_type, as: as, &)
        self
      end

      def metrics
        @bidi_service.metrics
      end

      def stats
        @bidi_service.stats
      end

      def event_stats(event_type)
        @bidi_service.event_stats(event_type)
      end

      def subscribe_orderbook(instrument_id:, depth: 20, order_book_type: :ORDERBOOK_TYPE_ALL)
        @bidi_service.subscribe_orderbook(
          instrument_id: instrument_id,
          depth: depth,
          order_book_type: order_book_type
        )
      end

      def subscribe_candles(instrument_id:, interval:, waiting_close: false, candle_source_type: nil)
        @bidi_service.subscribe_candles(
          instrument_id: instrument_id,
          interval: interval,
          waiting_close: waiting_close,
          candle_source_type: candle_source_type
        )
      end

      def subscribe_trades(*instrument_ids, trade_source: :TRADE_SOURCE_ALL, with_open_interest: false)
        @bidi_service.subscribe_trades(
          *instrument_ids,
          trade_source: trade_source,
          with_open_interest: with_open_interest
        )
      end

      def subscribe_info(*instrument_ids)
        @bidi_service.subscribe_info(*instrument_ids)
      end

      def subscribe_last_price(*instrument_ids)
        @bidi_service.subscribe_last_price(*instrument_ids)
      end

      def unsubscribe_orderbook(instrument_id:, depth: 20, order_book_type: :ORDERBOOK_TYPE_ALL)
        @bidi_service.unsubscribe_orderbook(
          instrument_id: instrument_id,
          depth: depth,
          order_book_type: order_book_type
        )
      end

      def unsubscribe_candles(instrument_id:, interval:, waiting_close: false, candle_source_type: nil)
        @bidi_service.unsubscribe_candles(
          instrument_id: instrument_id,
          interval: interval,
          waiting_close: waiting_close,
          candle_source_type: candle_source_type
        )
      end

      def unsubscribe_trades(*instrument_ids, trade_source: :TRADE_SOURCE_ALL, with_open_interest: false)
        @bidi_service.unsubscribe_trades(
          *instrument_ids,
          trade_source: trade_source,
          with_open_interest: with_open_interest
        )
      end

      def unsubscribe_info(*instrument_ids)
        @bidi_service.unsubscribe_info(*instrument_ids)
      end

      def unsubscribe_last_price(*instrument_ids)
        @bidi_service.unsubscribe_last_price(*instrument_ids)
      end

      def my_subscriptions
        @bidi_service.my_subscriptions
      end
      alias get_my_subscriptions my_subscriptions

      def current_subscriptions
        @bidi_service.current_subscriptions
      end

      def send_ping(time: nil)
        @bidi_service.send_ping(time: time)
      end

      def set_ping_delay(milliseconds: nil, **)
        @bidi_service.set_ping_delay(milliseconds: milliseconds, **)
      end

      def listen_async
        @bidi_service.listen_async
      end

      def stop_async
        @bidi_service.stop_async
      end

      def listen_sync
        @bidi_service.listen_sync
      end

      def listen
        @bidi_service.listen
      end

      def stop
        @bidi_service.stop
      end

      def force_reconnect
        @bidi_service.force_reconnect
      end

      def listening?
        @bidi_service.listening?
      end

      def last_event_at
        @bidi_service.last_event_at
      end

      def market_data_server_side_stream(as: :proto, **, &)
        @server_stream_service.market_data_server_side_stream(as: as, **, &)
      end
    end
  end
end
