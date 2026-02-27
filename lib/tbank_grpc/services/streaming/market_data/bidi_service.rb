# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      module MarketData
        # Bidirectional стриминг рыночных данных (подписки, свечи, стаканы, сделки и т.д.).
        #
        # Подробно по семантике и ограничениям:
        # @see docs/market_data_streaming.md
        # rubocop:disable Metrics/ClassLength
        class BidiService < BaseBidiStreamService
          EVENT_TYPES = %i[
            candle orderbook trade trading_status last_price open_interest ping subscription_status
          ].freeze
          MODEL_EVENT_TYPES = %i[candle orderbook trade trading_status last_price open_interest].freeze
          REQUEST_POP_TIMEOUT_SEC = 0.25

          # @return [Streaming::MarketData::Subscriptions::Manager]
          attr_reader :subscription_manager

          # @param channel_manager [ChannelManager]
          # @param config [Hash]
          # @param interceptors [Array<GRPC::ClientInterceptor>]
          # @param thread_pool_size [Integer]
          def initialize(channel_manager:, config:, interceptors:, thread_pool_size: 4)
            ProtoLoader.require!('marketdata')
            @subscription_manager = ::TbankGrpc::Streaming::MarketData::Subscriptions::Manager.new
            @model_mapper = ::TbankGrpc::Streaming::MarketData::Responses::ModelMapper.new
            super
            @event_router = ::TbankGrpc::Streaming::MarketData::Responses::EventRouter.new(
              event_loop: @event_loop,
              model_mapper: @model_mapper
            )
          end

          # Подписка на события стрима. Вызывать до {#listen} / {#listen_async}.
          #
          # @param event_type [Symbol, String] один из EVENT_TYPES
          # @param as [Symbol, nil] :proto или :model (для событий из MODEL_EVENT_TYPES);
          #   по умолчанию :model где применимо
          # @yield [payload] при наступлении события
          # @return [self]
          # @raise [InvalidArgumentError] при неверном event_type или as: :model для неподдерживаемого типа
          def on(event_type, as: nil, &)
            normalized_event = normalize_event_type(event_type)
            format = resolve_payload_format(normalized_event, as)
            validate_model_format!(normalized_event, format)
            @event_loop.on(normalized_event, as: format, &)
            self
          end

          # @return [Hash] super + subscriptions (текущее число подписок)
          def stats
            super.merge(subscriptions: @subscription_manager.total_subscriptions)
          end

          # @param event_type [Symbol, String]
          # @return [Hash] статистика по типу события (count и т.д.)
          def event_stats(event_type)
            @event_loop.metrics.event_stats(normalize_event_type(event_type))
          end

          # @param instrument_id [String] figi или instrument_uid
          # @param depth [Integer]
          # @param order_book_type [Symbol]
          # @return [void]
          def subscribe_orderbook(instrument_id:, depth: 20, order_book_type: :ORDERBOOK_TYPE_ALL)
            @subscription_manager.subscribe(
              :orderbook,
              instrument_id: normalize_instrument_id(instrument_id),
              depth: depth,
              order_book_type: order_book_type
            )
          end

          # @param instrument_id [String]
          # @param interval [String, Symbol] интервал свечей (см. Converters::CandleInterval)
          # @param waiting_close [Boolean]
          # @param candle_source_type [Symbol, nil]
          # @return [void]
          def subscribe_candles(instrument_id:, interval:, waiting_close: false, candle_source_type: nil)
            @subscription_manager.subscribe(
              :candles,
              instrument_id: normalize_instrument_id(instrument_id),
              interval: interval,
              waiting_close: waiting_close,
              candle_source_type: candle_source_type
            )
          end

          # @param instrument_ids [Array<String>] figi или instrument_uid
          # @param trade_source [Symbol]
          # @param with_open_interest [Boolean]
          # @return [void]
          def subscribe_trades(*instrument_ids, trade_source: :TRADE_SOURCE_ALL, with_open_interest: false)
            @subscription_manager.subscribe(
              :trades,
              instrument_ids: normalize_instrument_ids(instrument_ids),
              trade_source: trade_source,
              with_open_interest: with_open_interest
            )
          end

          # @param instrument_ids [Array<String>]
          # @return [void]
          def subscribe_info(*instrument_ids)
            @subscription_manager.subscribe(:info, instrument_ids: normalize_instrument_ids(instrument_ids))
          end

          # @param instrument_ids [Array<String>]
          # @return [void]
          def subscribe_last_price(*instrument_ids)
            @subscription_manager.subscribe(:last_price, instrument_ids: normalize_instrument_ids(instrument_ids))
          end

          # @param instrument_id [String]
          # @param depth [Integer]
          # @param order_book_type [Symbol]
          # @return [void]
          def unsubscribe_orderbook(instrument_id:, depth: 20, order_book_type: :ORDERBOOK_TYPE_ALL)
            @subscription_manager.unsubscribe(
              :orderbook,
              instrument_id: normalize_instrument_id(instrument_id),
              depth: depth,
              order_book_type: order_book_type
            )
          end

          # @param instrument_id [String]
          # @param interval [String, Symbol]
          # @param waiting_close [Boolean]
          # @param candle_source_type [Symbol, nil]
          # @return [void]
          def unsubscribe_candles(instrument_id:, interval:, waiting_close: false, candle_source_type: nil)
            @subscription_manager.unsubscribe(
              :candles,
              instrument_id: normalize_instrument_id(instrument_id),
              interval: interval,
              waiting_close: waiting_close,
              candle_source_type: candle_source_type
            )
          end

          # @param instrument_ids [Array<String>]
          # @param trade_source [Symbol]
          # @param with_open_interest [Boolean]
          # @return [void]
          def unsubscribe_trades(*instrument_ids, trade_source: :TRADE_SOURCE_ALL, with_open_interest: false)
            @subscription_manager.unsubscribe(
              :trades,
              instrument_ids: normalize_instrument_ids(instrument_ids),
              trade_source: trade_source,
              with_open_interest: with_open_interest
            )
          end

          # @param instrument_ids [Array<String>]
          # @return [void]
          def unsubscribe_info(*instrument_ids)
            @subscription_manager.unsubscribe(:info, instrument_ids: normalize_instrument_ids(instrument_ids))
          end

          # @param instrument_ids [Array<String>]
          # @return [void]
          def unsubscribe_last_price(*instrument_ids)
            @subscription_manager.unsubscribe(:last_price, instrument_ids: normalize_instrument_ids(instrument_ids))
          end

          # Запрос списка текущих подписок с сервера (отправляет get_my_subscriptions в стрим).
          # @return [void]
          def my_subscriptions
            @subscription_manager.request_my_subscriptions
          end
          alias get_my_subscriptions my_subscriptions

          # @return [Hash] локальный снимок подписок (тип => массив params)
          def current_subscriptions
            @subscription_manager.current_subscriptions
          end

          # @param time [Time, nil]
          # @return [void]
          def send_ping(time: nil)
            @subscription_manager.send_ping(time: time)
          end

          # @param milliseconds [Integer, nil] задержка пинга в мс (5000..180000)
          # @param options [Hash] поддерживается :ms как альтернатива milliseconds
          # @return [void]
          def set_ping_delay(milliseconds: nil, **options)
            milliseconds = options[:ms] if options.key?(:ms) && milliseconds.nil?
            @subscription_manager.set_ping_delay(milliseconds: milliseconds)
          end

          private

          def stream_key
            'market_data'
          end

          def build_event_loop(thread_pool_size:)
            ::TbankGrpc::Streaming::Core::Dispatch::EventLoop.new(
              thread_pool_size: thread_pool_size,
              metrics: build_stream_metrics_backend
            )
          end

          def dispatch_response(response)
            @event_router.dispatch(response)
          end

          def open_stream
            stub = initialize_stub(@channel_manager.channel)
            deadline = stream_deadline(Grpc::MethodName.full_name(stub, :market_data_stream))
            stub.market_data_stream(request_enumerator, metadata: {}, deadline: deadline)
          end

          def request_enumerator
            Enumerator.new do |yielder|
              @subscription_manager.initial_requests.each { |request| yielder << request }
              loop do
                break unless running?

                request = @subscription_manager.pop_request(timeout_sec: REQUEST_POP_TIMEOUT_SEC)
                yielder << request if request
              end
            end
          end

          def initialize_stub(channel)
            TbankGrpc::CONTRACT_V1::MarketDataStreamService::Stub.new(
              nil,
              :this_channel_is_insecure,
              channel_override: channel,
              interceptors: @interceptors
            )
          end

          def normalize_instrument_id(instrument_id)
            ::TbankGrpc::Streaming::MarketData::Subscriptions::ParamsNormalizer.normalize_instrument_id(instrument_id)
          end

          def normalize_instrument_ids(instrument_ids)
            ::TbankGrpc::Streaming::MarketData::Subscriptions::ParamsNormalizer.normalize_instrument_ids(instrument_ids)
          end

          def normalize_event_type(event_type)
            value = event_type.to_sym
            return value if EVENT_TYPES.include?(value)

            raise InvalidArgumentError, "Unsupported event type: #{event_type.inspect}"
          end

          def resolve_payload_format(event_type, as_option)
            return (MODEL_EVENT_TYPES.include?(event_type) ? :model : :proto) if as_option.nil?

            normalize_payload_format(as_option)
          end

          def normalize_payload_format(format)
            value = format.to_sym
            return value if %i[proto model].include?(value)

            raise InvalidArgumentError, "Unsupported payload format: #{format.inspect}"
          end

          def validate_model_format!(event_type, format)
            return unless format == :model
            return if MODEL_EVENT_TYPES.include?(event_type)

            raise InvalidArgumentError, "as: :model is unsupported for event #{event_type}"
          end

          def build_stream_metrics_backend
            ::TbankGrpc::Streaming::Core::Observability::Metrics.new(enabled: stream_metrics_enabled?)
          end

          def stream_metrics_enabled?
            @config[:stream_metrics_enabled] == true
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
