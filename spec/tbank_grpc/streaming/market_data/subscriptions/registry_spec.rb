# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Subscriptions::Registry do
  subject(:registry) { described_class.new(max_subscriptions: 3) }

  it 'counts info subscriptions with zero weight' do
    registry.store(:info, { instrument_ids: %w[a b] })
    registry.store(:last_price, { instrument_ids: ['c'] })

    expect(registry.total_subscriptions).to eq(1)
  end

  it 'rejects limit overflow' do
    registry.store(:trades, { instrument_ids: %w[a b c] })

    expect do
      registry.ensure_limit!(:last_price, { instrument_ids: ['d'] })
    end.to raise_error(TbankGrpc::InvalidArgumentError, /Subscription limit exceeded/)
  end

  it 'iterates all stored subscriptions' do
    registry.store(:last_price, { instrument_ids: ['a'] })
    registry.store(:trades, { instrument_ids: %w[b c] })

    pairs = registry.each_subscription.to_a

    expect(pairs).to include([:last_price, { instrument_ids: ['a'] }])
    expect(pairs).to include([:trades, { instrument_ids: %w[b c] }])
  end
end
