# frozen_string_literal: true

module TbankGrpc
  module Helpers
    # Точка входа в прикладные helper-обёртки клиента.
    class Facade
      # @param client [TbankGrpc::Client]
      def initialize(client)
        @client = client
      end

      # @return [InstrumentsHelper]
      def instruments
        @instruments ||= InstrumentsHelper.new(@client)
      end

      # @return [MarketDataHelper]
      def market_data
        @market_data ||= MarketDataHelper.new(@client)
      end
    end
  end
end
