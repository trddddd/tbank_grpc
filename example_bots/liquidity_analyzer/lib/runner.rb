# frozen_string_literal: true

module LiquidityAnalyzer
  class Runner
    def initialize(client:, settings:)
      @client = client
      @settings = settings
    end

    def call
      puts mode_banner_line

      instrument = resolve_instrument
      figi = instrument.figi
      instrument_id = instrument.instrument_uid || figi
      lot_size = instrument.lot_size || 1
      security_name = [instrument.ticker.to_s.strip, @settings.ticker.to_s.strip, figi.to_s.strip].find do |s|
        !s.empty?
      end || @settings.ticker
      tick_size = instrument.min_price_increment

      if @settings.watch
        run_watch(
          instrument_id: instrument_id,
          security_name: security_name,
          lot_size: lot_size,
          tick_size: tick_size
        )
      else
        session = Session.new(
          client: @client,
          settings: @settings,
          instrument_id: instrument_id,
          security_name: security_name,
          lot_size: lot_size,
          tick_size: tick_size
        )
        values = session.run_once(minutes: @settings.minutes)
        @client.close
        puts ReportFormatter.new([values], money_to_entry: @settings.money).render
      end
    end

    private

    def resolve_instrument
      helpers = @client.helpers.instruments
      return helpers.get_by_figi(@settings.figi.strip) if @settings.figi.to_s.strip != ''

      if @settings.class_code.to_s.strip != ''
        return helpers.get_by_ticker(@settings.ticker,
                                     class_code: @settings.class_code.strip)
      end

      helpers.get_by_ticker_any_class(@settings.ticker.upcase)
    end

    def run_watch(instrument_id:, security_name:, lot_size:, tick_size:)
      stats = Stats::SpreadStats.new(security: security_name)
      render_stop = false
      processor = OrderbookProcessor.new(
        lot_size: lot_size,
        money: @settings.money,
        tick_size: tick_size
      )

      puts "Подключение к стриму стакана #{security_name} (depth=#{@settings.depth})..."
      clear_screen
      puts ReportFormatter.new(
        [Stats::SpreadStats.new(security: security_name)],
        money_to_entry: @settings.money,
        window_size: 100,
        stream_metrics: @client.stream_metrics
      ).render

      render_thread = Thread.new do
        until render_stop
          sleep @settings.render_throttle_sec
          break if render_stop

          clear_screen
          puts ReportFormatter.new(
            [stats],
            money_to_entry: @settings.money,
            window_size: 100,
            stream_metrics: @client.stream_metrics
          ).render
        end
      end

      @client.stream_orderbook(instrument_id: instrument_id, depth: @settings.depth)
      @client.market_data_stream.on(:orderbook, as: :model) do |orderbook|
        processor.process(orderbook, stats)
      end
      @client.market_data_stream.listen
    ensure
      render_stop = true
      render_thread&.join(2)
    end

    def clear_screen
      print "\033[2J\033[H"
    end

    def mode_banner_line
      cfg = TbankGrpc.configuration
      sandbox = cfg&.sandbox
      line = if sandbox.nil?
               "\e[1;35mРежим: неизвестен\e[0m"
             elsif sandbox
               "\e[1;33m\e[7m  SANDBOX — тестовый сервер  \e[0m"
             else
               "\e[1;31m\e[7m  PRODUCTION — боевой счёт  \e[0m"
             end
      line += "\n\e[1;36m  INSECURE — подключение без проверки сертов\e[0m" if cfg&.insecure
      line
    end
  end
end
