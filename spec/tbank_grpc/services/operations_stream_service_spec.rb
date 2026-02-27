# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::OperationsStreamService do
  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, channel: channel) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc' } }
  let(:service) { described_class.new(channel_manager: channel_manager, config: config, interceptors: []) }
  let(:types) { TbankGrpc::CONTRACT_V1 }
  let(:server_stream_service) { service.instance_variable_get(:@server_stream_service) }
  let(:stub) { double('operations_stream_stub') }

  before do
    TbankGrpc::ProtoLoader.require!('operations')
    allow(server_stream_service).to receive(:initialize_stub).and_return(stub)
  end

  describe 'instance interface' do
    %i[portfolio_stream positions_stream operations_stream].each do |method_name|
      it "responds to ##{method_name}" do
        expect(service).to respond_to(method_name)
      end
    end
  end

  describe '#portfolio_stream' do
    it 'returns raw stream enumerator without block for as: :proto' do
      stream = [types::PortfolioStreamResponse.new].to_enum
      allow(stub).to receive(:portfolio_stream).and_return(stream)

      result = service.portfolio_stream(account_ids: ['acc-1'], as: :proto)

      expect(result).to eq(stream)
      expect(stub).to have_received(:portfolio_stream).with(
        have_attributes(accounts: ['acc-1']),
        hash_including(metadata: {})
      )
    end

    it 'maps only portfolio payload to model for as: :model' do
      responses = [
        types::PortfolioStreamResponse.new(
          subscriptions: types::PortfolioSubscriptionResult.new(tracking_id: 'tid-1')
        ),
        types::PortfolioStreamResponse.new(ping: types::Ping.new),
        types::PortfolioStreamResponse.new(portfolio: types::PortfolioResponse.new(account_id: 'acc-1'))
      ]
      allow(stub).to receive(:portfolio_stream).and_return(responses.to_enum)

      result = []
      service.portfolio_stream(account_ids: ['acc-1'], as: :model) { |payload| result << payload }

      expect(result.size).to eq(1)
      expect(result.first).to be_a(TbankGrpc::Models::Operations::Portfolio)
      expect(result.first.account_id).to eq('acc-1')
    end

    it 'normalizes and trims account ids' do
      allow(stub).to receive(:portfolio_stream).and_return([types::PortfolioStreamResponse.new].to_enum)

      service.portfolio_stream(accounts: ['  acc-1  '], as: :proto)

      expect(stub).to have_received(:portfolio_stream).with(
        have_attributes(accounts: ['acc-1']),
        anything
      )
    end

    it 'validates ping_delay_ms type' do
      expect do
        service.portfolio_stream(account_ids: ['acc-1'], ping_delay_ms: 'abc', as: :proto)
      end.to raise_error(TbankGrpc::InvalidArgumentError, /ping_delay_ms must be an integer/)
    end
  end

  describe '#positions_stream' do
    it 'maps position and initial_positions payloads to models for as: :model' do
      responses = [
        types::PositionsStreamResponse.new(ping: types::Ping.new),
        types::PositionsStreamResponse.new(
          initial_positions: types::PositionsResponse.new(account_id: 'acc-1')
        ),
        types::PositionsStreamResponse.new(
          position: types::PositionData.new(
            account_id: 'acc-1',
            money: [
              types::PositionsMoney.new(
                available_value: types::MoneyValue.new(currency: 'RUB', units: 100),
                blocked_value: types::MoneyValue.new(currency: 'RUB', units: 10)
              )
            ]
          )
        )
      ]
      allow(stub).to receive(:positions_stream).and_return(responses.to_enum)

      result = []
      service.positions_stream(
        account_ids: ['acc-1'],
        with_initial_positions: true,
        as: :model
      ) { |payload| result << payload }

      expect(result.size).to eq(2)
      expect(result[0]).to be_a(TbankGrpc::Models::Operations::Positions)
      expect(result[0].account_id).to eq('acc-1')
      expect(result[1]).to be_a(TbankGrpc::Models::Operations::PositionData)
      expect(result[1].account_id).to eq('acc-1')
      expect(result[1].money.first[:available_value]).to be_a(TbankGrpc::Models::Core::ValueObjects::Money)
    end
  end

  describe '#operations_stream' do
    it 'maps only operation payload to model for as: :model' do
      responses = [
        types::OperationsStreamResponse.new(ping: types::Ping.new),
        types::OperationsStreamResponse.new(
          subscriptions: types::OperationsSubscriptionResult.new(tracking_id: 'tid-1')
        ),
        types::OperationsStreamResponse.new(
          operation: types::OperationData.new(
            id: 'op-1',
            figi: 'BBG123',
            payment: types::MoneyValue.new(currency: 'RUB', units: 100)
          )
        )
      ]
      allow(stub).to receive(:operations_stream).and_return(responses.to_enum)

      result = []
      service.operations_stream(account_ids: ['acc-1'], as: :model) { |payload| result << payload }

      expect(result.size).to eq(1)
      expect(result.first).to be_a(TbankGrpc::Models::Operations::OperationData)
      expect(result.first.id).to eq('op-1')
      expect(result.first.payment.currency).to eq('RUB')
    end
  end

  it 'raises for as: :model without block' do
    allow(stub).to receive(:operations_stream).and_return([types::OperationsStreamResponse.new].to_enum)

    expect do
      service.operations_stream(account_ids: ['acc-1'], as: :model)
    end.to raise_error(TbankGrpc::InvalidArgumentError, /requires block/)
  end

  it 'raises when multiple account sources are provided' do
    expect do
      service.operations_stream(account_ids: ['acc-1'], account_id: 'acc-2')
    end.to raise_error(TbankGrpc::InvalidArgumentError, /Provide only one/)
  end
end
