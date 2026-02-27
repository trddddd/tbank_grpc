# frozen_string_literal: true

require 'time'

module TbankGrpc
  module Streaming
    module MarketData
      module Subscriptions
        # Сборка proto-запросов для market data stream: подписки, ping, get_my_subscriptions.
        class RequestFactory
          # @param type_module [Module] контракт API (по умолчанию TbankGrpc::CONTRACT_V1)
          def initialize(type_module: TbankGrpc::CONTRACT_V1)
            @type_module = type_module
          end

          # @param type [Symbol, String] :orderbook, :candles, :trades, :info, :last_price
          # @param params [Hash] параметры подписки (instrument_id, depth, interval, instrument_ids и т.д.)
          # @param action [Symbol, String] :subscribe или :unsubscribe
          # @return [MarketDataRequest] proto-сообщение
          # @raise [InvalidArgumentError] при неизвестном type или action
          def subscription_request(type, params, action)
            proto_action = resolve_subscription_action(action)

            case type.to_sym
            when :orderbook
              build_orderbook_request(params, proto_action)
            when :candles
              build_candles_request(params, proto_action)
            when :trades
              build_trades_request(params, proto_action)
            when :info
              build_info_request(params, proto_action)
            when :last_price
              build_last_price_request(params, proto_action)
            else
              raise InvalidArgumentError, "Unknown subscription type: #{type.inspect}"
            end
          end

          # @return [MarketDataRequest] запрос get_my_subscriptions
          def my_subscriptions_request
            @type_module::MarketDataRequest.new(get_my_subscriptions: @type_module::GetMySubscriptions.new)
          end

          # @param time [Time, String, nil] время для ping (опционально)
          # @return [MarketDataRequest]
          def ping_request(time: nil)
            request = @type_module::PingRequest.new
            request.time = timestamp_to_proto(time) if time
            @type_module::MarketDataRequest.new(ping: request)
          end

          # @param milliseconds [Integer] задержка пинга в мс (5000..180000)
          # @return [MarketDataRequest]
          def ping_settings_request(milliseconds)
            @type_module::MarketDataRequest.new(
              ping_settings: @type_module::PingDelaySettings.new(ping_delay_ms: milliseconds)
            )
          end

          # @param milliseconds [Integer, #to_i]
          # @return [Integer] значение в допустимом диапазоне
          # @raise [InvalidArgumentError] если не в 5000..180000
          def normalize_ping_delay(milliseconds)
            value = milliseconds.to_i
            return value if value.between?(5_000, 180_000)

            raise InvalidArgumentError, 'ping_delay_ms must be within 5000..180000'
          end

          private

          def build_orderbook_request(params, proto_action)
            instrument = @type_module::OrderBookInstrument.new(
              instrument_id: params[:instrument_id],
              depth: params[:depth],
              order_book_type: params[:order_book_type]
            )
            @type_module::MarketDataRequest.new(
              subscribe_order_book_request: @type_module::SubscribeOrderBookRequest.new(
                subscription_action: proto_action,
                instruments: [instrument]
              )
            )
          end

          def build_candles_request(params, proto_action)
            instrument = @type_module::CandleInstrument.new(
              instrument_id: params[:instrument_id],
              interval: params[:interval]
            )
            request = @type_module::SubscribeCandlesRequest.new(
              subscription_action: proto_action,
              instruments: [instrument],
              waiting_close: params[:waiting_close]
            )
            request.candle_source_type = params[:candle_source_type] if params[:candle_source_type]
            @type_module::MarketDataRequest.new(subscribe_candles_request: request)
          end

          def build_trades_request(params, proto_action)
            instruments = params[:instrument_ids].map do |instrument_id|
              @type_module::TradeInstrument.new(instrument_id: instrument_id)
            end
            @type_module::MarketDataRequest.new(
              subscribe_trades_request: @type_module::SubscribeTradesRequest.new(
                subscription_action: proto_action,
                instruments: instruments,
                trade_source: params[:trade_source],
                with_open_interest: params[:with_open_interest]
              )
            )
          end

          def build_info_request(params, proto_action)
            instruments = params[:instrument_ids].map do |instrument_id|
              @type_module::InfoInstrument.new(instrument_id: instrument_id)
            end
            @type_module::MarketDataRequest.new(
              subscribe_info_request: @type_module::SubscribeInfoRequest.new(
                subscription_action: proto_action,
                instruments: instruments
              )
            )
          end

          def build_last_price_request(params, proto_action)
            instruments = params[:instrument_ids].map do |instrument_id|
              @type_module::LastPriceInstrument.new(instrument_id: instrument_id)
            end
            @type_module::MarketDataRequest.new(
              subscribe_last_price_request: @type_module::SubscribeLastPriceRequest.new(
                subscription_action: proto_action,
                instruments: instruments
              )
            )
          end

          def resolve_subscription_action(action)
            @type_module::SubscriptionAction.const_get(action.to_s)
          rescue NameError
            raise InvalidArgumentError, "Unsupported subscription action: #{action.inspect}"
          end

          def timestamp_to_proto(time)
            object = time.is_a?(Time) ? time : Time.parse(time.to_s)
            Google::Protobuf::Timestamp.new(seconds: object.to_i, nanos: object.nsec)
          rescue StandardError
            raise InvalidArgumentError, "Invalid time value: #{time.inspect}"
          end
        end
      end
    end
  end
end
