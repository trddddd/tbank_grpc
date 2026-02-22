# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::Core::Runtime::StreamWatchdog do
  let(:service) do
    instance_double(
      TbankGrpc::Services::MarketDataStreamService,
      listening?: true,
      last_event_at: Time.now - 10,
      force_reconnect: nil
    )
  end

  subject(:watchdog) { described_class.new(service: service, timeout_sec: 1, check_interval_sec: 1) }

  it 'forces reconnect when idle timeout exceeded' do
    watchdog.send(:check_idle_timeout)

    expect(service).to have_received(:force_reconnect)
  end

  it 'does nothing when service is not listening' do
    allow(service).to receive(:listening?).and_return(false)

    watchdog.send(:check_idle_timeout)

    expect(service).not_to have_received(:force_reconnect)
  end
end
