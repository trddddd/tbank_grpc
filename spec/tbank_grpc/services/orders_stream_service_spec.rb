# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::OrdersStreamService do
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc' } }
  let(:interceptors) { [] }

  let(:server_service) do
    instance_double(
      TbankGrpc::Services::Streaming::Orders::ServerStreamService,
      order_state_stream: :order_state_result,
      trades_stream: :trades_result
    )
  end

  before do
    allow(TbankGrpc::Services::Streaming::Orders::ServerStreamService)
      .to receive(:new)
      .and_return(server_service)
  end

  subject(:service) do
    described_class.new(
      channel_manager: channel_manager,
      config: config,
      interceptors: interceptors
    )
  end

  it 'delegates order_state_stream to server stream service' do
    result = service.order_state_stream(
      as: :proto,
      account_ids: ['acc-1'],
      ping_delay_ms: 10_000
    )

    expect(result).to eq(:order_state_result)
    expect(server_service).to have_received(:order_state_stream)
      .with(
        as: :proto,
        account_ids: ['acc-1'],
        account_id: nil,
        accounts: nil,
        ping_delay_ms: 10_000,
        ping_delay_millis: nil
      )
  end

  it 'delegates trades_stream to server stream service' do
    result = service.trades_stream(
      as: :model,
      account_id: 'acc-1',
      ping_delay_ms: 11_000
    ) { |_payload| nil }

    expect(result).to eq(:trades_result)
    expect(server_service).to have_received(:trades_stream)
      .with(
        as: :model,
        account_ids: nil,
        account_id: 'acc-1',
        accounts: nil,
        ping_delay_ms: 11_000
      )
  end

  it 'exposes attr-style readers' do
    expect(service.channel_manager).to eq(channel_manager)
    expect(service.config).to eq(config)
  end
end
