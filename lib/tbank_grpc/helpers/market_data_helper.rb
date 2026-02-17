# frozen_string_literal: true

module TbankGrpc
  module Helpers
    # Утилитарные методы для типовых сценариев с {Services::MarketDataService}.
    class MarketDataHelper
      # @param client [TbankGrpc::Client]
      def initialize(client)
        @client = client
      end

      # Получить стаканы для нескольких инструментов параллельно.
      #
      # @param instrument_ids [Array<String>, String] список идентификаторов инструментов
      # @param depth [Integer] глубина стакана (1..50)
      # @return [Array<Models::MarketData::OrderBook>]
      # @raise [TbankGrpc::Error]
      def get_multiple_orderbooks(instrument_ids, depth: 20)
        ids = Array(instrument_ids).reject { |item| item.to_s.empty? }
        return [] if ids.empty?

        ids.map do |instrument_id|
          Thread.new { @client.market_data.get_order_book(instrument_id: instrument_id, depth: depth) }
        end.map(&:value)
      end
    end
  end
end
