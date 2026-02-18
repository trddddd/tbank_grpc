# frozen_string_literal: true

module TbankGrpc
  module Services
    # Сервис пользователя (UsersService): счета, информация, маржа.
    #
    # @see https://developer.tbank.ru/invest/api/users-service
    class UsersService < BaseService
      # Счета пользователя. GetAccounts.
      #
      # @param status [Symbol, nil] ACCOUNT_STATUS_* (:new, :open, :closed, :all)
      # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
      # @return [Array<Models::Accounts::Account>, Response]
      # @raise [TbankGrpc::Error]
      def get_accounts(status: nil, return_metadata: false)
        request = Tinkoff::Public::Invest::Api::Contract::V1::GetAccountsRequest.new
        if status
          request.status = resolve_enum(
            Tinkoff::Public::Invest::Api::Contract::V1::AccountStatus, status,
            prefix: 'ACCOUNT_STATUS'
          )
        end
        execute_rpc(
          method_name: :get_accounts,
          request: request,
          return_metadata: return_metadata
        ) { |response| Array(response.accounts).map { |a| Models::Accounts::Account.from_grpc(a) } }
      end

      # Информация о пользователе. GetInfo.
      #
      # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
      # @return [Models::Accounts::UserInfo, Response]
      # @raise [TbankGrpc::Error]
      def get_info(return_metadata: false)
        execute_rpc(
          method_name: :get_info,
          request: Tinkoff::Public::Invest::Api::Contract::V1::GetInfoRequest.new,
          model: Models::Accounts::UserInfo,
          return_metadata: return_metadata
        )
      end

      # Маржинальные показатели по счёту. GetMarginAttributes.
      #
      # @param account_id [String] идентификатор брокерского счёта
      # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
      # @return [Models::Accounts::MarginAttributes, Response]
      # @raise [TbankGrpc::Error]
      def get_margin_attributes(account_id:, return_metadata: false)
        request = Tinkoff::Public::Invest::Api::Contract::V1::GetMarginAttributesRequest.new(account_id: account_id)
        execute_rpc(
          method_name: :get_margin_attributes,
          request: request,
          model: Models::Accounts::MarginAttributes,
          return_metadata: return_metadata
        )
      end

      private

      def initialize_stub
        ProtoLoader.require!('users')
        Tinkoff::Public::Invest::Api::Contract::V1::UsersService::Stub.new(
          nil,
          :this_channel_is_insecure,
          channel_override: @channel,
          interceptors: @interceptors
        )
      end
    end
  end
end
