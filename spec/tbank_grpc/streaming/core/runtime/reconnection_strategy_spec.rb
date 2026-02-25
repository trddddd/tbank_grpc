# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::Core::Runtime::ReconnectionStrategy do
  it 'raises ReconnectionError when max attempts exceeded' do
    strategy = described_class.new(max_attempts: 1, base_delay: 0)

    expect { strategy.call(1) }.not_to raise_error
    expect { strategy.call(2) }
      .to raise_error(TbankGrpc::Streaming::Core::Runtime::ReconnectionError, /Max reconnection attempts reached/)
  end

  it 'can abort wait using block' do
    strategy = described_class.new(max_attempts: 3, base_delay: 5)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    strategy.call(1) { true }

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be < 0.2
  end
end
