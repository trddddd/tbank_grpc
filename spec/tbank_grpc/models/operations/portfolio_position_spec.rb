# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Operations::PortfolioPosition do
  before { TbankGrpc::ProtoLoader.require!('operations') }

  let(:proto_class) { TbankGrpc::CONTRACT_V1::PortfolioPosition }
  let(:money_proto) do
    TbankGrpc::CONTRACT_V1::MoneyValue.new(
      currency: 'RUB', units: 250, nano: 100_000_000
    )
  end
  let(:quotation_proto) do
    TbankGrpc::CONTRACT_V1::Quotation.new(units: 10, nano: 500_000_000)
  end

  let(:proto) do
    proto_class.new(
      figi: 'BBG004730N88',
      instrument_type: 'share',
      quantity: quotation_proto,
      average_position_price: money_proto,
      current_price: money_proto,
      position_uid: 'pos-uid-1',
      instrument_uid: 'inst-uid-1',
      ticker: 'SBER',
      class_code: 'TQBR',
      blocked: false
    )
  end

  describe '.from_grpc' do
    it 'returns PortfolioPosition with attributes from proto' do
      model = described_class.from_grpc(proto)

      expect(model).to be_a(described_class)
      expect(model.figi).to eq('BBG004730N88')
      expect(model.instrument_type).to eq('share')
      expect(model.position_uid).to eq('pos-uid-1')
      expect(model.instrument_uid).to eq('inst-uid-1')
      expect(model.ticker).to eq('SBER')
      expect(model.class_code).to eq('TQBR')
      expect(model.blocked).to be(false)
    end

    it 'maps quantity and money fields via value objects' do
      model = described_class.from_grpc(proto)

      expect(model.quantity).to be_a(TbankGrpc::Models::Core::ValueObjects::Quotation)
      expect(model.quantity&.to_f).to eq(10.5)
      expect(model.average_position_price).to be_a(TbankGrpc::Models::Core::ValueObjects::Money)
      expect(model.current_price&.to_f).to eq(250.1)
    end
  end

  describe '#inspect' do
    it 'includes figi and instrument_type' do
      model = described_class.from_grpc(proto)
      expect(model.inspect).to include('BBG004730N88', 'share')
    end
  end
end
