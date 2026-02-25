# frozen_string_literal: true

module TbankGrpc
  module Grpc
    # Вычисление дедлайна для unary/stream RPC по имени сервиса и конфигу.
    # @api private
    module DeadlineResolver
      DEFAULT_DEADLINES = {
        'MarketDataService' => 60,
        'OrdersService' => 30,
        'StopOrdersService' => 30,
        'InstrumentsService' => 180,
        'UsersService' => 180,
        'OperationsService' => 180,
        'OrdersStreamService' => 300,
        'OperationsStreamService' => 300,
        'SandboxService' => 180,
        'SignalService' => 60,
        'MarketDataStreamService' => 90
      }.freeze

      # @param method_full_name [String] например "InstrumentsService/GetInstrumentBy"
      # @param config [Hash] конфигурация (deadline_overrides, timeout)
      # @return [Time, nil] время дедлайна или nil
      def self.deadline_for(method_full_name, config)
        return if method_full_name.nil?

        service_name = method_full_name.to_s.split('/').first
        overrides = config[:deadline_overrides] || {}

        seconds =
          pick_override(overrides, method_full_name) ||
          pick_override(overrides, service_name) ||
          DEFAULT_DEADLINES[service_name] ||
          config[:timeout]

        return if seconds.nil?

        Time.now + seconds.to_f
      end

      def self.pick_override(overrides, key)
        return unless overrides

        overrides[key] || overrides[key.to_s] || overrides[key.to_sym]
      end
    end
  end
end
