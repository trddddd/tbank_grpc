# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Models
    module MarketData
      # Стакан по инструменту из ответа `GetOrderBook`.
      #
      # Представления цен:
      # - Для доменной точности и работы с units/nano используйте {#bids}/{#asks}
      #   (там `price` как {Core::ValueObjects::Quotation}).
      # - Для расчётов используйте {#bid_prices}/{#ask_prices}, {#spread}, {#mid_price}
      #   (все в `BigDecimal`).
      # - Для вывода в консоль/UI используйте строковые helper-методы
      #   {#best_bid_price_s}, {#best_ask_price_s}, {#spread_s}.
      class OrderBook < BaseModel
        grpc_simple :figi, :instrument_uid, :ticker, :class_code, :depth
        grpc_quotation :last_price, :close_price, :limit_up, :limit_down
        serializable_attr :time, :bids, :asks,
                          :spread, :spread_bps, :spread_percent, :mid_price

        inspectable_attrs :figi, :depth, :bids_count, :asks_count

        # @return [Array<BigDecimal>] цены ask-уровней
        # @return [Array<BigDecimal>] цены bid-уровней
        # @return [Array<Integer>] количества ask-уровней
        # @return [Array<Integer>] количества bid-уровней
        attr_reader :ask_prices, :bid_prices, :ask_quantities, :bid_quantities

        # @param proto [Google::Protobuf::MessageExts, nil]
        def initialize(proto = nil)
          super
          bids = @pb&.bids || []
          asks = @pb&.asks || []
          @bid_prices = bids.map { |o| TbankGrpc::Converters::Quotation.to_decimal(o.price) }.freeze
          @ask_prices = asks.map { |o| TbankGrpc::Converters::Quotation.to_decimal(o.price) }.freeze
          @bid_quantities = bids.map(&:quantity).freeze
          @ask_quantities = asks.map(&:quantity).freeze
        end

        # Количество bid-уровней в стакане.
        #
        # @return [Integer]
        def bids_count
          @pb&.bids&.size || 0
        end

        # Количество ask-уровней в стакане.
        #
        # @return [Integer]
        def asks_count
          @pb&.asks&.size || 0
        end

        # Время стакана.
        #
        # @return [Time, nil]
        def time
          return @time if defined?(@time)

          @time = timestamp_to_time(time_ts)
        end

        # Bid-уровни стакана.
        #
        # @return [Array<Hash>]
        def bids
          @bids ||= (@pb&.bids || []).map do |bid|
            { price: Core::ValueObjects::Quotation.from_grpc(bid.price), quantity: bid.quantity }.freeze
          end.freeze
        end

        # Ask-уровни стакана.
        #
        # @return [Array<Hash>]
        def asks
          @asks ||= (@pb&.asks || []).map do |ask|
            { price: Core::ValueObjects::Quotation.from_grpc(ask.price), quantity: ask.quantity }.freeze
          end.freeze
        end

        # Лучший bid.
        #
        # @return [Hash, nil]
        def best_bid
          bids.first
        end

        # Цена лучшего bid в `BigDecimal` (для расчётов).
        #
        # @return [BigDecimal, nil]
        def best_bid_price_decimal
          bid_prices.first
        end

        # Цена лучшего bid в `Float` (для display-only сценариев).
        #
        # @return [Float, nil]
        def best_bid_price_f
          best_bid_price_decimal&.to_f
        end

        # Цена лучшего bid в человеко-читаемой строке без экспоненциальной нотации.
        #
        # @return [String, nil]
        def best_bid_price_s
          format_decimal(best_bid_price_decimal)
        end

        # Лучший ask.
        #
        # @return [Hash, nil]
        def best_ask
          asks.first
        end

        # Цена лучшего ask в `BigDecimal` (для расчётов).
        #
        # @return [BigDecimal, nil]
        def best_ask_price_decimal
          ask_prices.first
        end

        # Цена лучшего ask в `Float` (для display-only сценариев).
        #
        # @return [Float, nil]
        def best_ask_price_f
          best_ask_price_decimal&.to_f
        end

        # Цена лучшего ask в человеко-читаемой строке без экспоненциальной нотации.
        #
        # @return [String, nil]
        def best_ask_price_s
          format_decimal(best_ask_price_decimal)
        end

        # Абсолютный спред между лучшими bid/ask.
        #
        # @return [BigDecimal, nil]
        def spread
          return unless best_bid && best_ask

          @spread ||= (ask_prices.first - bid_prices.first).abs
        end

        # Спред в строковом формате для человеко-читаемого вывода.
        #
        # @return [String, nil]
        def spread_s
          format_decimal(spread)
        end

        # Спред в bps относительно mid-price.
        #
        # @return [Float, nil]
        def spread_bps
          return unless best_bid && best_ask

          mid = mid_price
          return unless mid&.to_f&.positive?

          @spread_bps ||= ((spread / mid) * 10_000).to_f.round(2)
        end

        # Спред в процентах.
        #
        # @return [Float, nil]
        def spread_percent
          return unless spread_bps

          @spread_percent ||= (spread_bps / 100.0).round(4)
        end

        # Средняя цена между лучшими bid/ask.
        #
        # @return [BigDecimal, nil]
        def mid_price
          return unless best_bid && best_ask

          @mid_price ||= (bid_prices.first + ask_prices.first) / 2
        end

        # Взвешенная средняя цена bid по первым N уровням.
        #
        # @param levels [Integer]
        # @return [BigDecimal]
        def weighted_bid_price(levels = 5)
          prices = bid_prices.first(levels)
          quantities = bid_quantities.first(levels)
          total_volume = quantities.sum
          weighted_sum = prices.zip(quantities).sum(BigDecimal('0')) do |price, quantity|
            price * quantity
          end
          total_volume.zero? ? BigDecimal('0') : weighted_sum / total_volume
        end

        # Дисбаланс объёма bid/ask: `(bids - asks) / (bids + asks)`.
        #
        # @return [Float, nil]
        def imbalance
          return if bid_quantities.empty? || ask_quantities.empty?

          total_bids = bid_quantities.sum
          total_asks = ask_quantities.sum
          total = total_bids + total_asks
          return if total.zero?

          (total_bids - total_asks).to_f / total
        end

        # Минимальная ликвидность в обе стороны по первым N уровням.
        #
        # @param levels [Integer]
        # @return [Integer]
        def liquidity_score(levels = 5)
          bid_vol = bid_quantities.first(levels).sum
          ask_vol = ask_quantities.first(levels).sum
          [bid_vol, ask_vol].min
        end

        # Bid-уровни стакана в decimal-представлении
        # (`price` как `BigDecimal`) для расчётов и сериализации.
        #
        # @return [Array<Hash>]
        def bids_decimal
          @bids_decimal ||= bid_prices.zip(bid_quantities).map do |price, quantity|
            { price: price, quantity: quantity }
          end
        end

        # Ask-уровни стакана в decimal-представлении
        # (`price` как `BigDecimal`) для расчётов и сериализации.
        #
        # @return [Array<Hash>]
        def asks_decimal
          @asks_decimal ||= ask_prices.zip(ask_quantities).map do |price, quantity|
            { price: price, quantity: quantity }
          end
        end

        private

        # Время стакана: GetOrderBookResponse — orderbook_ts (23), в стриме OrderBook — time (6).
        # Поддерживаем оба поля для совместимости unary и stream payload.
        def time_ts
          return unless @pb

          (@pb.orderbook_ts if @pb.respond_to?(:orderbook_ts)) || (@pb.time if @pb.respond_to?(:time))
        end

        # Внутренние timestamp-поля proto (не в реестре, не попадают в to_h).
        def last_price_ts
          return unless @pb.respond_to?(:last_price_ts) && @pb.last_price_ts

          timestamp_to_time(@pb.last_price_ts)
        end

        def close_price_ts
          return unless @pb.respond_to?(:close_price_ts) && @pb.close_price_ts

          timestamp_to_time(@pb.close_price_ts)
        end

        def format_decimal(value)
          value&.to_s('F')
        end
      end
    end
  end
end
