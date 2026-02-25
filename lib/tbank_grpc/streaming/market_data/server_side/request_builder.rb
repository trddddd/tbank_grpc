# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module ServerSide
        # Сборка MarketDataServerSideStreamRequest из опций (candles, orderbooks, trades, info,
        # last_prices, ping_delay_ms).
        class RequestBuilder
          # @param params_normalizer [Subscriptions::ParamsNormalizer]
          # @param model_mapper [Responses::ModelMapper]
          # @param type_module [Module]
          def initialize(
            params_normalizer: Subscriptions::ParamsNormalizer,
            model_mapper: Responses::ModelMapper.new,
            type_module: Tinkoff::Public::Invest::Api::Contract::V1
          )
            @params_normalizer = params_normalizer
            @model_mapper = model_mapper
            @type_module = type_module
          end

          # @param options [Hash] candles:, orderbooks:, trades:, info:, last_prices: (массивы параметров),
          #   ping_delay_ms: (опционально)
          # @return [MarketDataServerSideStreamRequest]
          def build(**options)
            normalized = normalize_options(options)
            request = @type_module::MarketDataServerSideStreamRequest.new
            apply_subscription_requests(request, normalized)
            request.ping_settings = build_ping_settings(normalized[:ping_delay_ms]) if normalized[:ping_delay_ms]
            request
          end

          # @param response [MarketDataResponse]
          # @param format [Symbol] :proto или :model
          # @return [Object] proto или первая модель из ответа
          def convert_response(response, format:)
            return response if format == :proto

            @model_mapper.first_model_from_response(response)
          end

          private

          def normalize_options(options)
            {
              candles: Array(options[:candles]),
              orderbooks: Array(options[:orderbooks]),
              trades: Array(options[:trades]),
              info: Array(options[:info]),
              last_prices: Array(options[:last_prices]),
              ping_delay_ms: options[:ping_delay_ms]
            }
          end

          def apply_subscription_requests(request, normalized)
            apply_request(request, :subscribe_candles_request, normalized[:candles], :build_candles_request)
            apply_request(request, :subscribe_order_book_request, normalized[:orderbooks], :build_orderbooks_request)
            apply_request(request, :subscribe_trades_request, normalized[:trades], :build_trades_request)
            apply_request(request, :subscribe_info_request, normalized[:info], :build_info_request)
            apply_request(request, :subscribe_last_price_request, normalized[:last_prices], :build_last_prices_request)
          end

          def apply_request(request, field, items, builder_method)
            return if items.empty?

            request.public_send("#{field}=", send(builder_method, items))
          end

          def build_candles_request(items)
            waiting_close = extract_uniform_option(items, :waiting_close) { |value| value.nil? ? false : value }
            candle_source = extract_uniform_option(items, :candle_source_type) do |value|
              @params_normalizer.resolve_candle_source(value, type_module: @type_module, allow_nil: true)
            end

            instruments = Array(items).map do |item|
              @type_module::CandleInstrument.new(
                instrument_id: normalize_item_instrument_id(item),
                interval: @params_normalizer.resolve_subscription_interval(item[:interval], type_module: @type_module)
              )
            end
            request = @type_module::SubscribeCandlesRequest.new(
              subscription_action: @type_module::SubscriptionAction::SUBSCRIPTION_ACTION_SUBSCRIBE,
              instruments: instruments,
              waiting_close: waiting_close
            )
            if candle_source
              request.candle_source_type = @params_normalizer.resolve_candle_source(
                candle_source,
                type_module: @type_module,
                allow_nil: false
              )
            end
            request
          end

          def build_orderbooks_request(items)
            instruments = Array(items).map do |item|
              @type_module::OrderBookInstrument.new(
                instrument_id: normalize_item_instrument_id(item),
                depth: @params_normalizer.normalize_depth(item.fetch(:depth, 20)),
                order_book_type: @params_normalizer.resolve_order_book_type(
                  item.fetch(:order_book_type, :ORDERBOOK_TYPE_ALL),
                  type_module: @type_module
                )
              )
            end
            @type_module::SubscribeOrderBookRequest.new(
              subscription_action: @type_module::SubscriptionAction::SUBSCRIPTION_ACTION_SUBSCRIBE,
              instruments: instruments
            )
          end

          def build_trades_request(items)
            trade_source = extract_uniform_option(items, :trade_source) do |value|
              @params_normalizer.resolve_trade_source(value.nil? ? :TRADE_SOURCE_ALL : value, type_module: @type_module)
            end
            with_open_interest = extract_uniform_option(items, :with_open_interest) do |value|
              value.nil? ? false : value
            end

            instruments = Array(items).map do |item|
              @type_module::TradeInstrument.new(instrument_id: normalize_item_instrument_id(item))
            end
            @type_module::SubscribeTradesRequest.new(
              subscription_action: @type_module::SubscriptionAction::SUBSCRIPTION_ACTION_SUBSCRIBE,
              instruments: instruments,
              trade_source: trade_source,
              with_open_interest: with_open_interest
            )
          end

          def build_info_request(items)
            instruments = Array(items).map do |item|
              @type_module::InfoInstrument.new(instrument_id: normalize_item_instrument_id(item))
            end
            @type_module::SubscribeInfoRequest.new(
              subscription_action: @type_module::SubscriptionAction::SUBSCRIPTION_ACTION_SUBSCRIBE,
              instruments: instruments
            )
          end

          def build_last_prices_request(items)
            instruments = Array(items).map do |item|
              @type_module::LastPriceInstrument.new(instrument_id: normalize_item_instrument_id(item))
            end
            @type_module::SubscribeLastPriceRequest.new(
              subscription_action: @type_module::SubscriptionAction::SUBSCRIPTION_ACTION_SUBSCRIBE,
              instruments: instruments
            )
          end

          def normalize_item_instrument_id(item)
            return @params_normalizer.normalize_instrument_id(item[:instrument_id]) if item.is_a?(Hash)

            raise InvalidArgumentError, 'Stream request item must be a Hash with :instrument_id'
          end

          def build_ping_settings(milliseconds)
            value = milliseconds.to_i
            raise InvalidArgumentError, 'ping_delay_ms must be within 5000..180000' unless value.between?(5_000,
                                                                                                          180_000)

            @type_module::PingDelaySettings.new(ping_delay_ms: value)
          end

          def extract_uniform_option(items, key)
            values = items.map do |item|
              unless item.is_a?(Hash)
                raise InvalidArgumentError,
                      'Stream request item must be a Hash with :instrument_id'
              end

              raw = item.key?(key) ? item[key] : nil
              yield(raw)
            end
            unique = values.uniq
            return unique.first if unique.length <= 1

            raise InvalidArgumentError, "Mixed values for #{key} are unsupported in one server-side request"
          end
        end
      end
    end
  end
end
