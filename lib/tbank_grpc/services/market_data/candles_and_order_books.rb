# frozen_string_literal: true

module TbankGrpc
  module Services
    module MarketData
      # Свечи и стакан. GetCandles, GetOrderBook.
      module CandlesAndOrderBooks
        # Исторические свечи по инструменту. GetCandles.
        #
        # @param from [Time, String] начало периода (UTC)
        # @param to [Time, String] конец периода (UTC)
        # @param interval [Symbol] интервал свечей (CandleInterval). Допустимые значения:
        #   * 5/10/30 сек: :CANDLE_INTERVAL_5_SEC, :CANDLE_INTERVAL_10_SEC, :CANDLE_INTERVAL_30_SEC (limit до 1250–2500)
        #   * минуты: :CANDLE_INTERVAL_1_MIN, :CANDLE_INTERVAL_2_MIN, :CANDLE_INTERVAL_3_MIN, :CANDLE_INTERVAL_5_MIN,
        #     :CANDLE_INTERVAL_10_MIN, :CANDLE_INTERVAL_15_MIN, :CANDLE_INTERVAL_30_MIN (limit до 750–2400)
        #   * часы: :CANDLE_INTERVAL_HOUR или :CANDLE_INTERVAL_1_HOUR, :CANDLE_INTERVAL_2_HOUR, :CANDLE_INTERVAL_4_HOUR
        #     (limit до 700–2400)
        #   * день и выше: :CANDLE_INTERVAL_DAY, :CANDLE_INTERVAL_WEEK, :CANDLE_INTERVAL_MONTH (limit до 120–2400)
        # @param instrument_id [String] FIGI, UID или ticker
        # @param options [Hash] опционально: limit (Integer), candle_source_type (Symbol), return_metadata (Boolean)
        # @return [Models::MarketData::CandleCollection, Response]
        # @raise [TbankGrpc::Error]
        def get_candles(from:, to:, interval:, instrument_id:, **options)
          limit = options[:limit]
          candle_source_type = options[:candle_source_type]
          return_metadata = options.fetch(:return_metadata, false)

          id = resolve_instrument_id(instrument_id: instrument_id)
          interval_proto = convert_interval(interval)
          request_params = {
            instrument_id: id,
            from: timestamp_to_proto(from),
            to: timestamp_to_proto(to),
            interval: interval_proto
          }
          request_params[:limit] = limit if limit
          request_params[:candle_source_type] = candle_source_type if candle_source_type
          request = build_get_candles_request(request_params, interval: interval)

          log_params = { instrument_id: id, from: from, to: to, interval: interval }
          log_params[:limit] = limit.nil? ? '—' : limit
          log_params[:candle_source_type] = candle_source_type.nil? ? '—' : candle_source_type
          @logger.debug('GetCandles request', **log_params)

          execute_rpc(method_name: :get_candles, request: request, return_metadata: return_metadata) do |response|
            Models::MarketData::CandleCollection.from_grpc(response.candles, instrument_id: id)
          end
        end

        # Стакан по инструменту. GetOrderBook. Глубина 1–50.
        #
        # @param instrument_id [String]
        # @param depth [Integer] глубина стакана (1–50), по умолчанию 20
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::MarketData::OrderBook, Response]
        # @raise [TbankGrpc::Error]
        def get_order_book(instrument_id:, depth: 20, return_metadata: false)
          id = resolve_instrument_id(instrument_id: instrument_id)
          validate_depth(depth)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetOrderBookRequest.new(
            instrument_id: id,
            depth: depth
          )
          @logger.debug('GetOrderBook request', instrument_id: id, depth: depth)
          execute_rpc(method_name: :get_order_book, request: request, model: Models::MarketData::OrderBook,
                      return_metadata: return_metadata)
        end

        private

        def build_get_candles_request(request_params, interval:)
          Tinkoff::Public::Invest::Api::Contract::V1::GetCandlesRequest.new(request_params)
        rescue RangeError, ArgumentError => e
          msg = "Invalid interval: #{interval.inspect}. #{e.message}. "
          msg += 'Use CANDLE_INTERVAL_1_MIN, CANDLE_INTERVAL_DAY, etc.'
          raise InvalidArgumentError, msg
        end

        def convert_interval(interval)
          # В API часовой интервал — CANDLE_INTERVAL_HOUR, а не 1_HOUR
          interval == :CANDLE_INTERVAL_1_HOUR ? :CANDLE_INTERVAL_HOUR : interval
        end

        def validate_depth(depth)
          return if (1..50).include?(depth)

          raise InvalidArgumentError, "Depth must be between 1 and 50, got #{depth}"
        end
      end
    end
  end
end
