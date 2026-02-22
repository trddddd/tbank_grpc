# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe TbankGrpc::Streaming::Core::Runtime::AsyncListener do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  class TestAsyncService
    attr_reader :stop_calls

    def initialize(gate:, stop_writes_gate:)
      @gate = gate
      @stop_writes_gate = stop_writes_gate
      @stop_calls = 0
    end

    def listen
      @gate.pop
    end

    def stop
      @stop_calls += 1
      @gate << :stop if @stop_writes_gate
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  it 'starts and stops listener cooperatively' do
    gate = Queue.new
    service = TestAsyncService.new(gate: gate, stop_writes_gate: true)

    listener = described_class.new(service)
    thread = listener.start

    Timeout.timeout(1) do
      sleep(0.01) until listener.listening?
    end

    listener.stop

    expect(service.stop_calls).to eq(1)
    expect(listener.running?).to be(false)
    expect(thread.alive?).to be(false)
  end

  it 'does not force kill listener thread when graceful stop times out' do
    gate = Queue.new
    service = TestAsyncService.new(gate: gate, stop_writes_gate: false)
    stub_const("#{described_class}::JOIN_TIMEOUT_SEC", 0.01)

    listener = described_class.new(service)
    thread = listener.start

    Timeout.timeout(1) do
      sleep(0.01) until listener.listening?
    end

    listener.stop
    expect(thread.alive?).to be(true)

    gate << :stop
    expect(thread.join(1)).to be(thread)
  end

  it 'raises when started twice without stop' do
    gate = Queue.new
    service = TestAsyncService.new(gate: gate, stop_writes_gate: true)

    listener = described_class.new(service)
    listener.start

    expect { listener.start }.to raise_error(TbankGrpc::InvalidArgumentError, /already running/)
  ensure
    listener&.stop
  end
end
