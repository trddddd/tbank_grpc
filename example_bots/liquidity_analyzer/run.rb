#!/usr/bin/env ruby
# frozen_string_literal: true

Dir[File.join(__dir__, 'lib', '*.rb')].sort.each { |file| require file }
require 'tbank_grpc'

module LiquidityAnalyzer
  class Error < StandardError; end

  class Boot
    def self.call(argv)
      settings = ConfigLoader.call(argv)

      TbankGrpc.configure do |c|
        settings.grpc_options.each { |k, v| c.send("#{k}=", v) }
      end

      client = TbankGrpc::Client.new
      Runner.new(client: client, settings: settings).call
    rescue ArgumentError => e
      abort "\e[31m#{e.message}\e[0m\n#{ConfigLoader.usage}"
    rescue TbankGrpc::Error => e
      abort "\e[31m#{error_message_for(e)}\e[0m"
    rescue Interrupt
      puts "\nВыход."
    end

    ERROR_MESSAGES = {
      TbankGrpc::NotFoundError => ->(e) { "Инструмент не найден: #{e.message}" },
      TbankGrpc::InvalidArgumentError => ->(e) { "Неверный аргумент API: #{e.message}" },
      TbankGrpc::InvalidTokenError => ->(e) { "Ошибка токена (проверьте TBANK_TOKEN): #{e.message}" },
      TbankGrpc::PermissionDeniedError => ->(e) { "Доступ запрещён: #{e.message}" },
      TbankGrpc::UnavailableError => ->(e) { "Сервис недоступен (сеть/сервер): #{e.message}" },
      TbankGrpc::DeadlineExceededError => ->(e) { "Таймаут запроса: #{e.message}" },
      TbankGrpc::Error => ->(e) { "Ошибка API: #{e.message}" }
    }.freeze

    def self.error_message_for(error)
      ERROR_MESSAGES.each do |klass, formatter|
        return formatter.call(error) if error.is_a?(klass)
      end
      "Ошибка: #{error.message}"
    end
    private_class_method :error_message_for
  end
end

LiquidityAnalyzer::Boot.call(ARGV) if $PROGRAM_NAME == __FILE__
