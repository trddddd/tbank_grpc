# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Subscriptions::RequestFactory do
  subject(:factory) { described_class.new }

  let(:types) { Tinkoff::Public::Invest::Api::Contract::V1 }

  before { TbankGrpc::ProtoLoader.require!('marketdata') }

  it 'builds orderbook subscribe request' do
    request = factory.subscription_request(
      :orderbook,
      { instrument_id: 'uid1', depth: 20, order_book_type: types::OrderBookType::ORDERBOOK_TYPE_ALL },
      :SUBSCRIPTION_ACTION_SUBSCRIBE
    )

    expect(request.subscribe_order_book_request.instruments.first.instrument_id).to eq('uid1')
  end

  it 'validates ping delay range' do
    expect { factory.normalize_ping_delay(4000) }
      .to raise_error(TbankGrpc::InvalidArgumentError, /5000\.\.180000/)
  end

  it 'raises for unknown subscription type' do
    expect do
      factory.subscription_request(:unknown, {}, :SUBSCRIPTION_ACTION_SUBSCRIBE)
    end.to raise_error(TbankGrpc::InvalidArgumentError, /Unknown subscription type/)
  end
end
