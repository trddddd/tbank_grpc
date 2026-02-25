# frozen_string_literal: true

module LiquidityAnalyzer
  class Session
    def initialize(client:, settings:, instrument_id:, security_name:, lot_size:, tick_size:)
      @client = client
      @settings = settings
      @instrument_id = instrument_id
      @security_name = security_name
      @processor = OrderbookProcessor.new(
        lot_size: lot_size,
        money: settings.money,
        tick_size: tick_size
      )
    end

    def run_once(minutes:)
      duration_sec = (minutes.to_f * 60)
      if duration_sec > @settings.max_duration_sec
        warn "Внимание: duration #{duration_sec / 60} мин ограничен 60 мин."
        duration_sec = @settings.max_duration_sec
      end

      values = Stats::SpreadStats.new(security: @security_name)
      if duration_sec <= 0
        orderbook = @client.market_data.get_order_book(instrument_id: @instrument_id, depth: @settings.depth)
        append_orderbook(values, orderbook)
      else
        collect_samples(values, duration_sec)
      end
      values
    end

    private

    def collect_samples(values, duration_sec)
      deadline = Time.now + duration_sec
      loop do
        orderbook = @client.market_data.get_order_book(instrument_id: @instrument_id, depth: @settings.depth)
        append_orderbook(values, orderbook)
        break if Time.now >= deadline

        sleep([@settings.interval, deadline - Time.now].min)
      end
    end

    def append_orderbook(values, orderbook)
      @processor.process(orderbook, values)
    end
  end
end
