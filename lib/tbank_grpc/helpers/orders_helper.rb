# frozen_string_literal: true

require 'securerandom'

module TbankGrpc
  module Helpers
    # Фасад для типовых сценариев с ордерами: рыночные и лимитные покупка/продажа, разбиение объёма на части
    # (order slicing по рынку: несколько ORDER_TYPE_MARKET заявок для снижения разового рыночного воздействия).
    # rubocop:disable Metrics/ParameterLists, Metrics/ClassLength
    class OrdersHelper
      # @param client [TbankGrpc::Client]
      def initialize(client)
        @client = client
      end

      # Рыночная покупка.
      #
      # @param instrument_id [String] FIGI или instrument_uid
      # @param quantity [Integer] объём в лотах
      # @param account_id [String]
      # @param order_id [String, nil] idempotency key (до 36 символов); при nil генерируется UUID
      # @param return_metadata [Boolean]
      # @return [PostOrderResponse, Response]
      def buy_market(instrument_id:, quantity:, account_id:, order_id: nil, return_metadata: false)
        @client.orders.post_order(
          instrument_id: instrument_id,
          quantity: quantity,
          direction: :ORDER_DIRECTION_BUY,
          account_id: account_id,
          order_type: :ORDER_TYPE_MARKET,
          order_id: order_id.to_s.strip.empty? ? SecureRandom.uuid : order_id,
          return_metadata: return_metadata
        )
      end

      # Рыночная продажа.
      #
      # @param instrument_id [String]
      # @param quantity [Integer] объём в лотах
      # @param account_id [String]
      # @param order_id [String, nil] при nil генерируется UUID
      # @param return_metadata [Boolean]
      # @return [PostOrderResponse, Response]
      def sell_market(instrument_id:, quantity:, account_id:, order_id: nil, return_metadata: false)
        @client.orders.post_order(
          instrument_id: instrument_id,
          quantity: quantity,
          direction: :ORDER_DIRECTION_SELL,
          account_id: account_id,
          order_type: :ORDER_TYPE_MARKET,
          order_id: order_id.to_s.strip.empty? ? SecureRandom.uuid : order_id,
          return_metadata: return_metadata
        )
      end

      # Лимитная покупка.
      #
      # @param instrument_id [String] FIGI или instrument_uid
      # @param quantity [Integer] объём в лотах
      # @param price [Numeric, String, Tinkoff::Public::Invest::Api::Contract::V1::Quotation,
      #   TbankGrpc::Models::Core::ValueObjects::Quotation] лимитная цена; любой тип приводится к proto
      #   Quotation для запроса (см. {TbankGrpc::Converters::Quotation.to_pb})
      # @param account_id [String]
      # @param order_id [String, nil] idempotency key; при nil — UUID
      # @param time_in_force [Symbol, Integer, nil] TIME_IN_FORCE_* (по умолчанию — день)
      # @param price_type [Symbol, Integer, nil] PRICE_TYPE_*
      # @param return_metadata [Boolean]
      # @return [PostOrderResponse, Response]
      def buy_limit(
        instrument_id:,
        quantity:,
        price:,
        account_id:,
        order_id: nil,
        time_in_force: nil,
        price_type: nil,
        return_metadata: false
      )
        @client.orders.post_order(
          instrument_id: instrument_id,
          quantity: quantity,
          price: price,
          direction: :ORDER_DIRECTION_BUY,
          account_id: account_id,
          order_type: :ORDER_TYPE_LIMIT,
          order_id: order_id.to_s.strip.empty? ? SecureRandom.uuid : order_id,
          time_in_force: time_in_force,
          price_type: price_type,
          return_metadata: return_metadata
        )
      end

      # Лимитная продажа.
      #
      # @param instrument_id [String]
      # @param quantity [Integer] объём в лотах
      # @param price [Numeric, String, Tinkoff::Public::Invest::Api::Contract::V1::Quotation,
      #   TbankGrpc::Models::Core::ValueObjects::Quotation] лимитная цена; любой тип приводится к proto
      #   Quotation для запроса (см. {TbankGrpc::Converters::Quotation.to_pb})
      # @param account_id [String]
      # @param order_id [String, nil] при nil — UUID
      # @param time_in_force [Symbol, Integer, nil]
      # @param price_type [Symbol, Integer, nil]
      # @param return_metadata [Boolean]
      # @return [PostOrderResponse, Response]
      def sell_limit(
        instrument_id:,
        quantity:,
        price:,
        account_id:,
        order_id: nil,
        time_in_force: nil,
        price_type: nil,
        return_metadata: false
      )
        @client.orders.post_order(
          instrument_id: instrument_id,
          quantity: quantity,
          price: price,
          direction: :ORDER_DIRECTION_SELL,
          account_id: account_id,
          order_type: :ORDER_TYPE_LIMIT,
          order_id: order_id.to_s.strip.empty? ? SecureRandom.uuid : order_id,
          time_in_force: time_in_force,
          price_type: price_type,
          return_metadata: return_metadata
        )
      end

      # Покупка частями по рынку (slicing): разбивает quantity на parts рыночных заявок (ORDER_TYPE_MARKET).
      #
      # @param instrument_id [String]
      # @param quantity [Integer] общий объём в лотах
      # @param account_id [String]
      # @param parts [Integer] на сколько заявок разбить (по умолчанию 3)
      # @param delay_ms [Integer] задержка между частями в миллисекундах (по умолчанию 0 — без задержки)
      # @param return_metadata [Boolean]
      # @return [Array<PostOrderResponse, Response>] массив ответов по каждой части (при ошибке — исключение)
      def buy_sliced(
        instrument_id:,
        quantity:,
        account_id:,
        parts: 3,
        delay_ms: 0,
        return_metadata: false
      )
        execute_sliced_orders(
          direction: :ORDER_DIRECTION_BUY,
          instrument_id: instrument_id,
          quantity: quantity,
          account_id: account_id,
          parts: parts,
          delay_ms: delay_ms,
          return_metadata: return_metadata
        )
      end

      # Продажа частями по рынку (slicing): разбивает quantity на parts рыночных заявок (ORDER_TYPE_MARKET).
      #
      # @param instrument_id [String]
      # @param quantity [Integer]
      # @param account_id [String]
      # @param parts [Integer] на сколько заявок разбить (по умолчанию 3)
      # @param delay_ms [Integer] задержка между частями в миллисекундах (по умолчанию 0 — без задержки)
      # @param return_metadata [Boolean]
      # @return [Array<PostOrderResponse, Response>] массив ответов по каждой части (при ошибке — исключение)
      def sell_sliced(
        instrument_id:,
        quantity:,
        account_id:,
        parts: 3,
        delay_ms: 0,
        return_metadata: false
      )
        execute_sliced_orders(
          direction: :ORDER_DIRECTION_SELL,
          instrument_id: instrument_id,
          quantity: quantity,
          account_id: account_id,
          parts: parts,
          delay_ms: delay_ms,
          return_metadata: return_metadata
        )
      end

      # Отменить заявку.
      #
      # @param account_id [String]
      # @param order_id [String] биржевой order_id или idempotency key (с order_id_type)
      # @param order_request_id [String, nil] при указании — отмена по idempotency key
      # @param return_metadata [Boolean]
      def cancel(account_id:, order_id: nil, order_request_id: nil, return_metadata: false)
        @client.orders.cancel_order(
          account_id: account_id,
          order_id: order_id,
          order_request_id: order_request_id,
          return_metadata: return_metadata
        )
      end

      # Статус заявки.
      #
      # @param account_id [String]
      # @param order_id [String, nil]
      # @param order_request_id [String, nil]
      # @param return_metadata [Boolean]
      def get_state(account_id:, order_id: nil, order_request_id: nil, return_metadata: false)
        @client.orders.get_order_state(
          account_id: account_id,
          order_id: order_id,
          order_request_id: order_request_id,
          return_metadata: return_metadata
        )
      end

      private

      def split_quantity(total_quantity, parts)
        total_quantity = total_quantity.to_i
        parts = parts.to_i
        raise TbankGrpc::InvalidArgumentError, 'total_quantity must be positive' if total_quantity <= 0
        raise TbankGrpc::InvalidArgumentError, 'parts must be positive' if parts <= 0
        return [total_quantity] if parts == 1

        base = total_quantity / parts
        remainder = total_quantity % parts
        Array.new(parts, base).tap { |arr| remainder.times { |i| arr[i] += 1 } }
      end

      def execute_sliced_orders(
        direction:,
        instrument_id:,
        quantity:,
        account_id:,
        parts:,
        delay_ms:,
        return_metadata:
      )
        parts = [parts.to_i, 1].max
        quantities = split_quantity(quantity, parts)

        quantities.each_with_index.map do |qty, idx|
          next if qty <= 0

          sleep(delay_ms.to_i / 1000.0) if idx.positive? && delay_ms.to_i.positive?

          @client.orders.post_order(
            instrument_id: instrument_id,
            quantity: qty,
            direction: direction,
            account_id: account_id,
            order_type: :ORDER_TYPE_MARKET,
            order_id: SecureRandom.uuid,
            return_metadata: return_metadata
          )
        end.compact
      end
    end
    # rubocop:enable Metrics/ParameterLists, Metrics/ClassLength
  end
end
