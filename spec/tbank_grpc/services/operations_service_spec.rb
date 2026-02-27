# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::OperationsService do
  it 'inherits from Unary::BaseUnaryService' do
    expect(described_class).to be < TbankGrpc::Services::Unary::BaseUnaryService
  end

  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc', sandbox: false } }
  let(:grpc_stub) { instance_double(Tinkoff::Public::Invest::Api::Contract::V1::OperationsService::Stub) }
  let(:service) { described_class.new(channel, config, interceptors: []) }

  before do
    TbankGrpc::ProtoLoader.require!('operations')
    allow_any_instance_of(described_class).to receive(:initialize_stub).and_return(grpc_stub)
  end

  describe 'instance interface' do
    %i[get_portfolio get_positions get_operations get_operations_by_cursor].each do |method_name|
      it "responds to ##{method_name}" do
        expect(service).to respond_to(method_name)
      end
    end
  end

  describe '#get_portfolio' do
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::PortfolioResponse.new(
        account_id: 'acc-1'
      )
    end

    before { allow(grpc_stub).to receive(:get_portfolio).and_return(response) }

    it 'calls stub with PortfolioRequest (account_id)' do
      service.get_portfolio(account_id: 'acc-1')

      expect(grpc_stub).to have_received(:get_portfolio).with(
        have_attributes(account_id: 'acc-1'),
        anything
      )
    end

    it 'passes currency when given' do
      service.get_portfolio(account_id: 'acc-1', currency: :rub)

      expect(grpc_stub).to have_received(:get_portfolio).with(
        have_attributes(account_id: 'acc-1', currency: :RUB),
        anything
      )
    end

    it 'returns Portfolio model' do
      result = service.get_portfolio(account_id: 'acc-1')

      expect(result).to be_a(TbankGrpc::Models::Operations::Portfolio)
      expect(result.account_id).to eq('acc-1')
    end
  end

  describe '#get_positions' do
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::PositionsResponse.new(
        account_id: 'acc-1',
        limits_loading_in_progress: false
      )
    end

    before { allow(grpc_stub).to receive(:get_positions).and_return(response) }

    it 'calls stub with PositionsRequest' do
      service.get_positions(account_id: 'acc-1')

      expect(grpc_stub).to have_received(:get_positions).with(
        have_attributes(account_id: 'acc-1'),
        anything
      )
    end

    it 'returns Positions model' do
      result = service.get_positions(account_id: 'acc-1')

      expect(result).to be_a(TbankGrpc::Models::Operations::Positions)
      expect(result.account_id).to eq('acc-1')
    end
  end

  describe '#get_operations' do
    let(:proto_operation) do
      Tinkoff::Public::Invest::Api::Contract::V1::Operation.new(
        id: 'op-1',
        type: 'Покупка ЦБ',
        state: :OPERATION_STATE_EXECUTED,
        figi: 'BBG123'
      )
    end
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::OperationsResponse.new(operations: [])
    end
    let(:response_with_ops) do
      Tinkoff::Public::Invest::Api::Contract::V1::OperationsResponse.new(operations: [proto_operation])
    end

    before { allow(grpc_stub).to receive(:get_operations).and_return(response) }

    it 'calls stub with OperationsRequest (account_id, from, to)' do
      from = Time.utc(2024, 1, 1)
      to = Time.utc(2024, 1, 31)
      captured_req = nil
      allow(grpc_stub).to receive(:get_operations) do |req, *_|
        captured_req = req
        response
      end
      service.get_operations(account_id: 'acc-1', from: from, to: to)

      expect(captured_req.account_id).to eq('acc-1')
      expect(captured_req.from).to be_a(Google::Protobuf::Timestamp)
      expect(captured_req.to).to be_a(Google::Protobuf::Timestamp)
    end

    it 'returns Array of Operation models' do
      result = service.get_operations(account_id: 'acc-1', from: Time.now - 86_400, to: Time.now)

      expect(result).to be_an(Array)
      expect(result).to eq([])
      expect(result.first).to be_nil
    end

    it 'maps operations to Operation models' do
      allow(grpc_stub).to receive(:get_operations).and_return(response_with_ops)

      result = service.get_operations(account_id: 'acc-1', from: Time.now - 86_400, to: Time.now)

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first).to be_a(TbankGrpc::Models::Operations::Operation)
      expect(result.first.id).to eq('op-1')
      expect(result[0].figi).to eq('BBG123')
    end

    it 'passes state and figi when given' do
      captured_req = nil
      allow(grpc_stub).to receive(:get_operations) { |req, *_|
        captured_req = req
        response
      }
      service.get_operations(account_id: 'acc-1', from: Time.now - 86_400, to: Time.now, state: :executed,
                             figi: 'BBG123')

      expect(captured_req.account_id).to eq('acc-1')
      expect(captured_req.state).to eq(:OPERATION_STATE_EXECUTED)
      expect(captured_req.figi).to eq('BBG123')
    end

    it 'returns Response with data (proto) and metadata when return_metadata: true' do
      op_double = double(execute: response, metadata: {}, trailing_metadata: {})
      allow(grpc_stub).to receive(:get_operations) do |*_args, **opts|
        opts[:return_op] ? op_double : response
      end

      result = service.get_operations(
        account_id: 'acc-1',
        from: Time.now - 86_400,
        to: Time.now,
        return_metadata: true
      )

      expect(result).to be_a(TbankGrpc::Response)
      expect(result.data).to eq(response)
      expect(result.metadata).to be_a(Hash)
    end
  end

  describe '#get_operations_by_cursor' do
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::GetOperationsByCursorResponse.new(
        has_next: false,
        items: []
      )
    end

    before { allow(grpc_stub).to receive(:get_operations_by_cursor).and_return(response) }

    it 'calls stub with GetOperationsByCursorRequest' do
      service.get_operations_by_cursor(account_id: 'acc-1')

      expect(grpc_stub).to have_received(:get_operations_by_cursor).with(
        have_attributes(account_id: 'acc-1'),
        anything
      )
    end

    it 'passes cursor and limit when given' do
      service.get_operations_by_cursor(account_id: 'acc-1', cursor: 'cur1', limit: 50)

      expect(grpc_stub).to have_received(:get_operations_by_cursor).with(
        have_attributes(account_id: 'acc-1', cursor: 'cur1', limit: 50),
        anything
      )
    end

    it 'returns GetOperationsByCursorResponse (proto)' do
      result = service.get_operations_by_cursor(account_id: 'acc-1')

      expect(result).to eq(response)
    end

    it 'returns Response with data and metadata when return_metadata: true' do
      op_double = double(execute: response, metadata: {}, trailing_metadata: {})
      allow(grpc_stub).to receive(:get_operations_by_cursor) do |*_args, **opts|
        opts[:return_op] ? op_double : response
      end

      result = service.get_operations_by_cursor(account_id: 'acc-1', return_metadata: true)

      expect(result).to be_a(TbankGrpc::Response)
      expect(result.data).to eq(response)
      expect(result.metadata).to be_a(Hash)
    end
  end
end
