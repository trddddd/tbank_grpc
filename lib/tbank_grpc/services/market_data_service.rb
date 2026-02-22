# frozen_string_literal: true

module TbankGrpc
  module Services
    # Сервис рыночных данных (MarketDataService).
    # Свечи, стакан, последние цены.
    #
    # @see https://developer.tbank.ru/invest/api/market-data-service
    class MarketDataService < Unary::BaseUnaryService
      include MarketData::CandlesAndOrderBooks
      include MarketData::PricesAndStatuses

      private

      def initialize_stub
        ProtoLoader.require!('marketdata')
        Tinkoff::Public::Invest::Api::Contract::V1::MarketDataService::Stub.new(
          nil,
          :this_channel_is_insecure,
          channel_override: @channel,
          interceptors: @interceptors
        )
      end
    end
  end
end
