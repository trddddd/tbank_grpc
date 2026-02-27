# frozen_string_literal: true

module TbankGrpc
  module Services
    # Сервис операций (OperationsService): портфель, позиции, операции (GetOperations, GetOperationsByCursor).
    # Особенности методов операций — в документации T-Bank (нестабильные id, опционы, курсор, trade_id, комиссии).
    #
    # @see https://developer.tbank.ru/invest/api/operations-service
    class OperationsService < Unary::BaseUnaryService
      # Портфель по счёту. GetPortfolio.
      #
      # @param account_id [String]
      # @param currency [Symbol, nil] :rub, :usd, :eur (опционально)
      # @param return_metadata [Boolean]
      # @return [Models::Operations::Portfolio, Response]
      def get_portfolio(account_id:, currency: nil, return_metadata: false)
        request = Tinkoff::Public::Invest::Api::Contract::V1::PortfolioRequest.new(
          account_id: normalize_account_id(account_id)
        )
        if currency
          request.currency = resolve_enum(
            Tinkoff::Public::Invest::Api::Contract::V1::PortfolioRequest::CurrencyRequest,
            currency,
            prefix: nil
          )
        end
        execute_rpc(
          method_name: :get_portfolio,
          request: request,
          model: Models::Operations::Portfolio,
          return_metadata: return_metadata
        )
      end

      # Позиции по счёту. GetPositions.
      #
      # @param account_id [String]
      # @param return_metadata [Boolean]
      # @return [Models::Operations::Positions, Response]
      def get_positions(account_id:, return_metadata: false)
        request = Tinkoff::Public::Invest::Api::Contract::V1::PositionsRequest.new(
          account_id: normalize_account_id(account_id)
        )
        execute_rpc(
          method_name: :get_positions,
          request: request,
          model: Models::Operations::Positions,
          return_metadata: return_metadata
        )
      end

      # Список операций за период. GetOperations.
      #
      # @param account_id [String]
      # @param from [Time, String, Date]
      # @param to [Time, String, Date]
      # @param state [Symbol, Integer, nil] OPERATION_STATE_*
      # @param figi [String, nil]
      # @param return_metadata [Boolean]
      # @return [Array<Models::Operations::Operation>, Response]
      # rubocop:disable Metrics/ParameterLists
      def get_operations(account_id:, from:, to:, state: nil, figi: nil, return_metadata: false)
        request = Tinkoff::Public::Invest::Api::Contract::V1::OperationsRequest.new(
          account_id: normalize_account_id(account_id),
          from: timestamp_to_proto(from),
          to: timestamp_to_proto(to)
        )
        if state
          request.state = resolve_enum(
            Tinkoff::Public::Invest::Api::Contract::V1::OperationState,
            state,
            prefix: 'OPERATION_STATE'
          )
        end
        request.figi = figi if figi
        execute_list_rpc(
          method_name: :get_operations,
          request: request,
          response_collection: :operations,
          model_class: Models::Operations::Operation,
          return_metadata: return_metadata
        )
      end
      # rubocop:enable Metrics/ParameterLists

      # Список операций по курсору (пагинация). GetOperationsByCursor.
      #
      # @param account_id [String]
      # @param from [Time, String, nil]
      # @param to [Time, String, nil]
      # @param cursor [String, nil]
      # @param limit [Integer, nil]
      # @param instrument_id [String, nil]
      # @param operation_types [Array, nil] OPERATION_TYPE_*
      # @param state [Symbol, Integer, nil]
      # @param without_commissions [Boolean, nil]
      # @param without_trades [Boolean, nil]
      # @param without_overnights [Boolean, nil]
      # @param return_metadata [Boolean]
      # @return [Tinkoff::...::GetOperationsByCursorResponse, Response]
      # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      def get_operations_by_cursor(
        account_id:,
        from: nil,
        to: nil,
        cursor: nil,
        limit: nil,
        instrument_id: nil,
        operation_types: nil,
        state: nil,
        without_commissions: nil,
        without_trades: nil,
        without_overnights: nil,
        return_metadata: false
      )
        request = Tinkoff::Public::Invest::Api::Contract::V1::GetOperationsByCursorRequest.new(
          account_id: normalize_account_id(account_id)
        )
        request.instrument_id = instrument_id if instrument_id
        request.from = timestamp_to_proto(from) if from
        request.to = timestamp_to_proto(to) if to
        request.cursor = cursor if cursor
        request.limit = limit if limit
        if operation_types
          request.operation_types = Array(operation_types).map do |t|
            resolve_enum(
              Tinkoff::Public::Invest::Api::Contract::V1::OperationType,
              t,
              prefix: 'OPERATION_TYPE'
            )
          end
        end
        if state
          request.state = resolve_enum(
            Tinkoff::Public::Invest::Api::Contract::V1::OperationState,
            state,
            prefix: 'OPERATION_STATE'
          )
        end
        request.without_commissions = without_commissions unless without_commissions.nil?
        request.without_trades = without_trades unless without_trades.nil?
        request.without_overnights = without_overnights unless without_overnights.nil?
        execute_rpc(
          method_name: :get_operations_by_cursor,
          request: request,
          return_metadata: return_metadata
        )
      end
      # rubocop:enable Metrics/ParameterLists, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      private

      def initialize_stub
        ProtoLoader.require!('operations')
        Tinkoff::Public::Invest::Api::Contract::V1::OperationsService::Stub.new(
          nil,
          :this_channel_is_insecure,
          channel_override: @channel,
          interceptors: @interceptors
        )
      end

      def normalize_account_id(account_id)
        Normalizers::AccountIdNormalizer.normalize_single(account_id, strip: true)
      end
    end
  end
end
