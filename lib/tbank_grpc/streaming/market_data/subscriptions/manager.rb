# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Subscriptions
        # rubocop:disable Metrics/ClassLength
        class Manager
          MAX_SUBSCRIPTIONS = 300
          MAX_SUBSCRIPTION_MUTATIONS_PER_MINUTE = 100
          RATE_WINDOW_SEC = 60.0
          TYPE_MODULE = Tinkoff::Public::Invest::Api::Contract::V1

          attr_reader :request_queue

          def initialize(
            params_normalizer: ParamsNormalizer,
            request_factory: nil,
            registry: nil,
            mutation_limiter: nil
          )
            @params_normalizer = params_normalizer
            @request_factory = request_factory || RequestFactory.new
            @registry = registry || Registry.new(max_subscriptions: MAX_SUBSCRIPTIONS)
            @mutation_limiter = mutation_limiter || MutationLimiter.new(
              max_mutations: MAX_SUBSCRIPTION_MUTATIONS_PER_MINUTE,
              window_sec: RATE_WINDOW_SEC
            )
            @request_queue = Queue.new
            @ping_delay_ms = nil
            @mutex = Mutex.new
          end

          # @return [Array<Hash>] текущий список подписок после операции (даже при no-op)
          def subscribe(type, params)
            normalized = normalize_subscription_params(type, params)
            @mutex.synchronize do
              next current_subscriptions_unsafe if @registry.include?(type, normalized)

              @mutation_limiter.register!
              @registry.ensure_limit!(type, normalized)
              @request_queue << @request_factory.subscription_request(type, normalized, :SUBSCRIPTION_ACTION_SUBSCRIBE)
              @registry.store(type, normalized)
              current_subscriptions_unsafe
            end
          end

          # @return [Array<Hash>] текущий список подписок после операции (даже при no-op)
          def unsubscribe(type, params)
            normalized = normalize_subscription_params(type, params)
            @mutex.synchronize do
              next current_subscriptions_unsafe unless @registry.include?(type, normalized)

              @mutation_limiter.register!
              @request_queue << @request_factory.subscription_request(type, normalized,
                                                                      :SUBSCRIPTION_ACTION_UNSUBSCRIBE)
              @registry.remove(type, normalized)
              current_subscriptions_unsafe
            end
          end

          def request_my_subscriptions
            @mutex.synchronize { @request_queue << @request_factory.my_subscriptions_request }
            nil
          end

          def send_ping(time: nil)
            @mutex.synchronize { @request_queue << @request_factory.ping_request(time: time) }
          end

          def set_ping_delay(milliseconds: nil, **options)
            milliseconds = options[:ms] if options.key?(:ms) && milliseconds.nil?
            normalized = @request_factory.normalize_ping_delay(milliseconds)
            @mutex.synchronize do
              @ping_delay_ms = normalized
              @request_queue << @request_factory.ping_settings_request(normalized)
            end
          end

          def pop_request(timeout_sec: nil)
            return @request_queue.pop(true) if timeout_sec.nil?
            return @request_queue.pop(true) if timeout_sec.to_f <= 0

            @request_queue.pop(timeout: timeout_sec.to_f)
          rescue ThreadError
            nil
          end

          def initial_requests
            @mutex.synchronize do
              prune_startup_queue!

              requests = []
              requests << @request_factory.ping_settings_request(@ping_delay_ms) if @ping_delay_ms

              @registry.each_subscription do |type, params|
                requests << @request_factory.subscription_request(type, params, :SUBSCRIPTION_ACTION_SUBSCRIBE)
              end
              requests
            end
          end

          def total_subscriptions
            @mutex.synchronize { @registry.total_subscriptions }
          end

          # Текущие подписки (локальное состояние Registry) — для инспекции в консоли.
          # @return [Array<Hash>] массив хешей { type: Symbol, ...params }
          def current_subscriptions
            @mutex.synchronize { current_subscriptions_unsafe }
          end

          private

          def current_subscriptions_unsafe
            @registry.each_subscription.map { |type, params| { type: type, **params } }
          end

          def prune_startup_queue!
            preserved = []
            loop do
              request = @request_queue.pop(true)
              preserved << request if keep_request_in_queue_for_startup?(request)
            end
          rescue ThreadError
            preserved.each { |request| @request_queue << request }
          end

          def keep_request_in_queue_for_startup?(request)
            return false if subscription_mutation_request?(request)
            return false if request.ping_settings

            true
          end

          def subscription_mutation_request?(request)
            request.subscribe_order_book_request ||
              request.subscribe_candles_request ||
              request.subscribe_trades_request ||
              request.subscribe_info_request ||
              request.subscribe_last_price_request
          end

          def normalize_subscription_params(type, params)
            case type.to_sym
            when :orderbook
              normalize_orderbook_params(params)
            when :candles
              normalize_candles_params(params)
            when :trades
              normalize_trades_params(params)
            when :info, :last_price
              normalize_multi_id_params(params)
            else
              raise InvalidArgumentError, "Unknown subscription type: #{type}"
            end
          end

          def normalize_multi_id_params(params)
            values = params[:instrument_ids] || params[:instrument_id]
            { instrument_ids: @params_normalizer.normalize_instrument_ids(values) }
          end

          def normalize_orderbook_params(params)
            {
              instrument_id: @params_normalizer.normalize_instrument_id(params[:instrument_id]),
              depth: @params_normalizer.normalize_depth(params.fetch(:depth, 20)),
              order_book_type: @params_normalizer.resolve_order_book_type(params[:order_book_type],
                                                                          type_module: TYPE_MODULE)
            }
          end

          def normalize_candles_params(params)
            {
              instrument_id: @params_normalizer.normalize_instrument_id(params[:instrument_id]),
              interval: @params_normalizer.resolve_subscription_interval(params[:interval], type_module: TYPE_MODULE),
              waiting_close: !params.fetch(:waiting_close, false).nil?,
              candle_source_type: @params_normalizer.resolve_candle_source(params[:candle_source_type],
                                                                           type_module: TYPE_MODULE)
            }
          end

          def normalize_trades_params(params)
            values = params[:instrument_ids] || params[:instrument_id]
            {
              instrument_ids: @params_normalizer.normalize_instrument_ids(values),
              trade_source: @params_normalizer.resolve_trade_source(params[:trade_source], type_module: TYPE_MODULE),
              with_open_interest: !params.fetch(:with_open_interest, false).nil?
            }
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
