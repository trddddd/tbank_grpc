# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe TbankGrpc::Services::MarketDataStreamService do
  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, channel: channel, reset: nil) }
  let(:config) do
    {
      token: 't',
      app_name: 'trddddd.tbank_grpc',
      stream_idle_timeout: nil,
      stream_watchdog_interval_sec: nil,
      stream_metrics_enabled: false
    }
  end
  let(:service) { described_class.new(channel_manager: channel_manager, config: config, interceptors: []) }
  let(:types) { Tinkoff::Public::Invest::Api::Contract::V1 }
  let(:bidi_service) { service.instance_variable_get(:@bidi_service) }

  before do
    TbankGrpc::ProtoLoader.require!('marketdata')
  end

  after { service.stop }

  describe 'metrics backend' do
    it 'uses Metrics with enabled: false when stream metrics are disabled (no-op, zero-shape)' do
      expect(service.metrics).to be_a(TbankGrpc::Streaming::Core::Observability::Metrics)
      expect(service.event_stats(:candle)).to include(
        emitted: 0,
        processed: 0,
        success: 0,
        errors: 0
      )
      expect(service.metrics.to_h).to include(
        uptime_seconds: 0.0,
        events_emitted: {},
        latency_stats: {},
        error_count: 0
      )
    end

    it 'uses Metrics with enabled: true and accumulates stats when stream_metrics_enabled' do
      enabled_service = described_class.new(
        channel_manager: channel_manager,
        config: config.merge(stream_metrics_enabled: true),
        interceptors: []
      )
      queue = Queue.new

      enabled_service.event_loop.start
      enabled_service.on(:candle, as: :proto) { |payload| queue << payload }
      enabled_service.instance_variable_get(:@bidi_service).send(
        :dispatch_response,
        types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid2'))
      )
      Timeout.timeout(1) { queue.pop }

      stats = enabled_service.event_stats(:candle)
      expect(enabled_service.metrics).to be_a(TbankGrpc::Streaming::Core::Observability::Metrics)
      expect(stats[:processed]).to be >= 1
      expect(stats[:avg_latency_ms]).to be > 0
    ensure
      enabled_service&.stop
    end
  end

  describe '#on' do
    it 'registers callbacks with proto and model formats' do
      service.on(:candle, as: :proto) { |_payload| nil }
      service.on(:candle, as: :model) { |_payload| nil }
      expect(true).to be(true)
    end

    it 'raises for ping with as: :model' do
      expect { service.on(:ping, as: :model) { |_payload| nil } }
        .to raise_error(TbankGrpc::InvalidArgumentError, /unsupported/i)
    end

    it 'raises for subscription_status with as: :model' do
      expect { service.on(:subscription_status, as: :model) { |_payload| nil } }
        .to raise_error(TbankGrpc::InvalidArgumentError, /unsupported/i)
    end

    it 'defaults to :model for MODEL_EVENT_TYPES when as: omitted' do
      queue = Queue.new
      service.event_loop.start
      service.on(:candle) { |payload| queue << payload }

      bidi_service.send(:dispatch_response,
                        types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid1')))
      payload = Timeout.timeout(1) { queue.pop }
      expect(payload).to be_a(TbankGrpc::Models::MarketData::Candle)
      expect(payload.instrument_uid).to eq('uid1')
    end

    it 'defaults to :proto for ping and subscription_status when as: omitted' do
      ping_queue = Queue.new
      status_queue = Queue.new
      service.event_loop.start
      service.on(:ping) { |payload| ping_queue << payload }
      service.on(:subscription_status) { |payload| status_queue << payload }

      bidi_service.send(:dispatch_response, types::MarketDataResponse.new(ping: types::Ping.new))
      expect(Timeout.timeout(1) { ping_queue.pop }).to be_a(types::Ping)

      resp = types::MarketDataResponse.new(
        subscribe_order_book_response: types::SubscribeOrderBookResponse.new(tracking_id: 't1')
      )
      bidi_service.send(:dispatch_response, resp)
      expect(Timeout.timeout(1) { status_queue.pop }).to include(type: :orderbook)
    end
  end

  describe 'dispatching events' do
    it 'dispatches open_interest as OpenInterest model' do
      queue = Queue.new
      service.event_loop.start
      service.on(:open_interest, as: :model) { |payload| queue << payload }

      open_interest = types::OpenInterest.new(instrument_uid: 'uid1', open_interest: 5)
      bidi_service.send(:dispatch_response, types::MarketDataResponse.new(open_interest: open_interest))

      payload = Timeout.timeout(1) { queue.pop }
      expect(payload).to have_attributes(
        instrument_uid: 'uid1',
        open_interest: 5
      ).and be_a(TbankGrpc::Models::MarketData::OpenInterest)
    end

    it 'dispatches subscription_status in proto format with type' do
      queue = Queue.new
      service.event_loop.start
      service.on(:subscription_status, as: :proto) { |payload| queue << payload }

      subscription_response = types::SubscribeOrderBookResponse.new(tracking_id: 'tid-1')
      bidi_service.send(
        :dispatch_response,
        types::MarketDataResponse.new(subscribe_order_book_response: subscription_response)
      )

      expect(Timeout.timeout(1) { queue.pop }).to include(type: :orderbook)
    end

    it 'includes response tracking_id in subscription_status payload' do
      queue = Queue.new
      service.event_loop.start
      service.on(:subscription_status, as: :proto) { |payload| queue << payload }

      subscription_response = types::SubscribeOrderBookResponse.new(tracking_id: 'tid-1')
      bidi_service.send(
        :dispatch_response,
        types::MarketDataResponse.new(subscribe_order_book_response: subscription_response)
      )

      first = Timeout.timeout(1) { queue.pop }
      expect(first[:response].tracking_id).to eq('tid-1')
    end

    it 'dispatches ping in proto format' do
      queue = Queue.new
      service.event_loop.start
      service.on(:ping, as: :proto) { |payload| queue << payload }

      bidi_service.send(:dispatch_response, types::MarketDataResponse.new(ping: types::Ping.new))

      expect(Timeout.timeout(1) { queue.pop }).to be_a(types::Ping)
    end

    it 'does not call Candle.from_grpc when only proto callbacks registered' do
      allow(TbankGrpc::Models::MarketData::Candle).to receive(:from_grpc)
      queue = Queue.new
      service.event_loop.start
      service.on(:candle, as: :proto) { |payload| queue << payload }

      bidi_service.send(:dispatch_response,
                        types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid1')))
      Timeout.timeout(1) { queue.pop }

      expect(TbankGrpc::Models::MarketData::Candle).not_to have_received(:from_grpc)
    end

    it 'dispatches candle proto payload when only proto callbacks registered' do
      queue = Queue.new
      service.event_loop.start
      service.on(:candle, as: :proto) { |payload| queue << payload }

      bidi_service.send(:dispatch_response,
                        types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid1')))

      expect(Timeout.timeout(1) { queue.pop }.instrument_uid).to eq('uid1')
    end
  end

  describe 'instrument_id validation' do
    it 'raises when instrument_id is blank for subscribe_orderbook' do
      expect { service.subscribe_orderbook(instrument_id: '  ') }
        .to raise_error(TbankGrpc::InvalidArgumentError, /instrument_id is required/)
    end

    it 'raises when instrument_id is empty for subscribe_candles' do
      expect { service.subscribe_candles(instrument_id: '', interval: :CANDLE_INTERVAL_1_MIN) }
        .to raise_error(TbankGrpc::InvalidArgumentError, /instrument_id is required/)
    end
  end

  describe '#market_data_server_side_stream' do
    let(:stub) { double('market_data_stream_stub') }
    let(:server_stream_service) { service.instance_variable_get(:@server_stream_service) }

    before do
      allow(server_stream_service).to receive(:build_stub).and_return(stub)
    end

    it 'supports as: :model for candle payloads' do
      response = types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid1'))
      allow(stub).to receive(:market_data_server_side_stream)
        .with(anything, hash_including(metadata: {}, deadline: nil))
        .and_return([response].to_enum)

      results = []
      service.market_data_server_side_stream(
        candles: [{ instrument_id: 'uid1', interval: :CANDLE_INTERVAL_1_MIN }],
        as: :model
      ) { |payload| results << payload }

      expect(results.first).to be_a(TbankGrpc::Models::MarketData::Candle)
      expect(stub).to have_received(:market_data_server_side_stream)
        .with(anything, hash_including(metadata: {}, deadline: nil))
    end

    it 'skips unsupported as: :model payloads (ping/subscription)' do
      response = types::MarketDataResponse.new(ping: types::Ping.new)
      allow(stub).to receive(:market_data_server_side_stream).and_return([response].to_enum)

      results = []
      service.market_data_server_side_stream(
        candles: [{ instrument_id: 'uid1', interval: :CANDLE_INTERVAL_1_MIN }],
        as: :model
      ) { |payload| results << payload }
      expect(results).to eq([])
    end

    it 'raises when candles options contain mixed waiting_close values' do
      expect do
        service.market_data_server_side_stream(
          as: :proto,
          candles: [
            { instrument_id: 'uid1', interval: :CANDLE_INTERVAL_1_MIN, waiting_close: true },
            { instrument_id: 'uid2', interval: :CANDLE_INTERVAL_1_MIN, waiting_close: false }
          ]
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /Mixed values for waiting_close/)
    end

    it 'raises when trades options contain mixed trade_source values' do
      expect do
        service.market_data_server_side_stream(
          as: :proto,
          trades: [
            { instrument_id: 'uid1', trade_source: :TRADE_SOURCE_ALL },
            { instrument_id: 'uid2', trade_source: :TRADE_SOURCE_EXCHANGE }
          ]
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /Mixed values for trade_source/)
    end
  end

  describe 'stream resilience' do
    it 'calls channel_manager.reset on force_reconnect' do
      bidi_service.send(:running=, true)

      service.force_reconnect

      expect(channel_manager).to have_received(:reset)
    end

    it 'keeps running state true after force_reconnect' do
      bidi_service.send(:running=, true)

      service.force_reconnect

      expect(bidi_service.send(:running?)).to be(true)
    end
  end
end
