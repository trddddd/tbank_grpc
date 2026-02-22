# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Subscriptions::Manager do
  let(:manager) { described_class.new }
  let(:types) { Tinkoff::Public::Invest::Api::Contract::V1 }

  before do
    TbankGrpc::ProtoLoader.require!('marketdata')
  end

  def expect_enum_value(actual, enum_module, constant_name)
    expected_symbol = constant_name.to_sym
    expected_number = enum_module.const_get(constant_name)
    expect([expected_symbol, expected_number]).to include(actual)
  end

  describe 'request building' do
    it 'builds order book request with order_book_type and normalized depth' do
      manager.subscribe(:orderbook, instrument_id: 'uid1', depth: 11, order_book_type: :ORDERBOOK_TYPE_DEALER)
      request = manager.pop_request

      payload = request.subscribe_order_book_request
      instrument = payload.instruments.first

      expect_enum_value(payload.subscription_action, types::SubscriptionAction, :SUBSCRIPTION_ACTION_SUBSCRIBE)
      expect(instrument.instrument_id).to eq('uid1')
      expect(instrument.depth).to eq(10)
      expect_enum_value(instrument.order_book_type, types::OrderBookType, :ORDERBOOK_TYPE_DEALER)
    end

    it 'builds trades request with trade_source and with_open_interest' do
      manager.subscribe(
        :trades,
        instrument_ids: %w[uid1 uid2],
        trade_source: :TRADE_SOURCE_EXCHANGE,
        with_open_interest: true
      )

      request = manager.pop_request
      payload = request.subscribe_trades_request

      expect(payload.instruments.map(&:instrument_id)).to eq(%w[uid1 uid2])
      expect_enum_value(payload.trade_source, types::TradeSourceType, :TRADE_SOURCE_EXCHANGE)
      expect(payload.with_open_interest).to be(true)
    end

    it 'builds candles request with waiting_close and candle_source_type' do
      manager.subscribe(
        :candles,
        instrument_id: 'uid1',
        interval: :CANDLE_INTERVAL_15_MIN,
        waiting_close: true,
        candle_source_type: :CANDLE_SOURCE_EXCHANGE
      )

      request = manager.pop_request
      payload = request.subscribe_candles_request

      expect(payload.instruments.first.instrument_id).to eq('uid1')
      expect(payload.waiting_close).to be(true)
      expect_enum_value(
        payload.candle_source_type,
        types::GetCandlesRequest::CandleSource,
        :CANDLE_SOURCE_EXCHANGE
      )
    end

    it 'supports all declared stream intervals and candle interval aliases' do
      mapping = TbankGrpc::Converters::CandleToSubscriptionInterval::CANDLE_TO_SUBSCRIPTION
      intervals = mapping.keys + types::SubscriptionInterval.constants

      intervals.uniq.each_with_index do |interval, idx|
        manager.subscribe(:candles, instrument_id: "uid#{idx}", interval: interval)
        request = manager.pop_request
        actual_interval = request.subscribe_candles_request.instruments.first.interval
        enum_constants = types::SubscriptionInterval.constants
        enum_values = enum_constants.map { |name| types::SubscriptionInterval.const_get(name) }
        expect(enum_constants + enum_values).to include(actual_interval)
      end
    end
  end

  describe '#pop_request' do
    it 'returns nil when timeout expires and queue is empty' do
      expect(manager.pop_request(timeout_sec: 0.01)).to be_nil
    end

    it 'returns queued request with timeout mode' do
      manager.subscribe(:info, instrument_ids: ['uid1'])

      request = manager.pop_request(timeout_sec: 0.1)
      expect(request.subscribe_info_request.instruments.map(&:instrument_id)).to eq(['uid1'])
    end
  end

  describe '#initial_requests' do
    it 'does not duplicate startup subscribe requests and keeps control requests in queue' do
      manager.subscribe(:orderbook, instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_ALL)
      manager.request_my_subscriptions

      initial = manager.initial_requests

      subscribe_orderbooks = initial.map(&:subscribe_order_book_request).compact
      expect(subscribe_orderbooks.size).to eq(1)
      expect(subscribe_orderbooks.first.instruments.map(&:instrument_id)).to eq(['uid1'])

      control = manager.pop_request
      expect(control.get_my_subscriptions).not_to be_nil
      expect(manager.pop_request(timeout_sec: 0.01)).to be_nil
    end
  end

  describe 'idempotency' do
    it 'does not enqueue duplicate subscribe for same params' do
      manager.subscribe(:orderbook, instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_ALL)
      manager.subscribe(:orderbook, instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_ALL)

      first = manager.pop_request
      second = manager.pop_request(timeout_sec: 0.01)

      expect(first.subscribe_order_book_request).not_to be_nil
      expect(second).to be_nil
      expect(manager.total_subscriptions).to eq(1)
    end

    it 'does not enqueue unsubscribe when subscription is absent' do
      manager.unsubscribe(:orderbook, instrument_id: 'uid1', depth: 10, order_book_type: :ORDERBOOK_TYPE_ALL)

      expect(manager.pop_request(timeout_sec: 0.01)).to be_nil
    end
  end

  describe 'limits' do
    it 'enforces 300 total subscriptions excluding info stream' do
      manager.subscribe(:info, instrument_ids: Array.new(50) { |i| "info#{i}" })
      manager.subscribe(:trades, instrument_ids: Array.new(300) { |i| "trade#{i}" })

      expect do
        manager.subscribe(:last_price, instrument_ids: ['overflow'])
      end.to raise_error(TbankGrpc::InvalidArgumentError, /Subscription limit exceeded/)
    end

    it 'enforces 100 subscription mutations per minute' do
      100.times do |i|
        manager.subscribe(:info, instrument_ids: ["uid#{i}"])
      end

      expect do
        manager.subscribe(:info, instrument_ids: ['uid-over'])
      end.to raise_error(TbankGrpc::InvalidArgumentError, /mutation limit exceeded/i)
    end
  end

  describe 'ping settings' do
    it 'validates ping_delay_ms range' do
      expect { manager.set_ping_delay(ms: 4000) }
        .to raise_error(TbankGrpc::InvalidArgumentError, /5000\.\.180000/)
    end

    it 'pushes ping settings request for valid ping_delay_ms' do
      manager.set_ping_delay(ms: 6000)
      request = manager.pop_request
      expect(request.ping_settings.ping_delay_ms).to eq(6000)
    end
  end
end
