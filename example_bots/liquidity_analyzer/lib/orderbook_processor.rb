# frozen_string_literal: true

module LiquidityAnalyzer
  class OrderbookProcessor
    def initialize(lot_size:, money:, tick_size: nil)
      @lot_size = lot_size
      @money = money
      @tick_size = tick_size
    end

    def process(orderbook, stats)
      result = Calculator.slippage(
        orderbook: orderbook,
        lot_size: @lot_size,
        money: @money,
        tick_size: @tick_size
      )
      spread_pct = orderbook&.spread_percent
      long_bps = result[:buy]&.bps
      short_bps = result[:sell]&.bps

      stats.add_sample(
        spread_percent: spread_pct,
        slippage_long: long_bps,
        slippage_short: short_bps
      )

      stats
    end
  end
end
