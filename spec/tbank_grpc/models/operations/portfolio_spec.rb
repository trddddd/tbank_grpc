# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Operations::Portfolio do
  before { TbankGrpc::ProtoLoader.require!('operations') }

  let(:position_proto) do
    Tinkoff::Public::Invest::Api::Contract::V1::PortfolioPosition.new(
      figi: 'BBG004730N88',
      instrument_type: 'share',
      ticker: 'SBER',
      position_uid: 'pos-1',
      instrument_uid: 'inst-1'
    )
  end
  let(:portfolio_proto) do
    Tinkoff::Public::Invest::Api::Contract::V1::PortfolioResponse.new(
      account_id: 'acc-1',
      positions: [position_proto]
    )
  end

  describe '.from_grpc' do
    it 'returns Portfolio with account_id' do
      model = described_class.from_grpc(portfolio_proto)

      expect(model).to be_a(described_class)
      expect(model.account_id).to eq('acc-1')
    end

    it 'maps positions to Array of PortfolioPosition' do
      model = described_class.from_grpc(portfolio_proto)

      expect(model.positions).to be_an(Array)
      expect(model.positions.size).to eq(1)
      expect(model.positions.first).to be_a(TbankGrpc::Models::Operations::PortfolioPosition)
      expect(model.positions.first.figi).to eq('BBG004730N88')
      expect(model.positions.first.ticker).to eq('SBER')
    end

    it 'returns empty positions for proto without positions' do
      empty_proto = Tinkoff::Public::Invest::Api::Contract::V1::PortfolioResponse.new(account_id: 'acc-1')
      model = described_class.from_grpc(empty_proto)

      expect(model.positions).to eq([])
    end

    it 'maps virtual_positions to array of hashes with expected keys' do
      vp_proto = Tinkoff::Public::Invest::Api::Contract::V1::VirtualPortfolioPosition.new(
        position_uid: 'vp-1',
        instrument_uid: 'inst-1',
        figi: 'BBG004730N88',
        instrument_type: 'share',
        ticker: 'SBER',
        class_code: 'TQBR'
      )
      proto_with_vp = Tinkoff::Public::Invest::Api::Contract::V1::PortfolioResponse.new(
        account_id: 'acc-1',
        virtual_positions: [vp_proto]
      )
      model = described_class.from_grpc(proto_with_vp)

      expect(model.virtual_positions).to be_an(Array)
      expect(model.virtual_positions.size).to eq(1)
      expect(model.virtual_positions.first).to be_a(Hash)
      expect(model.virtual_positions.first).to include(
        position_uid: 'vp-1',
        instrument_uid: 'inst-1',
        figi: 'BBG004730N88',
        instrument_type: 'share',
        ticker: 'SBER',
        class_code: 'TQBR'
      )
    end
  end

  describe '#total' do
    it 'returns total_amount_portfolio as Float when set' do
      money = Tinkoff::Public::Invest::Api::Contract::V1::MoneyValue.new(currency: 'RUB', units: 100_000, nano: 0)
      proto = Tinkoff::Public::Invest::Api::Contract::V1::PortfolioResponse.new(
        account_id: 'acc-1',
        total_amount_portfolio: money
      )
      model = described_class.from_grpc(proto)

      expect(model.total).to eq(100_000.0)
    end
  end
end
