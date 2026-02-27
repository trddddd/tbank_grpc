# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Responses::ModelMapper do
  subject(:mapper) { described_class.new }

  let(:types) { TbankGrpc::CONTRACT_V1 }

  before { TbankGrpc::ProtoLoader.require!('marketdata') }

  it 'maps candle payload to model' do
    proto = types::Candle.new(instrument_uid: 'uid1')

    model = mapper.map(:candle, proto)

    expect(model).to be_a(TbankGrpc::Models::MarketData::Candle)
    expect(model.instrument_uid).to eq('uid1')
  end

  it 'returns nil for unsupported type' do
    expect(mapper.map(:ping, types::Ping.new)).to be_nil
  end

  it 'extracts first model payload from response' do
    response = types::MarketDataResponse.new(last_price: types::LastPrice.new(instrument_uid: 'uid2'))

    model = mapper.first_model_from_response(response)

    expect(model).to be_a(TbankGrpc::Models::MarketData::LastPrice)
    expect(model.instrument_uid).to eq('uid2')
  end

  it 'returns proto response as-is for format: :proto' do
    response = types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid3'))

    result = mapper.convert_response(response, format: :proto)

    expect(result).to eq(response)
  end

  it 'converts response to model for format: :model' do
    response = types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid3'))

    model = mapper.convert_response(response, format: :model)

    expect(model).to be_a(TbankGrpc::Models::MarketData::Candle)
    expect(model.instrument_uid).to eq('uid3')
  end
end
