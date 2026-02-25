# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Responses
        # Разбор ответа MarketDataStream: маршрутизация candle/orderbook/trade/... в event_loop.
        class EventRouter
          # @return [Streaming::Core::Dispatch::EventLoop]
          attr_reader :event_loop
          # @return [ModelMapper]
          attr_reader :model_mapper

          # @param event_loop [Streaming::Core::Dispatch::EventLoop]
          # @param model_mapper [ModelMapper]
          def initialize(event_loop:, model_mapper: ModelMapper.new)
            @event_loop = event_loop
            @model_mapper = model_mapper
          end

          # Обрабатывает один ответ стрима: диспатчит рыночные payload и subscription_status.
          # @param response [MarketDataResponse] proto-ответ
          # @return [void]
          def dispatch(response)
            dispatch_market_payloads(response)
            dispatch_subscription_statuses(response)
          end

          private

          def dispatch_market_payloads(response)
            dispatch_typed_market_event(:candle, response.candle)
            dispatch_typed_market_event(:orderbook, response.orderbook)
            dispatch_typed_market_event(:trade, response.trade)
            dispatch_typed_market_event(:trading_status, response.trading_status)
            dispatch_typed_market_event(:last_price, response.last_price)
            dispatch_typed_market_event(:open_interest, response.open_interest)
            emit_event(:ping, proto_payload: response.ping)
          end

          def dispatch_typed_market_event(event_type, payload)
            return unless payload

            model_payload = nil
            model_payload = @model_mapper.map(event_type, payload) if @event_loop.needs_model_payload?(event_type)
            @event_loop.emit(event_type, proto_payload: payload, model_payload: model_payload)
          end

          def dispatch_subscription_statuses(response)
            emit_event(:subscription_status,
                       proto_payload: (r = response.subscribe_order_book_response) && { type: :orderbook, response: r })
            emit_event(:subscription_status,
                       proto_payload: (r = response.subscribe_candles_response) && { type: :candles, response: r })
            emit_event(:subscription_status,
                       proto_payload: (r = response.subscribe_trades_response) && { type: :trades, response: r })
            emit_event(:subscription_status,
                       proto_payload: (r = response.subscribe_info_response) && { type: :info, response: r })
            emit_event(:subscription_status,
                       proto_payload: (r = response.subscribe_last_price_response) && { type: :last_price,
                                                                                        response: r })
          end

          def emit_event(event_type, proto_payload:, model_payload: nil)
            return unless proto_payload

            @event_loop.emit(event_type, proto_payload: proto_payload, model_payload: model_payload)
          end
        end
      end
    end
  end
end
