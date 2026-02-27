# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::ServerSide::RequestBuilder do
  subject(:builder) { described_class.new }

  let(:types) { TbankGrpc::CONTRACT_V1 }

  before { TbankGrpc::ProtoLoader.require!('marketdata') }

  it 'builds request with candle subscriptions' do
    request = builder.build(candles: [{ instrument_id: 'uid1', interval: :CANDLE_INTERVAL_1_MIN }])

    expect(request.subscribe_candles_request.instruments.first.instrument_id).to eq('uid1')
  end

  it 'rejects mixed trade_source in one request' do
    expect do
      builder.build(
        trades: [
          { instrument_id: 'uid1', trade_source: :TRADE_SOURCE_ALL },
          { instrument_id: 'uid2', trade_source: :TRADE_SOURCE_EXCHANGE }
        ]
      )
    end.to raise_error(TbankGrpc::InvalidArgumentError, /Mixed values for trade_source/)
  end
end
