# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Orders::MaxLots do
  before { TbankGrpc::ProtoLoader.require!('orders') }

  let(:buy_limits_proto) do
    TbankGrpc::CONTRACT_V1::GetMaxLotsResponse::BuyLimitsView.new(
      buy_money_amount: TbankGrpc::CONTRACT_V1::Quotation.new(units: 1_000_000, nano: 0),
      buy_max_lots: 3180,
      buy_max_market_lots: 3000
    )
  end

  let(:buy_margin_limits_proto) do
    TbankGrpc::CONTRACT_V1::GetMaxLotsResponse::BuyLimitsView.new(
      buy_money_amount: TbankGrpc::CONTRACT_V1::Quotation.new(units: 2_000_000, nano: 0),
      buy_max_lots: 4000,
      buy_max_market_lots: 3500
    )
  end

  let(:sell_limits_proto) do
    TbankGrpc::CONTRACT_V1::GetMaxLotsResponse::SellLimitsView.new(sell_max_lots: 5)
  end

  let(:sell_margin_limits_proto) do
    TbankGrpc::CONTRACT_V1::GetMaxLotsResponse::SellLimitsView.new(sell_max_lots: 12)
  end

  let(:proto) do
    TbankGrpc::CONTRACT_V1::GetMaxLotsResponse.new(
      currency: 'rub',
      buy_limits: buy_limits_proto,
      buy_margin_limits: buy_margin_limits_proto,
      sell_limits: sell_limits_proto,
      sell_margin_limits: sell_margin_limits_proto
    )
  end

  describe '.from_grpc' do
    it 'maps max lots fields and nested views' do
      model = described_class.from_grpc(proto)

      expect(model).to be_a(described_class)
      expect(model.currency).to eq('rub')
      expect(model.buy_limits).to be_a(TbankGrpc::Models::Orders::MaxLots::BuyLimitsView)
      expect(model.sell_limits).to be_a(TbankGrpc::Models::Orders::MaxLots::SellLimitsView)
      expect(model.buy_available_lots).to eq(3180)
      expect(model.buy_available_market_lots).to eq(3000)
      expect(model.buy_available_margin_lots).to eq(4000)
      expect(model.buy_available_margin_market_lots).to eq(3500)
      expect(model.sell_available_lots).to eq(5)
      expect(model.sell_available_margin_lots).to eq(12)
    end

    it 'provides compatibility aliases for *_limits_response methods' do
      model = described_class.from_grpc(proto)

      expect(model.buy_limits_response).to eq(model.buy_limits)
      expect(model.sell_limits_response).to eq(model.sell_limits)
      expect(model.buy_margin_limits_response).to eq(model.buy_margin_limits)
      expect(model.sell_margin_limits_response).to eq(model.sell_margin_limits)
    end
  end
end
