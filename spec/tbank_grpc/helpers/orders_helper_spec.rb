# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Helpers::OrdersHelper do
  let(:client) { instance_double(TbankGrpc::Client) }
  let(:orders_service) { instance_double(TbankGrpc::Services::OrdersService) }
  let(:helper) { described_class.new(client) }

  before { allow(client).to receive(:orders).and_return(orders_service) }

  describe '#buy_market' do
    let(:response) { double('PostOrderResponse') }

    before do
      allow(orders_service).to receive(:post_order).and_return(response)
    end

    it 'calls post_order with buy and market type' do
      helper.buy_market(
        instrument_id: 'BBG000B9XRY4',
        quantity: 1,
        account_id: 'acc-1'
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(
          instrument_id: 'BBG000B9XRY4',
          quantity: 1,
          direction: :ORDER_DIRECTION_BUY,
          account_id: 'acc-1',
          order_type: :ORDER_TYPE_MARKET,
          return_metadata: false
        )
      )
    end

    it 'generates order_id when not provided' do
      helper.buy_market(instrument_id: 'FIGI', quantity: 1, account_id: 'acc-1')

      expect(orders_service).to have_received(:post_order).with(
        hash_including(order_id: a_string_matching(/\A[0-9a-f-]{36}\z/))
      )
    end

    it 'generates order_id when order_id is empty string' do
      helper.buy_market(instrument_id: 'FIGI', quantity: 1, account_id: 'acc-1', order_id: '')

      expect(orders_service).to have_received(:post_order).with(
        hash_including(order_id: a_string_matching(/\A[0-9a-f-]{36}\z/))
      )
    end

    it 'uses given order_id when provided' do
      helper.buy_market(
        instrument_id: 'FIGI',
        quantity: 1,
        account_id: 'acc-1',
        order_id: 'my-idempotency-key'
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(order_id: 'my-idempotency-key')
      )
    end

    it 'forwards return_metadata to post_order' do
      helper.buy_market(
        instrument_id: 'FIGI',
        quantity: 1,
        account_id: 'acc-1',
        return_metadata: true
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(return_metadata: true)
      )
    end
  end

  describe '#sell_market' do
    let(:response) { double('PostOrderResponse') }

    before { allow(orders_service).to receive(:post_order).and_return(response) }

    it 'calls post_order with sell and market type' do
      helper.sell_market(
        instrument_id: 'BBG000B9XRY4',
        quantity: 2,
        account_id: 'acc-1'
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(
          instrument_id: 'BBG000B9XRY4',
          quantity: 2,
          direction: :ORDER_DIRECTION_SELL,
          account_id: 'acc-1',
          order_type: :ORDER_TYPE_MARKET
        )
      )
    end

    it 'generates order_id when not provided' do
      helper.sell_market(instrument_id: 'FIGI', quantity: 1, account_id: 'acc-1')

      expect(orders_service).to have_received(:post_order).with(
        hash_including(order_id: a_string_matching(/\A[0-9a-f-]{36}\z/))
      )
    end
  end

  describe '#buy_limit' do
    let(:response) { double('PostOrderResponse') }

    before { allow(orders_service).to receive(:post_order).and_return(response) }

    it 'calls post_order with buy, limit type and price' do
      helper.buy_limit(
        instrument_id: 'FIGI',
        quantity: 1,
        price: 100.5,
        account_id: 'acc-1'
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(
          instrument_id: 'FIGI',
          quantity: 1,
          price: 100.5,
          direction: :ORDER_DIRECTION_BUY,
          account_id: 'acc-1',
          order_type: :ORDER_TYPE_LIMIT,
          time_in_force: nil,
          price_type: nil
        )
      )
    end

    it 'forwards time_in_force and price_type' do
      helper.buy_limit(
        instrument_id: 'FIGI',
        quantity: 1,
        price: 100,
        account_id: 'acc-1',
        time_in_force: :TIME_IN_FORCE_DAY,
        price_type: :PRICE_TYPE_CURRENCY
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(time_in_force: :TIME_IN_FORCE_DAY, price_type: :PRICE_TYPE_CURRENCY)
      )
    end
  end

  describe '#sell_limit' do
    let(:response) { double('PostOrderResponse') }

    before { allow(orders_service).to receive(:post_order).and_return(response) }

    it 'calls post_order with sell, limit type and price' do
      helper.sell_limit(
        instrument_id: 'FIGI',
        quantity: 1,
        price: 200,
        account_id: 'acc-1'
      )

      expect(orders_service).to have_received(:post_order).with(
        hash_including(
          direction: :ORDER_DIRECTION_SELL,
          order_type: :ORDER_TYPE_LIMIT,
          price: 200
        )
      )
    end
  end

  describe '#buy_sliced' do
    let(:response) { double('PostOrderResponse') }

    it 'splits quantity into parts and calls post_order for each' do
      quantities = []
      allow(orders_service).to receive(:post_order) do |args|
        quantities << args[:quantity]
        response
      end

      helper.buy_sliced(
        instrument_id: 'FIGI',
        quantity: 10,
        account_id: 'acc-1',
        parts: 3
      )

      expect(quantities.size).to eq(3)
      expect(quantities.sum).to eq(10)
    end

    it 'uses ORDER_TYPE_MARKET and ORDER_DIRECTION_BUY for each part' do
      allow(orders_service).to receive(:post_order).and_return(response)
      helper.buy_sliced(instrument_id: 'FIGI', quantity: 6, account_id: 'acc-1', parts: 2)

      expect(orders_service).to have_received(:post_order).with(
        hash_including(
          instrument_id: 'FIGI',
          direction: :ORDER_DIRECTION_BUY,
          order_type: :ORDER_TYPE_MARKET,
          account_id: 'acc-1'
        )
      ).at_least(:twice)
    end
  end

  describe '#sell_sliced' do
    let(:response) { double('PostOrderResponse') }

    before { allow(orders_service).to receive(:post_order).and_return(response) }

    it 'splits quantity into parts with sell direction' do
      helper.sell_sliced(
        instrument_id: 'FIGI',
        quantity: 4,
        account_id: 'acc-1',
        parts: 2
      )

      expect(orders_service).to have_received(:post_order).exactly(2).times
      expect(orders_service).to have_received(:post_order).with(
        hash_including(direction: :ORDER_DIRECTION_SELL, order_type: :ORDER_TYPE_MARKET)
      ).at_least(:twice)
    end
  end

  describe '#cancel' do
    before { allow(orders_service).to receive(:cancel_order).and_return(true) }

    it 'delegates to orders.cancel_order with order_id' do
      helper.cancel(account_id: 'acc-1', order_id: 'ord-1')

      expect(orders_service).to have_received(:cancel_order).with(
        account_id: 'acc-1',
        order_id: 'ord-1',
        order_request_id: nil,
        return_metadata: false
      )
    end

    it 'forwards order_request_id and return_metadata' do
      helper.cancel(
        account_id: 'acc-1',
        order_request_id: 'req-123',
        return_metadata: true
      )

      expect(orders_service).to have_received(:cancel_order).with(
        account_id: 'acc-1',
        order_id: nil,
        order_request_id: 'req-123',
        return_metadata: true
      )
    end
  end

  describe '#get_state' do
    let(:state_response) { double('OrderStateResponse') }

    before { allow(orders_service).to receive(:get_order_state).and_return(state_response) }

    it 'delegates to orders.get_order_state' do
      result = helper.get_state(account_id: 'acc-1', order_id: 'ord-1')

      expect(orders_service).to have_received(:get_order_state).with(
        account_id: 'acc-1',
        order_id: 'ord-1',
        order_request_id: nil,
        return_metadata: false
      )
      expect(result).to eq(state_response)
    end

    it 'forwards order_request_id and return_metadata' do
      helper.get_state(
        account_id: 'acc-1',
        order_request_id: 'req-1',
        return_metadata: true
      )

      expect(orders_service).to have_received(:get_order_state).with(
        account_id: 'acc-1',
        order_id: nil,
        order_request_id: 'req-1',
        return_metadata: true
      )
    end
  end
end
