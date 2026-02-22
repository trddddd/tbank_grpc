# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Responses::EventRouter do
  let(:event_loop) { instance_double(TbankGrpc::Streaming::Core::Dispatch::EventLoop) }
  let(:model_mapper) { instance_double(TbankGrpc::Streaming::MarketData::Responses::ModelMapper) }
  let(:router) { described_class.new(event_loop: event_loop, model_mapper: model_mapper) }
  let(:types) { Tinkoff::Public::Invest::Api::Contract::V1 }

  before do
    TbankGrpc::ProtoLoader.require!('marketdata')
    allow(model_mapper).to receive(:map)
  end

  it 'emits proto-only event without model conversion when model payload is not needed' do
    response = types::MarketDataResponse.new(candle: types::Candle.new(instrument_uid: 'uid1'))
    allow(event_loop).to receive(:needs_model_payload?).with(:candle).and_return(false)
    allow(event_loop).to receive(:emit)

    router.dispatch(response)

    expect(model_mapper).not_to have_received(:map)
    expect(event_loop).to have_received(:emit).with(:candle, proto_payload: response.candle, model_payload: nil)
  end

  it 'emits subscription status payload with response type' do
    payload = types::SubscribeOrderBookResponse.new(tracking_id: 't1')
    response = types::MarketDataResponse.new(subscribe_order_book_response: payload)
    allow(event_loop).to receive(:needs_model_payload?).and_return(false)
    allow(event_loop).to receive(:emit)

    router.dispatch(response)

    expect(event_loop).to have_received(:emit).with(
      :subscription_status,
      proto_payload: { type: :orderbook, response: payload },
      model_payload: nil
    )
  end
end
