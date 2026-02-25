# frozen_string_literal: true

require 'bigdecimal'

module LiquidityAnalyzer
  class Calculator
    Result = Data.define(:bps, :vwap, :filled_money)
    EMPTY_RESULT = Result.new(bps: nil, vwap: nil, filled_money: nil)

    def self.slippage(orderbook:, lot_size:, money:, tick_size: nil)
      new(orderbook: orderbook, lot_size: lot_size, money: money, tick_size: tick_size).call
    end

    def initialize(orderbook:, lot_size:, money:, tick_size: nil)
      @orderbook = orderbook
      @lot = BigDecimal(lot_size.to_s)
      @money = BigDecimal(money.to_s)
      @tick = tick_size.to_s.strip.empty? || tick_size.to_f <= 0 ? nil : BigDecimal(tick_size.to_s)
    end

    def call
      best_ask = @orderbook&.best_ask_price_decimal
      best_bid = @orderbook&.best_bid_price_decimal
      {
        buy: walk(levels_asks, best_ask, :buy),
        sell: walk(levels_bids, best_bid, :sell)
      }
    end

    private

    def levels_bids
      @orderbook&.bids_decimal
    end

    def levels_asks
      @orderbook&.asks_decimal
    end

    def walk(levels, best_price, side)
      return EMPTY_RESULT if levels.nil? || levels.empty? || best_price.nil? || best_price <= 0
      return EMPTY_RESULT if @money <= 0 || @lot <= 0

      total_value, total_shares = fill_from_levels(levels)
      return EMPTY_RESULT if total_value.nil? || total_shares <= 0

      vwap = total_value / total_shares
      bps = side == :buy ? ((vwap - best_price) / best_price) * 10_000 : ((best_price - vwap) / best_price) * 10_000

      Result.new(bps: bps.to_f.round(4), vwap: vwap.to_f, filled_money: total_value.to_f)
    end

    def fill_from_levels(levels)
      remaining = @money
      total_value = BigDecimal('0')
      total_shares = BigDecimal('0')

      levels.each do |lvl|
        price = round_to_tick(lvl[:price])
        qty_lots = lvl[:quantity].to_i
        next if price.nil? || price <= 0 || qty_lots <= 0

        cost_per_lot = price * @lot
        level_value = cost_per_lot * qty_lots

        if level_value <= remaining
          total_value += level_value
          total_shares += qty_lots * @lot
          remaining -= level_value
        else
          ideal_lots = (remaining / cost_per_lot).floor
          take_lots = [ideal_lots, qty_lots].min
          break if take_lots <= 0

          filled_cost = take_lots * cost_per_lot
          total_value += filled_cost
          total_shares += take_lots * @lot
          remaining -= filled_cost
        end

        break if remaining <= 0
      end

      total_shares <= 0 ? [nil, 0] : [total_value, total_shares]
    end

    def round_to_tick(price)
      return price if price.nil?
      return price unless @tick&.positive?

      (price / @tick).round * @tick
    end
  end
end
