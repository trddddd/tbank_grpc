# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::OrdersService do
  it 'inherits from Unary::BaseUnaryService' do
    expect(described_class).to be < TbankGrpc::Services::Unary::BaseUnaryService
  end

  let(:channel) { instance_double(GRPC::Core::Channel) }
  let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc', sandbox: false } }
  let(:grpc_stub) { instance_double(Tinkoff::Public::Invest::Api::Contract::V1::OrdersService::Stub) }
  let(:service) { described_class.new(channel, config, interceptors: []) }

  before do
    TbankGrpc::ProtoLoader.require!('orders')
    allow_any_instance_of(described_class).to receive(:initialize_stub).and_return(grpc_stub)
  end

  describe 'instance interface' do
    %i[
      post_order
      post_order_async
      cancel_order
      get_order_state
      get_order_state_by_request_id
      cancel_order_by_request_id
      get_orders
      replace_order
      get_max_lots
      get_order_price
    ].each do |method_name|
      it "responds to ##{method_name}" do
        expect(service).to respond_to(method_name)
      end
    end
  end

  describe '#post_order' do
    let(:response) { Tinkoff::Public::Invest::Api::Contract::V1::PostOrderResponse.new(order_id: 'ex-1') }

    before { allow(grpc_stub).to receive(:post_order).and_return(response) }

    it 'builds PostOrderRequest with enums and normalized ids' do
      result = service.post_order(
        instrument_id: ' BBG000B9XRY4 ',
        quantity: 2,
        price: 123.45,
        direction: :buy,
        account_id: ' acc-1 ',
        order_type: :limit,
        order_request_id: '11111111-1111-1111-1111-111111111111'
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::OrderResponse)
      expect(grpc_stub).to have_received(:post_order).with(
        have_attributes(
          instrument_id: 'BBG000B9XRY4',
          quantity: 2,
          direction: :ORDER_DIRECTION_BUY,
          account_id: 'acc-1',
          order_type: :ORDER_TYPE_LIMIT,
          order_id: '11111111-1111-1111-1111-111111111111'
        ),
        anything
      )
    end

    it 'supports deprecated figi alias for instrument_id' do
      service.post_order(
        figi: 'BBG000B9XRY4',
        quantity: 1,
        direction: :buy,
        account_id: 'acc-1',
        order_type: :market,
        order_id: '22222222-2222-2222-2222-222222222222'
      )

      expect(grpc_stub).to have_received(:post_order).with(
        have_attributes(instrument_id: 'BBG000B9XRY4'),
        anything
      )
    end

    it 'returns Response wrapper when return_metadata: true' do
      op_double = double(execute: response, metadata: {}, trailing_metadata: {})
      allow(grpc_stub).to receive(:post_order) { |*_args, **opts| opts[:return_op] ? op_double : response }

      result = service.post_order(
        instrument_id: 'BBG000B9XRY4',
        quantity: 1,
        direction: :buy,
        account_id: 'acc-1',
        order_type: :market,
        order_id: '33333333-3333-3333-3333-333333333333',
        return_metadata: true
      )

      expect(result).to be_a(TbankGrpc::Response)
      expect(result.data).to eq(response)
      expect(result.metadata).to be_a(Hash)
    end

    it 'validates idempotency key length' do
      expect do
        service.post_order(
          instrument_id: 'BBG000B9XRY4',
          quantity: 1,
          direction: :buy,
          account_id: 'acc-1',
          order_type: :market,
          order_id: 'a' * 37
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /at most 36/)
    end
  end

  describe '#post_order_async' do
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::PostOrderAsyncResponse.new(
        order_request_id: '44444444-4444-4444-4444-444444444444'
      )
    end

    before { allow(grpc_stub).to receive(:post_order_async).and_return(response) }

    it 'sends PostOrderAsyncRequest with optional fields' do
      result = service.post_order_async(
        instrument_id: 'BBG000B9XRY4',
        quantity: 10,
        price: 100.01,
        direction: :ORDER_DIRECTION_SELL,
        account_id: 'acc-1',
        order_type: :ORDER_TYPE_LIMIT,
        order_id: '44444444-4444-4444-4444-444444444444',
        time_in_force: :fill_or_kill,
        price_type: :price_type_point
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::OrderAsyncResponse)
      expect(grpc_stub).to have_received(:post_order_async).with(
        have_attributes(
          instrument_id: 'BBG000B9XRY4',
          quantity: 10,
          direction: :ORDER_DIRECTION_SELL,
          order_type: :ORDER_TYPE_LIMIT,
          order_id: '44444444-4444-4444-4444-444444444444',
          time_in_force: :TIME_IN_FORCE_FILL_OR_KILL,
          price_type: :PRICE_TYPE_POINT
        ),
        anything
      )
    end
  end

  describe '#cancel_order / #get_order_state wrappers for request id' do
    let(:cancel_response) { Tinkoff::Public::Invest::Api::Contract::V1::CancelOrderResponse.new }
    let(:state_response) { Tinkoff::Public::Invest::Api::Contract::V1::OrderState.new(order_id: 'ex-1') }

    before do
      allow(grpc_stub).to receive(:cancel_order).and_return(cancel_response)
      allow(grpc_stub).to receive(:get_order_state).and_return(state_response)
    end

    it 'sets ORDER_ID_TYPE_REQUEST when cancelling by request id' do
      result = service.cancel_order_by_request_id(
        account_id: 'acc-1',
        order_request_id: '55555555-5555-5555-5555-555555555555'
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::CancelOrderResponse)
      expect(grpc_stub).to have_received(:cancel_order).with(
        have_attributes(
          order_id: '55555555-5555-5555-5555-555555555555',
          order_id_type: :ORDER_ID_TYPE_REQUEST
        ),
        anything
      )
    end

    it 'sets ORDER_ID_TYPE_REQUEST when requesting state by request id' do
      result = service.get_order_state_by_request_id(
        account_id: 'acc-1',
        order_request_id: '66666666-6666-6666-6666-666666666666'
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::OrderState)
      expect(grpc_stub).to have_received(:get_order_state).with(
        have_attributes(
          order_id: '66666666-6666-6666-6666-666666666666',
          order_id_type: :ORDER_ID_TYPE_REQUEST
        ),
        anything
      )
    end
  end

  describe '#get_orders' do
    let(:state) { Tinkoff::Public::Invest::Api::Contract::V1::OrderState.new(order_id: 'ex-2') }
    let(:response) { Tinkoff::Public::Invest::Api::Contract::V1::GetOrdersResponse.new(orders: [state]) }

    before { allow(grpc_stub).to receive(:get_orders).and_return(response) }

    it 'passes advanced filters and returns proto orders array' do
      from = Time.utc(2026, 2, 27, 10, 0, 0)
      to = Time.utc(2026, 2, 27, 12, 0, 0)
      result = service.get_orders(
        account_id: 'acc-1',
        from: from,
        to: to,
        execution_status: %i[new partially_fill]
      )

      expect(result).to be_an(Array)
      expect(result.first).to be_a(TbankGrpc::Models::Orders::OrderState)
      expect(result.first.order_id).to eq('ex-2')
      expect(grpc_stub).to have_received(:get_orders).with(
        have_attributes(
          account_id: 'acc-1',
          advanced_filters: have_attributes(
            execution_status: %i[EXECUTION_REPORT_STATUS_NEW EXECUTION_REPORT_STATUS_PARTIALLYFILL]
          )
        ),
        anything
      )
    end
  end

  describe '#replace_order' do
    let(:response) { Tinkoff::Public::Invest::Api::Contract::V1::PostOrderResponse.new(order_id: 'ex-3') }

    before { allow(grpc_stub).to receive(:replace_order).and_return(response) }

    it 'sends ReplaceOrderRequest with required fields and optional price_type' do
      result = service.replace_order(
        account_id: 'acc-1',
        order_id: 'ex-1',
        idempotency_key: '77777777-7777-7777-7777-777777777777',
        quantity: 3,
        price: 102.5,
        price_type: :price_type_currency,
        confirm_margin_trade: true
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::OrderResponse)
      expect(grpc_stub).to have_received(:replace_order).with(
        have_attributes(
          account_id: 'acc-1',
          order_id: 'ex-1',
          idempotency_key: '77777777-7777-7777-7777-777777777777',
          quantity: 3,
          price_type: :PRICE_TYPE_CURRENCY,
          confirm_margin_trade: true
        ),
        anything
      )
    end
  end

  describe '#get_max_lots' do
    let(:response) do
      Tinkoff::Public::Invest::Api::Contract::V1::GetMaxLotsResponse.new(
        currency: 'rub',
        buy_limits: Tinkoff::Public::Invest::Api::Contract::V1::GetMaxLotsResponse::BuyLimitsView.new(
          buy_max_lots: 3180,
          buy_max_market_lots: 3000
        ),
        sell_limits: Tinkoff::Public::Invest::Api::Contract::V1::GetMaxLotsResponse::SellLimitsView.new(
          sell_max_lots: 12
        )
      )
    end

    before { allow(grpc_stub).to receive(:get_max_lots).and_return(response) }

    it 'calls gRPC with account_id and instrument_id and returns max lots model' do
      result = service.get_max_lots(account_id: 'acc-1', instrument_id: 'BBG000B9XRY4')

      expect(result).to be_a(TbankGrpc::Models::Orders::MaxLots)
      expect(result.currency).to eq('rub')
      expect(result.buy_available_lots).to eq(3180)
      expect(result.sell_available_lots).to eq(12)
      expect(grpc_stub).to have_received(:get_max_lots).with(
        have_attributes(account_id: 'acc-1', instrument_id: 'BBG000B9XRY4'),
        anything
      )
    end
  end

  describe '#get_order_price' do
    let(:response) { Tinkoff::Public::Invest::Api::Contract::V1::GetOrderPriceResponse.new(lots_requested: 1) }

    before { allow(grpc_stub).to receive(:get_order_price).and_return(response) }

    it 'requires price for limit order pre-check' do
      expect do
        service.get_order_price(
          account_id: 'acc-1',
          instrument_id: 'BBG000B9XRY4',
          price: nil,
          direction: :buy,
          quantity: 1
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /price is required/)
    end

    it 'maps direction enum and quantity' do
      result = service.get_order_price(
        account_id: 'acc-1',
        instrument_id: 'BBG000B9XRY4',
        price: 100.5,
        direction: :sell,
        quantity: '2'
      )

      expect(result).to be_a(TbankGrpc::Models::Orders::OrderPrice)
      expect(result.lots_requested).to eq(1)
      expect(grpc_stub).to have_received(:get_order_price).with(
        have_attributes(
          account_id: 'acc-1',
          instrument_id: 'BBG000B9XRY4',
          direction: :ORDER_DIRECTION_SELL,
          quantity: 2
        ),
        anything
      )
    end
  end
end
