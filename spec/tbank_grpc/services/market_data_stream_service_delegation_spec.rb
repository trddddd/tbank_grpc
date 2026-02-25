# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::MarketDataStreamService do
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc' } }
  let(:interceptors) { [] }
  let(:event_loop) { double('event_loop') }
  let(:subscription_manager) { double('subscription_manager') }
  let(:reconnection_strategy) { double('reconnection_strategy') }

  let(:bidi_service) do
    instance_double(
      TbankGrpc::Services::Streaming::MarketData::BidiService,
      event_loop: event_loop,
      subscription_manager: subscription_manager,
      reconnection_strategy: reconnection_strategy,
      on: nil,
      subscribe_last_price: nil,
      listen: nil,
      stats: { listening: false }
    )
  end

  let(:server_service) do
    instance_double(
      TbankGrpc::Services::Streaming::MarketData::ServerStreamService,
      market_data_server_side_stream: :server_result
    )
  end

  before do
    allow(TbankGrpc::Services::Streaming::MarketData::BidiService)
      .to receive(:new)
      .and_return(bidi_service)
    allow(TbankGrpc::Services::Streaming::MarketData::ServerStreamService)
      .to receive(:new)
      .and_return(server_service)
  end

  subject(:service) do
    described_class.new(
      channel_manager: channel_manager,
      config: config,
      interceptors: interceptors,
      thread_pool_size: 3
    )
  end

  it 'delegates bidi callbacks and returns facade self' do
    result = service.on(:last_price, as: :proto) { |_payload| nil }

    expect(result).to eq(service)
    expect(bidi_service).to have_received(:on).with(:last_price, as: :proto)
  end

  it 'delegates bidi subscription methods' do
    service.subscribe_last_price('uid1', 'uid2')

    expect(bidi_service).to have_received(:subscribe_last_price).with('uid1', 'uid2')
  end

  it 'delegates listen lifecycle to bidi service' do
    service.listen

    expect(bidi_service).to have_received(:listen)
  end

  it 'delegates server-side stream to server service' do
    result = service.market_data_server_side_stream(as: :proto, candles: [{ instrument_id: 'uid1' }])

    expect(result).to eq(:server_result)
    expect(server_service).to have_received(:market_data_server_side_stream)
      .with(as: :proto, candles: [{ instrument_id: 'uid1' }])
  end

  it 'exposes delegated attr-style readers' do
    expect(service.channel_manager).to eq(channel_manager)
    expect(service.config).to eq(config)
    expect(service.event_loop).to eq(event_loop)
    expect(service.subscription_manager).to eq(subscription_manager)
    expect(service.reconnection_strategy).to eq(reconnection_strategy)
  end
end
