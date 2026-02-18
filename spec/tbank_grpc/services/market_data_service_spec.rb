# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::MarketDataService do
  before do
    TbankGrpc::ProtoLoader.require!('marketdata')
    allow_any_instance_of(described_class).to receive(:initialize_stub).and_return(grpc_stub)
  end

  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:config) { { token: 't', app_name: 'a', sandbox: true } }
  let(:grpc_stub) { instance_double(Tinkoff::Public::Invest::Api::Contract::V1::MarketDataService::Stub) }
  let(:service) { described_class.new(channel, config) }

  it 'uses proto-first method naming for order book' do
    expect(service).to respond_to(:get_order_book)
    expect(service).not_to respond_to(:get_orderbook)
  end

  describe '#get_order_book' do
    before do
      response = Tinkoff::Public::Invest::Api::Contract::V1::GetOrderBookResponse.new(figi: 'BBG004730N88', depth: 10)
      allow(grpc_stub).to receive(:get_order_book).and_return(response)
    end

    it 'calls gRPC with instrument_id and depth and returns model' do
      result = service.get_order_book(instrument_id: 'BBG004730N88', depth: 10)

      expect(result).to be_a(TbankGrpc::Models::MarketData::OrderBook)
      expect(grpc_stub).to have_received(:get_order_book).with(
        have_attributes(instrument_id: 'BBG004730N88', depth: 10),
        anything
      )
    end
  end

  describe '#get_candles' do
    before do
      allow(grpc_stub).to receive(:get_candles).and_return(
        Tinkoff::Public::Invest::Api::Contract::V1::GetCandlesResponse.new(candles: [])
      )
    end

    it 'calls gRPC with instrument_id, from, to and interval' do
      from_time = Time.utc(2025, 1, 1)
      to_time = Time.utc(2025, 1, 2)

      service.get_candles(
        instrument_id: 'BBG004730N88',
        from: from_time,
        to: to_time,
        interval: :CANDLE_INTERVAL_1_MIN
      )

      expect(grpc_stub).to have_received(:get_candles).with(
        have_attributes(instrument_id: 'BBG004730N88'),
        anything
      )
    end

    it 'returns CandleCollection model' do
      result = service.get_candles(
        instrument_id: 'BBG004730N88',
        from: Time.utc(2025, 1, 1),
        to: Time.utc(2025, 1, 2),
        interval: :CANDLE_INTERVAL_1_MIN
      )

      expect(result).to be_a(TbankGrpc::Models::MarketData::CandleCollection)
    end
  end

  describe '#get_last_prices' do
    before do
      allow(grpc_stub).to receive(:get_last_prices).and_return(
        Tinkoff::Public::Invest::Api::Contract::V1::GetLastPricesResponse.new(last_prices: [])
      )
    end

    it 'calls gRPC with instrument_id array' do
      service.get_last_prices(instrument_id: 'BBG004730N88')

      expect(grpc_stub).to have_received(:get_last_prices).with(
        have_attributes(instrument_id: ['BBG004730N88']),
        anything
      )
    end

    it 'returns array of LastPrice models' do
      result = service.get_last_prices(instrument_id: 'BBG004730N88')

      expect(result).to be_an(Array)
    end
  end
end
