# frozen_string_literal: true

module TbankGrpc
  module Services
    # Сервис торговых поручений (OrdersService): выставление, отмена, статус, стоимость, лимиты.
    #
    # Важные нюансы API:
    # - В PostOrder/PostOrderAsync поле order_id — это idempotency key (UID, до 36 символов).
    # - Для запросов по idempotency key используйте order_id_type: :ORDER_ID_TYPE_REQUEST
    #   или удобные методы *_by_request_id.
    # - В GetOrders фильтры from/to применимы только к заявкам, созданным сегодня.
    #
    # @see https://developer.tbank.ru/invest/services/orders/head-orders
    # @see https://developer.tbank.ru/invest/services/orders/methods
    # @see https://developer.tbank.ru/invest/services/orders/async
    # rubocop:disable Metrics/ClassLength, Metrics/ParameterLists
    class OrdersService < Unary::BaseUnaryService
      UID_MAX_LENGTH = 36

      # Выставить заявку (синхронно). PostOrder.
      #
      # @param instrument_id [String, nil] FIGI или instrument_uid
      # @param figi [String, nil] deprecated, alias для instrument_id
      # @param quantity [Integer]
      # @param direction [Symbol, Integer] ORDER_DIRECTION_*
      # @param account_id [String]
      # @param order_type [Symbol, Integer] ORDER_TYPE_*
      # @param order_id [String, nil] idempotency key (UID)
      # @param order_request_id [String, nil] alias к order_id
      # @param price [Numeric, Models::Core::ValueObjects::Quotation, Quotation, nil]
      # @param time_in_force [Symbol, Integer, nil] TIME_IN_FORCE_*
      # @param price_type [Symbol, Integer, nil] PRICE_TYPE_*
      # @param confirm_margin_trade [Boolean, nil]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::OrderResponse, Response]
      def post_order(
        quantity:, direction:, account_id:, order_type:, instrument_id: nil,
        figi: nil,
        order_id: nil,
        order_request_id: nil,
        price: nil,
        time_in_force: nil,
        price_type: nil,
        confirm_margin_trade: nil,
        return_metadata: false
      )
        request = TbankGrpc::CONTRACT_V1::PostOrderRequest.new(
          instrument_id: resolve_order_instrument_id(instrument_id: instrument_id, figi: figi),
          quantity: Normalizers::CommonNormalizer.positive_integer(quantity, field_name: 'quantity'),
          direction: resolve_enum(TbankGrpc::CONTRACT_V1::OrderDirection, direction, prefix: 'ORDER_DIRECTION'),
          account_id: normalize_account_id(account_id),
          order_type: resolve_enum(TbankGrpc::CONTRACT_V1::OrderType, order_type, prefix: 'ORDER_TYPE'),
          order_id: resolve_order_request_id(order_id: order_id, order_request_id: order_request_id)
        )
        request.price = build_quotation(price) if price
        if time_in_force
          request.time_in_force = resolve_enum(TbankGrpc::CONTRACT_V1::TimeInForceType, time_in_force,
                                               prefix: 'TIME_IN_FORCE')
        end
        if price_type
          request.price_type = resolve_enum(TbankGrpc::CONTRACT_V1::PriceType, price_type,
                                            prefix: 'PRICE_TYPE')
        end
        request.confirm_margin_trade = confirm_margin_trade unless confirm_margin_trade.nil?

        execute_rpc(
          method_name: :post_order,
          request: request,
          model: Models::Orders::OrderResponse,
          return_metadata: return_metadata
        )
      end

      # Выставить заявку асинхронно. PostOrderAsync.
      #
      # @note Для контроля результата используйте get_order_state_by_request_id или OrderStateStream.
      # @return [Models::Orders::OrderAsyncResponse, Response]
      def post_order_async(
        instrument_id:,
        quantity:,
        direction:,
        account_id:,
        order_type:,
        order_id: nil,
        order_request_id: nil,
        price: nil,
        time_in_force: nil,
        price_type: nil,
        confirm_margin_trade: nil,
        return_metadata: false
      )
        request = TbankGrpc::CONTRACT_V1::PostOrderAsyncRequest.new(
          instrument_id: resolve_instrument_id(instrument_id: instrument_id),
          quantity: Normalizers::CommonNormalizer.positive_integer(quantity, field_name: 'quantity'),
          direction: resolve_enum(TbankGrpc::CONTRACT_V1::OrderDirection, direction, prefix: 'ORDER_DIRECTION'),
          account_id: normalize_account_id(account_id),
          order_type: resolve_enum(TbankGrpc::CONTRACT_V1::OrderType, order_type, prefix: 'ORDER_TYPE'),
          order_id: resolve_order_request_id(order_id: order_id, order_request_id: order_request_id)
        )
        request.price = build_quotation(price) if price
        if time_in_force
          request.time_in_force = resolve_enum(TbankGrpc::CONTRACT_V1::TimeInForceType, time_in_force,
                                               prefix: 'TIME_IN_FORCE')
        end
        if price_type
          request.price_type = resolve_enum(TbankGrpc::CONTRACT_V1::PriceType, price_type,
                                            prefix: 'PRICE_TYPE')
        end
        request.confirm_margin_trade = confirm_margin_trade unless confirm_margin_trade.nil?

        execute_rpc(
          method_name: :post_order_async,
          request: request,
          model: Models::Orders::OrderAsyncResponse,
          return_metadata: return_metadata
        )
      end

      # Отменить заявку. CancelOrder.
      #
      # @param account_id [String]
      # @param order_id [String, nil] exchange order_id или request id (с order_id_type: :request)
      # @param order_request_id [String, nil] idempotency key; автоматически ставит order_id_type=request
      # @param order_id_type [Symbol, Integer, nil] ORDER_ID_TYPE_*
      # @param return_metadata [Boolean]
      # @return [Models::Orders::CancelOrderResponse, Response]
      def cancel_order(account_id:, order_id: nil, order_request_id: nil, order_id_type: nil, return_metadata: false)
        normalized_order_id, normalized_order_id_type = resolve_lookup_order_identifier(
          order_id: order_id,
          order_request_id: order_request_id,
          order_id_type: order_id_type
        )
        request = TbankGrpc::CONTRACT_V1::CancelOrderRequest.new(
          account_id: normalize_account_id(account_id),
          order_id: normalized_order_id
        )
        request.order_id_type = normalized_order_id_type if normalized_order_id_type

        execute_rpc(
          method_name: :cancel_order,
          request: request,
          model: Models::Orders::CancelOrderResponse,
          return_metadata: return_metadata
        )
      end

      # Статус поручения. GetOrderState.
      #
      # @param account_id [String]
      # @param order_id [String, nil]
      # @param order_request_id [String, nil]
      # @param price_type [Symbol, Integer, nil] PRICE_TYPE_*
      # @param order_id_type [Symbol, Integer, nil] ORDER_ID_TYPE_*
      # @param return_metadata [Boolean]
      # @return [Models::Orders::OrderState, Response]
      def get_order_state(
        account_id:,
        order_id: nil,
        order_request_id: nil,
        price_type: nil,
        order_id_type: nil,
        return_metadata: false
      )
        normalized_order_id, normalized_order_id_type = resolve_lookup_order_identifier(
          order_id: order_id,
          order_request_id: order_request_id,
          order_id_type: order_id_type
        )
        request = TbankGrpc::CONTRACT_V1::GetOrderStateRequest.new(
          account_id: normalize_account_id(account_id),
          order_id: normalized_order_id
        )
        if price_type
          request.price_type = resolve_enum(TbankGrpc::CONTRACT_V1::PriceType, price_type,
                                            prefix: 'PRICE_TYPE')
        end
        request.order_id_type = normalized_order_id_type if normalized_order_id_type

        execute_rpc(
          method_name: :get_order_state,
          request: request,
          model: Models::Orders::OrderState,
          return_metadata: return_metadata
        )
      end

      # Удобный метод: получить статус по idempotency key.
      #
      # @param account_id [String]
      # @param order_request_id [String]
      # @param price_type [Symbol, Integer, nil]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::OrderState, Response]
      def get_order_state_by_request_id(account_id:, order_request_id:, price_type: nil, return_metadata: false)
        get_order_state(
          account_id: account_id,
          order_request_id: order_request_id,
          order_id_type: :ORDER_ID_TYPE_REQUEST,
          price_type: price_type,
          return_metadata: return_metadata
        )
      end

      # Удобный метод: отменить по idempotency key.
      #
      # @param account_id [String]
      # @param order_request_id [String]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::CancelOrderResponse, Response]
      def cancel_order_by_request_id(account_id:, order_request_id:, return_metadata: false)
        cancel_order(
          account_id: account_id,
          order_request_id: order_request_id,
          order_id_type: :ORDER_ID_TYPE_REQUEST,
          return_metadata: return_metadata
        )
      end

      # Список активных заявок по счёту. GetOrders.
      #
      # @param account_id [String]
      # @param from [Time, String, Date, nil] применимо только для заявок, созданных сегодня
      # @param to [Time, String, Date, nil] применимо только для заявок, созданных сегодня
      # @param execution_status [Array<Symbol, Integer>, Symbol, Integer, nil] EXECUTION_REPORT_STATUS_*
      # @param return_metadata [Boolean]
      # @return [Array<Models::Orders::OrderState>, Response]
      def get_orders(account_id:, from: nil, to: nil, execution_status: nil, return_metadata: false)
        request = TbankGrpc::CONTRACT_V1::GetOrdersRequest.new(account_id: normalize_account_id(account_id))
        filters = build_orders_filters(from: from, to: to, execution_status: execution_status)
        request.advanced_filters = filters if filters

        execute_rpc(method_name: :get_orders, request: request, return_metadata: return_metadata) do |response|
          Array(response.orders).map { |state| Models::Orders::OrderState.from_grpc(state) }
        end
      end

      # Изменить активную заявку. ReplaceOrder.
      #
      # @param account_id [String]
      # @param order_id [String]
      # @param idempotency_key [String] новый idempotency key (UID)
      # @param quantity [Integer]
      # @param price [Numeric, Models::Core::ValueObjects::Quotation, Quotation, nil]
      # @param price_type [Symbol, Integer, nil]
      # @param confirm_margin_trade [Boolean, nil]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::OrderResponse, Response]
      def replace_order(
        account_id:,
        order_id:,
        idempotency_key:,
        quantity:,
        price: nil,
        price_type: nil,
        confirm_margin_trade: nil,
        return_metadata: false
      )
        request = TbankGrpc::CONTRACT_V1::ReplaceOrderRequest.new(
          account_id: normalize_account_id(account_id),
          order_id: Normalizers::CommonNormalizer.non_empty_string(order_id, field_name: 'order_id'),
          idempotency_key: Normalizers::CommonNormalizer.uid(
            idempotency_key,
            field_name: 'idempotency_key',
            max_length: UID_MAX_LENGTH
          ),
          quantity: Normalizers::CommonNormalizer.positive_integer(quantity, field_name: 'quantity')
        )
        request.price = build_quotation(price) if price
        if price_type
          request.price_type = resolve_enum(TbankGrpc::CONTRACT_V1::PriceType, price_type,
                                            prefix: 'PRICE_TYPE')
        end
        request.confirm_margin_trade = confirm_margin_trade unless confirm_margin_trade.nil?

        execute_rpc(
          method_name: :replace_order,
          request: request,
          model: Models::Orders::OrderResponse,
          return_metadata: return_metadata
        )
      end

      # Расчёт доступных лотов на покупку/продажу. GetMaxLots.
      #
      # @param account_id [String]
      # @param instrument_id [String]
      # @param price [Numeric, Models::Core::ValueObjects::Quotation, Quotation, nil]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::MaxLots, Response]
      def get_max_lots(account_id:, instrument_id:, price: nil, return_metadata: false)
        request = TbankGrpc::CONTRACT_V1::GetMaxLotsRequest.new(
          account_id: normalize_account_id(account_id),
          instrument_id: resolve_instrument_id(instrument_id: instrument_id)
        )
        request.price = build_quotation(price) if price

        execute_rpc(
          method_name: :get_max_lots,
          request: request,
          model: Models::Orders::MaxLots,
          return_metadata: return_metadata
        )
      end

      # Предварительная стоимость лимитной заявки. GetOrderPrice.
      #
      # @param account_id [String]
      # @param instrument_id [String]
      # @param price [Numeric, Models::Core::ValueObjects::Quotation, Quotation]
      # @param direction [Symbol, Integer] ORDER_DIRECTION_*
      # @param quantity [Integer]
      # @param return_metadata [Boolean]
      # @return [Models::Orders::OrderPrice, Response]
      def get_order_price(account_id:, instrument_id:, price:, direction:, quantity:, return_metadata: false)
        raise InvalidArgumentError, 'price is required for GetOrderPrice (limit order pre-check)' if price.nil?

        request = TbankGrpc::CONTRACT_V1::GetOrderPriceRequest.new(
          account_id: normalize_account_id(account_id),
          instrument_id: resolve_instrument_id(instrument_id: instrument_id),
          price: build_quotation(price),
          direction: resolve_enum(TbankGrpc::CONTRACT_V1::OrderDirection, direction, prefix: 'ORDER_DIRECTION'),
          quantity: Normalizers::CommonNormalizer.positive_integer(quantity, field_name: 'quantity')
        )

        execute_rpc(
          method_name: :get_order_price,
          request: request,
          model: Models::Orders::OrderPrice,
          return_metadata: return_metadata
        )
      end

      private

      def initialize_stub
        ProtoLoader.require!('orders')
        TbankGrpc::CONTRACT_V1::OrdersService::Stub.new(
          nil,
          :this_channel_is_insecure,
          channel_override: @channel,
          interceptors: @interceptors
        )
      end

      def normalize_account_id(account_id)
        Normalizers::AccountIdNormalizer.normalize_single(account_id, strip: true)
      end

      def resolve_order_instrument_id(instrument_id:, figi:)
        if instrument_id && figi && instrument_id.to_s.strip != figi.to_s.strip
          raise InvalidArgumentError, 'Provide only one identifier: instrument_id or figi'
        end

        resolve_instrument_id(instrument_id: instrument_id || figi)
      end

      def resolve_order_request_id(order_id:, order_request_id:)
        if order_id && order_request_id && order_id.to_s.strip != order_request_id.to_s.strip
          raise InvalidArgumentError, 'order_id and order_request_id must be equal when both provided'
        end

        Normalizers::CommonNormalizer.uid(
          order_id || order_request_id,
          field_name: 'order_id',
          max_length: UID_MAX_LENGTH
        )
      end

      def resolve_lookup_order_identifier(order_id:, order_request_id:, order_id_type:)
        if order_id && order_request_id && order_id.to_s.strip != order_request_id.to_s.strip
          raise InvalidArgumentError, 'order_id and order_request_id must be equal when both provided'
        end

        if order_request_id
          return [
            Normalizers::CommonNormalizer.uid(
              order_request_id,
              field_name: 'order_request_id',
              max_length: UID_MAX_LENGTH
            ),
            resolve_enum(TbankGrpc::CONTRACT_V1::OrderIdType, order_id_type || :ORDER_ID_TYPE_REQUEST,
                         prefix: 'ORDER_ID_TYPE')
          ]
        end

        [
          Normalizers::CommonNormalizer.non_empty_string(order_id, field_name: 'order_id'),
          (resolve_enum(TbankGrpc::CONTRACT_V1::OrderIdType, order_id_type, prefix: 'ORDER_ID_TYPE') if order_id_type)
        ]
      end

      def build_orders_filters(from:, to:, execution_status:)
        statuses = Array(execution_status).compact
        return nil if from.nil? && to.nil? && statuses.empty?

        filters = TbankGrpc::CONTRACT_V1::GetOrdersRequest::GetOrdersRequestFilters.new
        filters.from = timestamp_to_proto(from) if from
        filters.to = timestamp_to_proto(to) if to
        unless statuses.empty?
          statuses.each do |status|
            filters.execution_status << resolve_enum(
              TbankGrpc::CONTRACT_V1::OrderExecutionReportStatus,
              status,
              prefix: 'EXECUTION_REPORT_STATUS'
            )
          end
        end
        filters
      end
    end
    # rubocop:enable Metrics/ClassLength, Metrics/ParameterLists
  end
end
