# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::MarketData::OrderBook do
  let(:timestamp_proto_class) { Struct.new(:seconds, :nanos, keyword_init: true) }
  let(:quotation_proto_class) { Struct.new(:units, :nano, keyword_init: true) }
  let(:order_proto_class) { Struct.new(:price, :quantity, keyword_init: true) }
  let(:order_book_proto_class) do
    Struct.new(
      :figi, :instrument_uid, :ticker, :class_code, :depth, :time, :bids, :asks,
      keyword_init: true
    )
  end

  let(:proto) do
    order_book_proto_class.new(
      figi: 'BBG004730N88',
      instrument_uid: 'uid1',
      ticker: 'SBER',
      class_code: 'TQBR',
      depth: 10,
      time: timestamp_proto_class.new(seconds: 1_707_750_000, nanos: 0),
      bids: [
        order_proto_class.new(price: quotation_proto_class.new(units: 314, nano: 190_000_000), quantity: 5)
      ],
      asks: [
        order_proto_class.new(price: quotation_proto_class.new(units: 314, nano: 200_000_000), quantity: 2_831)
      ]
    )
  end

  let(:model) { described_class.from_grpc(proto) }

  let(:wide_spread_proto) do
    order_book_proto_class.new(
      figi: 'BBG004730N88',
      instrument_uid: 'uid1',
      ticker: 'SBER',
      class_code: 'TQBR',
      depth: 10,
      time: timestamp_proto_class.new(seconds: 1_707_750_000, nanos: 0),
      bids: [
        order_proto_class.new(price: quotation_proto_class.new(units: 100, nano: 0), quantity: 1)
      ],
      asks: [
        order_proto_class.new(price: quotation_proto_class.new(units: 200, nano: 0), quantity: 1)
      ]
    )
  end

  let(:zero_volume_proto) do
    order_book_proto_class.new(
      figi: 'BBG004730N88',
      instrument_uid: 'uid1',
      ticker: 'SBER',
      class_code: 'TQBR',
      depth: 10,
      time: timestamp_proto_class.new(seconds: 1_707_750_000, nanos: 0),
      bids: [
        order_proto_class.new(price: quotation_proto_class.new(units: 100, nano: 0), quantity: 0)
      ],
      asks: [
        order_proto_class.new(price: quotation_proto_class.new(units: 101, nano: 0), quantity: 0)
      ]
    )
  end

  describe 'price representations' do
    it 'keeps bids price as Quotation in domain-level view' do
      expect(model.bids.first[:price]).to be_a(TbankGrpc::Models::Core::ValueObjects::Quotation)
    end

    it 'exposes bid_prices as BigDecimal for calculations' do
      expect(model.bid_prices.first).to be_a(BigDecimal)
      expect(model.bid_prices.first.to_s('F')).to eq('314.19')
    end

    it 'freezes bids/asks cache to prevent accidental mutation' do
      expect(model.bids).to be_frozen
      expect(model.asks).to be_frozen
      expect(model.bids.first).to be_frozen
      expect(model.asks.first).to be_frozen
      expect { model.bids.first[:quantity] = 999 }.to raise_error(FrozenError)
      expect { model.asks.first[:quantity] = 999 }.to raise_error(FrozenError)
    end

    it 'returns independent payload from to_h (mutation-safe for cache)' do
      payload = model.to_h
      payload[:bids].first[:quantity] = 999

      expect(model.bids.first[:quantity]).to eq(5)
    end
  end

  describe 'display helpers' do
    it 'returns string prices without exponential notation' do
      expect(model.best_bid_price_s).to eq('314.19')
      expect(model.best_ask_price_s).to eq('314.2')
      expect(model.spread_s).to eq('0.01')
    end

    it 'returns decimal and float helpers for best bid/ask' do
      expect(model.best_bid_price_decimal).to eq(BigDecimal('314.19'))
      expect(model.best_ask_price_decimal).to eq(BigDecimal('314.2'))
      expect(model.best_bid_price_f).to eq(314.19)
      expect(model.best_ask_price_f).to eq(314.2)
    end
  end

  describe '#bids_decimal/#asks_decimal' do
    it 'uses precomputed decimal price arrays while preserving quantity' do
      bid_level = model.bids_decimal.first
      ask_level = model.asks_decimal.first

      expect(bid_level).to include(price: BigDecimal('314.19'), quantity: 5)
      expect(ask_level).to include(price: BigDecimal('314.2'), quantity: 2_831)
      expect(bid_level[:price]).to eq(model.bid_prices.first)
      expect(ask_level[:price]).to eq(model.ask_prices.first)
    end
  end

  describe 'derived metrics' do
    it 'returns spread_bps and spread_percent as Float values' do
      expect(model.spread_bps).to be_a(Float)
      expect(model.spread_percent).to be_a(Float)
    end

    it 'calculates spread_bps relative to mid_price' do
      wide_model = described_class.from_grpc(wide_spread_proto)
      expect(wide_model.spread_bps).to eq(6666.67)
    end

    it 'returns nil imbalance when both sides have zero total quantity' do
      zero_model = described_class.from_grpc(zero_volume_proto)
      expect(zero_model.imbalance).to be_nil
    end
  end

  describe '#time' do
    it 'memoizes nil time value without recalculating' do
      no_time_proto = proto.dup
      no_time_proto.time = nil
      no_time_model = described_class.from_grpc(no_time_proto)

      allow(no_time_model).to receive(:timestamp_to_time).and_return(nil)
      2.times { no_time_model.time }

      expect(no_time_model).to have_received(:timestamp_to_time).once
    end
  end
end
