# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Обновление позиций из PositionsStream (PositionData).
      class PositionData < BaseModel
        grpc_simple :account_id
        grpc_timestamp :date
        serializable_attr :money, :securities, :futures, :options

        inspectable_attrs :account_id, :date, :money, :securities

        # Денежные изменения по счёту.
        #
        # @return [Array<Hash>]
        def money
          @money ||= Array(@pb&.money).map { |entry| positions_money_to_h(entry) }
        end

        # Обновлённые позиции по ценным бумагам.
        #
        # @return [Array<Hash>]
        def securities
          @securities ||= Array(@pb&.securities).map { |security| position_security_to_h(security) }
        end

        # Обновлённые позиции по фьючерсам.
        #
        # @return [Array<Hash>]
        def futures
          @futures ||= Array(@pb&.futures).map { |future| position_future_to_h(future) }
        end

        # Обновлённые позиции по опционам.
        #
        # @return [Array<Hash>]
        def options
          @options ||= Array(@pb&.options).map { |option| position_option_to_h(option) }
        end

        private

        def positions_money_to_h(entry)
          currency = entry.available_value&.currency || entry.blocked_value&.currency
          {
            available_value: Core::ValueObjects::Money.from_grpc_or_zero(entry.available_value, currency),
            blocked_value: Core::ValueObjects::Money.from_grpc_or_zero(entry.blocked_value, currency)
          }
        end

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
