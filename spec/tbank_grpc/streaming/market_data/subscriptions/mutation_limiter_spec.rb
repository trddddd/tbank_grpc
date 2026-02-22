# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::MarketData::Subscriptions::MutationLimiter do
  subject(:limiter) { described_class.new(max_mutations: 100, window_sec: 60) }

  it 'raises after the configured mutation limit' do
    100.times { limiter.register! }

    expect { limiter.register! }.to raise_error(TbankGrpc::InvalidArgumentError, /mutation limit exceeded/i)
  end
end
