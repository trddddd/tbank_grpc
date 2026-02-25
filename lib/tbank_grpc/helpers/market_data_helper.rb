# frozen_string_literal: true

module TbankGrpc
  module Helpers
    # Утилитарные методы для типовых сценариев с {Services::MarketDataService}.
    class MarketDataHelper
      DEFAULT_MAX_CONCURRENCY = 8

      # @param client [TbankGrpc::Client]
      # @param max_concurrency [Integer] верхняя граница одновременно создаваемых потоков
      def initialize(client, max_concurrency: DEFAULT_MAX_CONCURRENCY)
        @client = client
        @max_concurrency = [max_concurrency.to_i, 1].max
      end

      # Получить стаканы для нескольких инструментов параллельно.
      #
      # @param instrument_ids [Array<String>, String] список идентификаторов инструментов
      # @param depth [Integer] глубина стакана (допустимые: 1, 10, 20, 30, 40, 50; приводится к ближайшей)
      # @return [Array<Models::MarketData::OrderBook>]
      # @raise [TbankGrpc::Error]
      def get_multiple_orderbooks(instrument_ids, depth: 20)
        ids = Array(instrument_ids).reject { |item| item.to_s.empty? }
        return [] if ids.empty?

        batch_size = [@max_concurrency, ids.length].min
        ids.each_slice(batch_size).flat_map do |slice|
          slice.map do |instrument_id|
            Thread.new { @client.market_data.get_order_book(instrument_id: instrument_id, depth: depth) }
          end.map(&:value)
        end
      end
    end
  end
end
