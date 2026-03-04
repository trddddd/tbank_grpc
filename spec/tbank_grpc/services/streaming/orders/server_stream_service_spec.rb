# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::Streaming::Orders::ServerStreamService do
  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, channel: channel) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc' } }
  let(:service) { described_class.new(channel_manager: channel_manager, config: config, interceptors: []) }
  let(:stub) { double('orders_stream_stub') }
  let(:types) { TbankGrpc::CONTRACT_V1 }

  before do
    TbankGrpc::ProtoLoader.require!('orders')
    allow(service).to receive(:initialize_stub).and_return(stub)
  end

  describe '#order_state_stream' do
    it 'returns stream enumerator for as: :proto without block' do
      stream = [types::OrderStateStreamResponse.new].to_enum
      allow(stub).to receive(:order_state_stream).and_return(stream)

      result = service.order_state_stream(as: :proto, account_ids: [' acc-1 '])

      expect(result).to eq(stream)
      expect(stub).to have_received(:order_state_stream).with(
        have_attributes(accounts: ['acc-1']),
        hash_including(metadata: {}, deadline: nil)
      )
    end

    it 'maps only order_state payload in model mode' do
      responses = [
        types::OrderStateStreamResponse.new(
          subscription: types::SubscriptionResponse.new(status: :RESULT_SUBSCRIPTION_STATUS_OK)
        ),
        types::OrderStateStreamResponse.new(ping: types::Ping.new),
        types::OrderStateStreamResponse.new(
          order_state: types::OrderStateStreamResponse::OrderState.new(order_id: 'ex-1')
        )
      ]
      allow(stub).to receive(:order_state_stream).and_return(responses.to_enum)

      results = []
      service.order_state_stream(as: :model, account_ids: ['acc-1']) { |payload| results << payload }

      expect(results.size).to eq(1)
      expect(results.first).to be_a(TbankGrpc::Models::Orders::OrderStreamState)
      expect(results.first.order_id).to eq('ex-1')
    end

    it 'validates ping_delay_millis range' do
      allow(stub).to receive(:order_state_stream).and_return([types::OrderStateStreamResponse.new].to_enum)

      expect do
        service.order_state_stream(as: :proto, account_ids: ['acc-1'], ping_delay_millis: 1_000)
      end.not_to raise_error

      expect do
        service.order_state_stream(as: :proto, account_ids: ['acc-1'], ping_delay_millis: 999)
      end.to raise_error(TbankGrpc::InvalidArgumentError, /ping_delay_millis/)

      expect do
        service.order_state_stream(as: :proto, account_ids: ['acc-1'], ping_delay_millis: 120_001)
      end.to raise_error(TbankGrpc::InvalidArgumentError, /ping_delay_millis/)
    end

    it 'raises when both ping_delay_ms and ping_delay_millis are provided' do
      expect do
        service.order_state_stream(
          as: :proto,
          account_ids: ['acc-1'],
          ping_delay_ms: 10_000,
          ping_delay_millis: 10_000
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /Provide only one of ping_delay_ms or ping_delay_millis/)
    end
  end

  describe '#trades_stream' do
    it 'maps only order_trades payload in model mode' do
      responses = [
        types::TradesStreamResponse.new(
          subscription: types::SubscriptionResponse.new(status: :RESULT_SUBSCRIPTION_STATUS_OK)
        ),
        types::TradesStreamResponse.new(ping: types::Ping.new),
        types::TradesStreamResponse.new(order_trades: types::OrderTrades.new(order_id: 'ex-2'))
      ]
      allow(stub).to receive(:trades_stream).and_return(responses.to_enum)

      results = []
      service.trades_stream(as: :model, account_ids: ['acc-1']) { |payload| results << payload }

      expect(results.size).to eq(1)
      expect(results.first).to be_a(TbankGrpc::Models::Orders::OrderTrades)
      expect(results.first.order_id).to eq('ex-2')
    end

    it 'raises for as: :model without block' do
      allow(stub).to receive(:trades_stream).and_return([types::TradesStreamResponse.new].to_enum)

      expect do
        service.trades_stream(as: :model, account_ids: ['acc-1'])
      end.to raise_error(TbankGrpc::InvalidArgumentError, /requires block/i)
    end
  end

  it 'raises when multiple account sources are provided' do
    expect do
      service.trades_stream(account_ids: ['acc-1'], account_id: 'acc-2')
    end.to raise_error(TbankGrpc::InvalidArgumentError, /Provide only one/)
  end
end
