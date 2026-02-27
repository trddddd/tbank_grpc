# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Responses
        # Преобразование proto-ответов стрима в доменные модели (Candle, OrderBook, Trade и т.д.).
        class ModelMapper
          MODEL_BUILDERS = {
            candle: ->(payload) { Models::MarketData::Candle.from_grpc(payload) },
            orderbook: ->(payload) { Models::MarketData::OrderBook.from_grpc(payload) },
            trade: ->(payload) { Models::MarketData::Trade.from_grpc(payload) },
            trading_status: ->(payload) { Models::MarketData::TradingStatus.from_grpc(payload) },
            last_price: ->(payload) { Models::MarketData::LastPrice.from_grpc(payload) },
            open_interest: ->(payload) { Models::MarketData::OpenInterest.from_grpc(payload) }
          }.freeze

          # @param event_type [Symbol, String] :candle, :orderbook, :trade, :trading_status, :last_price, :open_interest
          # @param payload [Object] proto-сообщение
          # @return [Models::MarketData::Candle, OrderBook, Trade, ... nil] модель или nil
          def map(event_type, payload)
            builder = MODEL_BUILDERS[event_type.to_sym]
            return nil unless builder && payload

            builder.call(payload)
          end

          # Возвращает первую непустую модель из ответа (для server-side stream и т.п.).
          # @param response [MarketDataResponse] proto-ответ
          # @return [Models::MarketData::Candle, OrderBook, Trade, ... nil]
          def first_model_from_response(response)
            map(:candle, response.candle) ||
              map(:orderbook, response.orderbook) ||
              map(:trade, response.trade) ||
              map(:trading_status, response.trading_status) ||
              map(:last_price, response.last_price) ||
              map(:open_interest, response.open_interest)
          end

          # Конвертация proto-ответа в модель с учётом формата (для server-side stream).
          # @param response [MarketDataResponse] proto-ответ
          # @param format [Symbol] :proto или :model
          # @return [Object, nil] модель, proto-ответ или nil
          def convert_response(response, format:)
            return response if format == :proto

            first_model_from_response(response)
          end
        end
      end
    end
  end
end
