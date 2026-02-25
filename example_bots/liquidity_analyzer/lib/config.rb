# frozen_string_literal: true

require 'optparse'

module LiquidityAnalyzer
  Settings = Data.define(
    :ticker, :figi, :class_code, :money, :depth,
    :minutes, :interval, :watch,
    :render_throttle_sec, :max_duration_sec,
    :grpc_options
  )

  class ConfigLoader
    MAX_DEPTH = 50
    USAGE = [
      'Использование:',
      '  run.rb TICKER [minutes] [money] [interval_sec] [depth]',
      '  run.rb --watch TICKER [money] [depth]',
      '  run.rb --figi=FIGI [minutes] [money] [interval_sec] [depth]',
      '  run.rb TICKER --class-code=SPBFUT  (фьючерсы: SPBFUT, облигации: TQOB)',
      '  minutes: дробное (0 = один снимок), 0.5 = 30 сек'
    ].join("\n")

    DEFAULTS = {
      minutes: 5,
      money: 1_000_000,
      interval: 5,
      depth: 20,
      max_duration_sec: 3600,
      render_throttle_sec: 1.0,
      sandbox: true,
      timeout: 30,
      retry_attempts: 3,
      thread_pool_size: 8,
      stream_metrics_enabled: true,
      log_level: :debug
    }.freeze

    GRPC_KEYS = %i[
      token app_name sandbox log_level timeout retry_attempts
      thread_pool_size stream_metrics_enabled insecure cert_path
    ].freeze

    def self.call(argv)
      new(argv).call
    end

    def self.usage(error = nil)
      [error, USAGE].compact.join("\n")
    end

    def initialize(argv)
      @argv = argv.dup
      @options = DEFAULTS.dup.merge(
        ticker: nil, figi: nil, class_code: nil, watch: false,
        token: nil, insecure: false, cert_path: nil, app_name: 'trddddd.tbank_grpc'
      )
    end

    def call
      parse_argv!
      apply_env!
      validate!
      build_settings
    end

    private

    def parse_argv!
      parser = OptionParser.new do |p|
        p.on('--figi=FIGI') { |v| @options[:figi] = v.to_s.strip }
        p.on('--class-code=CODE') { |v| @options[:class_code] = v.to_s.strip }
        p.on('-w', '--watch') { @options[:watch] = true }
      end
      rest = parser.parse!(@argv)

      @options[:ticker] = rest.shift.to_s.strip unless @options[:figi].to_s != ''

      if @options[:watch]
        @options[:money] = rest.shift&.to_i || @options[:money]
        @options[:depth] = (rest.shift&.to_i || @options[:depth]).clamp(1, MAX_DEPTH)
      else
        @options[:minutes] = rest.shift&.then { |v| v.to_s.strip.empty? ? 0 : v.to_f } || @options[:minutes]
        @options[:money] = rest.shift&.to_i || @options[:money]
        @options[:interval] = rest.shift&.to_i || @options[:interval]
        @options[:depth] = (rest.shift&.to_i || @options[:depth]).to_i.clamp(1, MAX_DEPTH)
      end

      @options[:figi] = nil if @options[:figi].to_s.strip.empty?
      @options[:class_code] = nil if @options[:class_code].to_s.strip.empty?
    end

    def apply_env!
      @options[:token] = ENV['TBANK_TOKEN']
      @options[:insecure] = ENV['TBANK_INSECURE'].to_s.strip == '1'
      @options[:cert_path] = resolve_cert_bundle unless @options[:insecure]
      @options[:sandbox] = ENV['TBANK_SANDBOX'].to_s.strip == '1' if ENV.key?('TBANK_SANDBOX')
      log_env = ENV['TBANK_LOG_LEVEL'].to_s.strip
      @options[:log_level] = log_env.to_sym if log_env != ''
    end

    def resolve_cert_bundle
      [Dir.pwd, Gem.loaded_specs['tbank_grpc']&.full_gem_path,
       File.expand_path('../../..', __dir__)].compact.uniq.each do |root|
        path = File.expand_path('certs/ca_bundle.crt', root)
        return path if File.exist?(path)
      end
      nil
    end

    def validate!
      return if @options[:figi].to_s.strip != '' || @options[:ticker].to_s.strip != ''

      raise ArgumentError, 'Укажите тикер или --figi=FIGI (например SBER или --figi=BBG004730N88).'
    end

    def validate_token!
      return unless @options[:token].to_s.strip.empty?

      raise ArgumentError,
            'TBANK_TOKEN не задан.'
    end

    def build_settings
      validate_token!
      Settings.new(
        ticker: @options[:ticker],
        figi: @options[:figi],
        class_code: @options[:class_code],
        money: @options[:money],
        depth: @options[:depth],
        minutes: @options[:minutes],
        interval: @options[:interval],
        watch: @options[:watch],
        render_throttle_sec: @options[:render_throttle_sec],
        max_duration_sec: @options[:max_duration_sec],
        grpc_options: grpc_config_slice
      )
    end

    def grpc_config_slice
      h = {}
      GRPC_KEYS.each do |k|
        next if k == :cert_path && @options[:insecure]

        h[k] = @options[k]
      end
      h
    end
  end
end
