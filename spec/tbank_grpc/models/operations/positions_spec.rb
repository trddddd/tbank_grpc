# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Operations::Positions do
  before { TbankGrpc::ProtoLoader.require!('operations') }

  let(:money_proto) do
    TbankGrpc::CONTRACT_V1::MoneyValue.new(currency: 'RUB', units: 50_000, nano: 0)
  end
  let(:proto) do
    TbankGrpc::CONTRACT_V1::PositionsResponse.new(
      account_id: 'acc-1',
      limits_loading_in_progress: false,
      money: [money_proto]
    )
  end

  describe '.from_grpc' do
    it 'returns Positions with account_id' do
      model = described_class.from_grpc(proto)

      expect(model).to be_a(described_class)
      expect(model.account_id).to eq('acc-1')
      expect(model.limits_loading_in_progress).to be(false)
    end

    it 'maps money to Array of Money value objects' do
      model = described_class.from_grpc(proto)

      expect(model.money).to be_an(Array)
      expect(model.money.size).to eq(1)
      expect(model.money.first).to be_a(TbankGrpc::Models::Core::ValueObjects::Money)
      expect(model.money.first.currency).to eq('RUB')
      expect(model.money.first.to_f).to eq(50_000.0)
    end

    it 'money_by_currency returns hash currency => Money' do
      model = described_class.from_grpc(proto)

      expect(model.money_by_currency).to be_a(Hash)
      expect(model.money_by_currency['RUB']).to be_a(TbankGrpc::Models::Core::ValueObjects::Money)
    end

    it 'blocked returns array of Money (empty when not set)' do
      model = described_class.from_grpc(proto)

      expect(model.blocked).to be_an(Array)
      expect(model.blocked).to eq([])
    end

    it 'securities returns array of hashes (empty when not set)' do
      model = described_class.from_grpc(proto)

      expect(model.securities).to be_an(Array)
      expect(model.securities).to eq([])
    end

    it 'futures returns array of hashes (empty when not set)' do
      model = described_class.from_grpc(proto)

      expect(model.futures).to be_an(Array)
      expect(model.futures).to eq([])
    end

    it 'options returns array of hashes (empty when not set)' do
      model = described_class.from_grpc(proto)

      expect(model.options).to be_an(Array)
      expect(model.options).to eq([])
    end
  end
end
