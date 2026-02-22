# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe TbankGrpc::Streaming::Core::Dispatch::EventLoop do
  let(:loop_instance) { described_class.new(thread_pool_size: 2) }

  after { loop_instance.stop }

  it 'is alive after start' do
    loop_instance.start
    expect(loop_instance.alive?).to be(true)
  end

  it 'is not alive after stop' do
    loop_instance.start
    loop_instance.stop
    expect(loop_instance.alive?).to be(false)
  end

  it 'can be started again after stop' do
    loop_instance.start
    loop_instance.stop
    loop_instance.start
    expect(loop_instance.alive?).to be(true)
  end

  it 'handles concurrent start and stop calls and still processes new events' do
    10.times do
      starter = Thread.new { loop_instance.start }
      stopper = Thread.new { loop_instance.stop }
      starter.join
      stopper.join
    end

    queue = Queue.new
    loop_instance.on(:candle) { |payload| queue << payload }
    loop_instance.start
    loop_instance.emit(:candle, proto_payload: 'after-restart', model_payload: nil)

    received = Timeout.timeout(1) { queue.pop }
    expect(received).to eq('after-restart')
  end

  it 'processes callbacks in worker threads' do
    queue = Queue.new
    loop_instance.on(:candle) { |payload| queue << payload }

    loop_instance.start
    loop_instance.emit(:candle, proto_payload: 'proto', model_payload: 'model')

    received = Timeout.timeout(1) { queue.pop }
    expect(received).to eq('proto')
  end

  it 'supports model payload callbacks' do
    queue = Queue.new
    loop_instance.on(:candle, as: :model) { |payload| queue << payload }

    loop_instance.start
    loop_instance.emit(:candle, proto_payload: 'proto', model_payload: 'model')

    received = Timeout.timeout(1) { queue.pop }
    expect(received).to eq('model')
  end

  it 'tracks callback errors and still stops cleanly' do
    queue = Queue.new
    loop_instance.on(:candle) { raise 'boom' }
    loop_instance.on(:candle) { |payload| queue << payload }

    loop_instance.start
    loop_instance.emit(:candle, proto_payload: 1, model_payload: nil)

    Timeout.timeout(1) { queue.pop }

    stats = loop_instance.stats
    expect(stats[:callbacks_error][:candle]).to eq(1)
    expect(stats[:thread_pool_size]).to eq(2)
  end

  it 'returns false for needs_model_payload when only proto callbacks registered' do
    loop_instance.on(:candle, as: :proto) { |_payload| nil }
    expect(loop_instance.needs_model_payload?(:candle)).to be(false)
  end

  it 'returns true for needs_model_payload when model callback registered' do
    loop_instance.on(:candle, as: :model) { |_payload| nil }
    expect(loop_instance.needs_model_payload?(:candle)).to be(true)
  end
end
