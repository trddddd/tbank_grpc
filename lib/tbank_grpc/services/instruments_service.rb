# frozen_string_literal: true

module TbankGrpc
  module Services
    # Клиент обёртки над `InstrumentsService` T-Invest API.
    #
    # В текущем проекте реализован ограниченный набор RPC:
    # `GetInstrumentBy`, `ShareBy`, `BondBy`, `FutureBy`, `FindInstrument`,
    # `Shares`, `Bonds`, `Futures`, `TradingSchedules`,
    # `GetBondCoupons`, `GetAccruedInterests`, `GetDividends`, `GetFuturesMargin`,
    # `GetAssetBy`, `GetAssetFundamentals`, `GetAssetReports`.
    #
    # @see https://developer.tbank.ru/invest/api/instruments-service
    class InstrumentsService < BaseService
      include Instruments::Lookup
      include Instruments::Listings
      include Instruments::Schedules
      include Instruments::CorporateActions
      include Instruments::Derivatives
      include Instruments::Assets

      private

      def initialize_stub
        ProtoLoader.require!('instruments')
        Tinkoff::Public::Invest::Api::Contract::V1::InstrumentsService::Stub.new(
          nil,
          :this_channel_is_insecure,
          channel_override: @channel,
          interceptors: @interceptors
        )
      end
    end
  end
end
