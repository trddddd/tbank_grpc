# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Позиции по счёту из GetPositions (деньги, бумаги, фьючерсы, опционы).
      class Positions < BaseModel
        grpc_simple :account_id, :limits_loading_in_progress
        serializable_attr :money, :blocked, :securities, :futures, :options

        inspectable_attrs :account_id, :money, :securities

        # Денежные балансы по валютам.
        #
        # @return [Array<Models::Core::ValueObjects::Money>]
        def money
          @money ||= Array(@pb&.money).map { |m| Core::ValueObjects::Money.from_grpc(m) }
        end

        # Заблокированные суммы.
        #
        # @return [Array<Models::Core::ValueObjects::Money>]
        def blocked
          @blocked ||= Array(@pb&.blocked).map { |m| Core::ValueObjects::Money.from_grpc(m) }
        end

        # Ценные бумаги (массив хэшей).
        #
        # @return [Array<Hash>]
        def securities
          @securities ||= Array(@pb&.securities).map { |s| position_security_to_h(s) }
        end

        # Фьючерсы (массив хэшей).
        #
        # @return [Array<Hash>]
        def futures
          @futures ||= Array(@pb&.futures).map { |f| position_future_to_h(f) }
        end

        # Опционы (массив хэшей).
        #
        # @return [Array<Hash>]
        def options
          @options ||= Array(@pb&.options).map { |o| position_option_to_h(o) }
        end

        # Хэш валюта => Money по полю money.
        #
        # @return [Hash<String, Models::Core::ValueObjects::Money>]
        def money_by_currency
          money.each_with_object({}) { |m, h| h[m.currency] = m if m.currency.to_s != '' }
        end

        private

        def position_security_to_h(security)
          {
            figi: security.figi,
            blocked: security.blocked,
            balance: security.balance,
            position_uid: security.position_uid,
            instrument_uid: security.instrument_uid,
            ticker: security.ticker,
            class_code: security.class_code,
            exchange_blocked: security.exchange_blocked,
            instrument_type: security.instrument_type
          }.compact
        end

        def position_future_to_h(future)
          {
            figi: future.figi,
            blocked: future.blocked,
            balance: future.balance,
            position_uid: future.position_uid,
            instrument_uid: future.instrument_uid,
            ticker: future.ticker,
            class_code: future.class_code
          }.compact
        end

        def position_option_to_h(option)
          {
            position_uid: option.position_uid,
            instrument_uid: option.instrument_uid,
            ticker: option.ticker,
            class_code: option.class_code,
            blocked: option.blocked,
            balance: option.balance
          }.compact
        end
      end
    end
  end
end
