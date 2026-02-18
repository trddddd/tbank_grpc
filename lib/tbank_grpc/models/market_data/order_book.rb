# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Models
    module MarketData
      # Стакан по инструменту из ответа `GetOrderBook`.
      class OrderBook < BaseModel
        grpc_simple :figi, :instrument_uid, :ticker, :class_code, :depth
        grpc_timestamp :last_price_ts, :close_price_ts
        grpc_quotation :last_price, :close_price, :limit_up, :limit_down

        inspectable_attrs :figi, :depth, :bids_count, :asks_count

        # @return [Array<BigDecimal>] цены ask-уровней
        # @return [Array<BigDecimal>] цены bid-уровней
        # @return [Array<Integer>] количества ask-уровней
        # @return [Array<Integer>] количества bid-уровней
        attr_reader :ask_prices, :bid_quantities, :ask_quantities, :bid_prices

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
          @time ||= timestamp_to_time(time_ts)
        end

        # Bid-уровни стакана.
        #
        # @return [Array<Hash>]
        def bids
          @bids ||= (@pb&.bids || []).map do |bid|
            { price: Core::ValueObjects::Quotation.from_grpc(bid.price), quantity: bid.quantity }
          end
        end

        # Ask-уровни стакана.
        #
        # @return [Array<Hash>]
        def asks
          @asks ||= (@pb&.asks || []).map do |ask|
            { price: Core::ValueObjects::Quotation.from_grpc(ask.price), quantity: ask.quantity }
          end
        end

        # Лучший bid.
        #
        # @return [Hash, nil]
        def best_bid
          bids&.first
        end

        # Лучший ask.
        #
        # @return [Hash, nil]
        def best_ask
          asks&.first
        end

        # Абсолютный спред между лучшими bid/ask.
        #
        # @return [BigDecimal, nil]
        def spread
          return unless best_bid && best_ask

          @spread ||= (ask_prices.first - bid_prices.first).abs
        end

        # Спред в bps.
        #
        # @return [Float, nil]
        def spread_bps
          return unless best_bid && best_ask && bid_prices.first.to_f.positive?

          @spread_bps ||= ((spread / bid_prices.first) * 10_000).round(2)
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
          total_volume = 0
          weighted_sum = BigDecimal('0')
          (@pb&.bids || []).first(levels).each do |order|
            price = TbankGrpc::Converters::Quotation.to_decimal(order.price)
            weighted_sum += price * order.quantity
            total_volume += order.quantity
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
          (total_bids - total_asks).to_f / (total_bids + total_asks)
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

        # Сериализация стакана в Hash.
        #
        # @param precision [Symbol, nil] формат сериализации денежных значений
        # @return [Hash]
        def to_h(precision: nil)
          return {} unless @pb

          serialize_hash({
                           figi: figi,
                           instrument_uid: instrument_uid,
                           ticker: ticker,
                           class_code: class_code,
                           depth: depth,
                           time: time,
                           bids: bids,
                           asks: asks,
                           last_price: last_price,
                           close_price: close_price,
                           limit_up: limit_up,
                           limit_down: limit_down,
                           spread: spread,
                           spread_bps: spread_bps,
                           spread_percent: spread_percent,
                           mid_price: mid_price
                         }, precision: precision)
        end

        private

        def time_ts
          return unless @pb

          (@pb.orderbook_ts if @pb.respond_to?(:orderbook_ts)) || (@pb.time if @pb.respond_to?(:time))
        end
      end
    end
  end
end
