# frozen_string_literal: true

module LiquidityAnalyzer
  class ReportFormatter
    def initialize(stats, money_to_entry:, window_size: nil, stream_metrics: nil)
      @stats = stats
      @money_to_entry = money_to_entry
      @window_size = window_size
      @stream_metrics = stream_metrics
    end

    def render
      report = +''
      report << mode_banner << "\n\n"
      report << render_watch_header
      report << intro_block
      return report << "Данные не собраны. Ошибка.\n" if @stats.empty?

      sorted = @stats.sort_by { |v| v.slippage_both_value || Float::INFINITY }
      sorted.each_with_index { |stat, i| report << render_stat_row(stat, i) }
      report
    end

    private

    def render_watch_header
      out = "Обновлено: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}   Ctrl+C — выход\n"
      stat = @stats.first
      if stat.respond_to?(:buffer_info)
        info = stat.buffer_info
        out << "Буфер: #{info[:current]}/#{info[:max_samples]} сэмплов"
        out << "  обрезок: #{info[:trim_count]}" if info[:trim_count].positive?
        out << '  (лимит)' if info[:at_cap]
        out << "\n"
      end
      if @stream_metrics.is_a?(Hash) && @stream_metrics[:metrics].is_a?(Hash)
        m = @stream_metrics[:metrics]
        out << "Стрим: orderbook событий: #{m.dig(:events_processed, :orderbook) || 0} " \
               "(получено #{m.dig(:events_emitted, :orderbook) || 0})"
        out << ", ошибок: #{m[:error_count]}" if (m[:error_count] || 0).positive?
        out << ", реконнектов: #{@stream_metrics[:reconnects]}" if (@stream_metrics[:reconnects] || 0).positive?
        out << "\n"
      end
      "#{out}\n"
    end

    def intro_block
      <<~TEXT
        =================================================
        ОТЧЕТ ПО ЛИКВИДНОСТИ / LIQUIDITY REPORT
        =================================================

        СПРАВКА ПО BPS (BASIS POINTS):
        • 1 BPS = 0.01% от суммы сделки
        • Пример: на сделке #{format_money(1_000_000)}₽, 10 BPS = #{format_money(1_000)}₽ потерь

        КРИТЕРИИ ЛИКВИДНОСТИ:
        • Отлично:  < 5 BPS  (< 0.05%) - низкие издержки для алготрейдинга
        • Хорошо:   5-20 BPS (0.05-0.20%) - активная торговля
        • Средне:   20-50 BPS (0.20-0.50%) - средняя ликвидность
        • Плохо:    50-100 BPS (0.50-1.00%) - низкая ликвидность
        • Крайне плохо: > 100 BPS (> 1.00%) - избегать

        =================================================

      TEXT
    end

    def render_stat_row(stat, index)
      raw_long = stat.slippage_to_long_middle_value
      raw_short = stat.slippage_to_short_middle_value
      raw_both = stat.slippage_both_value
      slippage_long = raw_long&.positive? ? raw_long : 0
      slippage_short = raw_short&.positive? ? raw_short : 0
      slippage_both = raw_both&.positive? ? raw_both : 0
      spread_pct = stat.spread_percent_middle_value || 0

      out = "\n#{index + 1}. #{stat.security}\n----------------------------------------\n"
      out << "  Общая оценка: #{liquidity_quality(raw_both)}\n  Спред: #{spread_pct.round(4)}%\n\n"
      out << slippage_line('LONG', raw_long, slippage_long, cost_in_rubles(slippage_long, @money_to_entry))
      out << slippage_line('SHORT', raw_short, slippage_short, cost_in_rubles(slippage_short, @money_to_entry))
      out << slippage_line('СРЕДНИЙ импакт', raw_both, slippage_both, cost_in_rubles(slippage_both, @money_to_entry),
                           term: false)
      out << "\n"
      out << render_window_block(stat) if @window_size && stat.respond_to?(:window)
      out
    end

    def mode_banner
      cfg = TbankGrpc.configuration
      sandbox = cfg&.sandbox
      text = if sandbox.nil?
               ' [ РЕЖИМ НЕИЗВЕСТЕН ] '
             elsif sandbox
               ' [ SANDBOX — ТЕСТОВЫЙ СЕРВЕР ] '
             else
               ' [ PRODUCTION — БОЕВОЙ СЧЁТ ] '
             end
      text += ' [ INSECURE ] ' if cfg&.insecure
      code = if sandbox.nil?
               "\e[1;35m"
             else
               (sandbox ? "\e[1;33m\e[7m" : "\e[1;31m\e[7m")
             end
      "#{code}#{text}\e[0m"
    end

    def slippage_line(label, raw_bps, bps, cost_rubles, term: true)
      if raw_bps.nil?
        line = "  #{label}: не рассчитано (в стакане недостаточно объёма для суммы входа)"
      elsif bps <= 0 || bps < 0.01
        line = "  #{label}: практически отсутствует (< 0.01 BPS)"
      else
        loss_pct = (bps / 100).round(4)
        line = "  #{label}: #{bps.round(2)} BPS\n     Потери на #{format_money(@money_to_entry.to_i)}₽: " \
               "~#{format_money(cost_rubles.to_i)}₽ (#{loss_pct}%)"
      end
      term ? "#{line}\n\n" : "#{line}\n"
    end

    def liquidity_quality(bps)
      return 'Не рассчитано (мало объёма в стакане)' if bps.nil?
      return 'Очень низкое (практически без проскальзывания)' if bps <= 0 || bps < 0.01
      return 'ОТЛИЧНО (< 5 BPS)' if bps < 5
      return 'ХОРОШО (активная торговля)' if bps < 20
      return 'СРЕДНЕ (умеренная торговля)' if bps < 50
      return 'ПЛОХО (низкая ликвидность)' if bps < 100

      'КРАЙНЕ ПЛОХО (избегать)'
    end

    def cost_in_rubles(bps, money_amount)
      return 0 if bps.nil? || bps <= 0

      money_amount.to_f * (bps / 10_000.0)
    end

    def format_money(amount)
      amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
    end

    def render_window_block(stat)
      win = stat.window(@window_size)
      return '' if win.empty?

      fmt = ->(v) { v.nil? ? 'n/a' : v.round(2) }
      m = win.median
      p90 = win.percentile(90)
      vol = win.volatility
      "  --- MICROSTRUCTURE (окно #{@window_size}) ---\n  " \
        "Медиана:  long #{fmt.call(m[:long])} BPS  short #{fmt.call(m[:short])} both #{fmt.call(m[:both])} BPS\n  " \
        "90% перцентиль:  long #{fmt.call(p90[:long])} short #{fmt.call(p90[:short])} " \
        "both #{fmt.call(p90[:both])} BPS\n  " \
        "Волатильность (σ):  long #{fmt.call(vol[:long])} short #{fmt.call(vol[:short])} " \
        "both #{fmt.call(vol[:both])} BPS\n\n"
    end
  end
end
