# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Orders models' do
  before { TbankGrpc::ProtoLoader.require!('orders') }

  let(:types) { TbankGrpc::CONTRACT_V1 }

  it 'maps OrderResponse from PostOrderResponse' do
    proto = types::PostOrderResponse.new(
      order_id: 'ex-1',
      execution_report_status: :EXECUTION_REPORT_STATUS_NEW,
      lots_requested: 2,
      lots_executed: 1,
      order_request_id: 'req-1'
    )

    model = TbankGrpc::Models::Orders::OrderResponse.from_grpc(proto)

    expect(model.order_id).to eq('ex-1')
    expect(model.execution_report_status).to eq(:EXECUTION_REPORT_STATUS_NEW)
    expect(model.lots_requested).to eq(2)
    expect(model.order_request_id).to eq('req-1')
  end

  it 'maps OrderState with stages' do
    stage = types::OrderStage.new(
      quantity: 1,
      trade_id: 't-1',
      execution_time: Google::Protobuf::Timestamp.new(seconds: 1)
    )
    proto = types::OrderState.new(
      order_id: 'ex-2',
      execution_report_status: :EXECUTION_REPORT_STATUS_PARTIALLYFILL,
      stages: [stage]
    )

    model = TbankGrpc::Models::Orders::OrderState.from_grpc(proto)

    expect(model.order_id).to eq('ex-2')
    expect(model.execution_report_status).to eq(:EXECUTION_REPORT_STATUS_PARTIALLYFILL)
    expect(model.stages.size).to eq(1)
    expect(model.stages.first[:trade_id]).to eq('t-1')
  end

  it 'maps OrderPrice with extra sections' do
    proto = types::GetOrderPriceResponse.new(
      lots_requested: 3,
      extra_bond: types::GetOrderPriceResponse::ExtraBond.new(
        nominal_conversion_rate: types::Quotation.new(units: 1, nano: 0)
      ),
      extra_future: types::GetOrderPriceResponse::ExtraFuture.new(
        initial_margin: types::MoneyValue.new(currency: 'RUB', units: 10, nano: 0)
      )
    )

    model = TbankGrpc::Models::Orders::OrderPrice.from_grpc(proto)

    expect(model.lots_requested).to eq(3)
    expect(model.extra_bond).to be_a(Hash)
    expect(model.extra_future).to be_a(Hash)
  end

  it 'maps stream payload models' do
    order_state_proto = types::OrderStateStreamResponse::OrderState.new(
      order_id: 'ex-stream',
      lots_left: 1,
      trades: [
        types::OrderTrade.new(
          trade_id: 'trade-1',
          quantity: 1,
          price: types::Quotation.new(units: 100, nano: 0)
        )
      ]
    )
    trades_proto = types::OrderTrades.new(
      order_id: 'ex-stream',
      trades: [
        types::OrderTrade.new(
          trade_id: 'trade-2',
          quantity: 2,
          price: types::Quotation.new(units: 101, nano: 0)
        )
      ]
    )

    state_model = TbankGrpc::Models::Orders::OrderStreamState.from_grpc(order_state_proto)
    trades_model = TbankGrpc::Models::Orders::OrderTrades.from_grpc(trades_proto)

    expect(state_model.lots_left).to eq(1)
    expect(state_model.trades.first[:trade_id]).to eq('trade-1')
    expect(trades_model.order_id).to eq('ex-stream')
    expect(trades_model.trades.first[:trade_id]).to eq('trade-2')
  end
end
