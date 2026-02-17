# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Helpers::MarketDataHelper do
  let(:client) { instance_double(TbankGrpc::Client) }
  let(:market_data) { instance_double(TbankGrpc::Services::MarketDataService) }
  let(:helper) { described_class.new(client) }

  before do
    allow(client).to receive(:market_data).and_return(market_data)
  end

  describe '#get_multiple_orderbooks' do
    it 'returns [] for empty ids' do
      expect(helper.get_multiple_orderbooks([])).to eq([])
    end

    it 'fetches each order book via get_order_book' do
      allow(market_data).to receive(:get_order_book) do |instrument_id:, depth:|
        "#{instrument_id}:#{depth}"
      end

      result = helper.get_multiple_orderbooks(%w[A B], depth: 10)

      expect(result.sort).to eq(%w[A:10 B:10])
      expect(market_data).to have_received(:get_order_book).with(instrument_id: 'A', depth: 10)
      expect(market_data).to have_received(:get_order_book).with(instrument_id: 'B', depth: 10)
    end
  end
end
