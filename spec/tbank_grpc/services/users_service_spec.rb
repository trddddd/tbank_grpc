# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::UsersService do
  before do
    TbankGrpc::ProtoLoader.require!('users')
    allow_any_instance_of(described_class).to receive(:initialize_stub).and_return(grpc_stub)
  end

  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:config) { { token: 't', app_name: 'a', sandbox: false } }
  let(:grpc_stub) { instance_double(Tinkoff::Public::Invest::Api::Contract::V1::UsersService::Stub) }
  let(:service) { described_class.new(channel, config) }

  describe '#get_accounts' do
    before do
      allow(grpc_stub).to receive(:get_accounts).and_return(
        Tinkoff::Public::Invest::Api::Contract::V1::GetAccountsResponse.new(accounts: [])
      )
    end

    it 'calls gRPC stub with GetAccountsRequest when no status given' do
      service.get_accounts

      expect(grpc_stub).to have_received(:get_accounts).with(
        be_a(Tinkoff::Public::Invest::Api::Contract::V1::GetAccountsRequest),
        anything
      )
    end

    it 'passes status enum when status is provided' do
      service.get_accounts(status: :open)

      expect(grpc_stub).to have_received(:get_accounts).with(
        have_attributes(status: :ACCOUNT_STATUS_OPEN),
        anything
      )
    end

    it 'returns array of Account models' do
      result = service.get_accounts

      expect(result).to be_an(Array)
    end
  end

  describe '#get_info' do
    before do
      allow(grpc_stub).to receive(:get_info).and_return(
        Tinkoff::Public::Invest::Api::Contract::V1::GetInfoResponse.new(prem_status: false)
      )
    end

    it 'calls gRPC stub get_info with empty request' do
      service.get_info

      expect(grpc_stub).to have_received(:get_info).with(
        be_a(Tinkoff::Public::Invest::Api::Contract::V1::GetInfoRequest),
        anything
      )
    end

    it 'returns UserInfo model' do
      result = service.get_info

      expect(result).to be_a(TbankGrpc::Models::Accounts::UserInfo)
    end
  end

  describe '#get_margin_attributes' do
    before do
      allow(grpc_stub).to receive(:get_margin_attributes).and_return(
        Tinkoff::Public::Invest::Api::Contract::V1::GetMarginAttributesResponse.new
      )
    end

    it 'calls gRPC stub with account_id' do
      service.get_margin_attributes(account_id: 'acc-123')

      expect(grpc_stub).to have_received(:get_margin_attributes).with(
        have_attributes(account_id: 'acc-123'),
        anything
      )
    end

    it 'returns MarginAttributes model' do
      result = service.get_margin_attributes(account_id: 'acc-123')

      expect(result).to be_a(TbankGrpc::Models::Accounts::MarginAttributes)
    end
  end
end
