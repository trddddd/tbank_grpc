# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::Streaming::BaseBidiStreamService do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  class DummyMetrics
    def event_stats(_event_type)
      { emitted: 0 }
    end
  end

  class DummyEventLoop
    attr_reader :metrics

    def initialize
      @metrics = DummyMetrics.new
      @alive = false
    end

    def start
      @alive = true
    end

    def stop
      @alive = false
    end

    def alive?
      @alive
    end

    def stats
      { emitted: 0 }
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  let(:service_class) do
    Class.new(described_class) do
      attr_reader :dispatched

      def initialize(**kwargs)
        @dispatched = []
        @stream_source = [].to_enum
        super
      end

      attr_writer :stream_source

      private

      def stream_key
        'dummy_stream'
      end

      def open_stream
        @stream_source
      end

      def dispatch_response(response)
        @dispatched << response
      end

      def build_event_loop(thread_pool_size:)
        _ = thread_pool_size
        DummyEventLoop.new
      end
    end
  end

  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, reset: nil) }
  let(:config) { { stream_idle_timeout: nil, deadline_overrides: { 'Dummy/Stream' => 0.5 } } }

  subject(:service) do
    service_class.new(
      channel_manager: channel_manager,
      config: config,
      interceptors: [],
      thread_pool_size: 2
    )
  end

  describe '#force_reconnect' do
    it 'resets channel when service is running' do
      service.send(:running=, true)

      service.force_reconnect

      expect(channel_manager).to have_received(:reset).with(source: 'dummy_stream', reason: 'force_reconnect')
    end

    it 'does not reset channel when service is not running' do
      service.force_reconnect

      expect(channel_manager).not_to have_received(:reset)
    end
  end

  describe '#listen' do
    it 'handles Interrupt and always stops event loop' do
      loop_runner = double('listen_loop')
      allow(loop_runner).to receive(:run).and_raise(Interrupt)
      allow(service).to receive(:build_listen_loop).and_return(loop_runner)

      expect { service.listen }.not_to raise_error
      expect(service.send(:running?)).to be(false)
      expect(service.event_loop.alive?).to be(false)
    end

    it 'propagates ReconnectionError from listen loop' do
      loop_runner = double('listen_loop')
      allow(loop_runner).to receive(:run)
        .and_raise(TbankGrpc::Streaming::Core::Runtime::ReconnectionError, 'limit reached')
      allow(service).to receive(:build_listen_loop).and_return(loop_runner)

      expect { service.listen }
        .to raise_error(TbankGrpc::Streaming::Core::Runtime::ReconnectionError, /limit reached/)
      expect(service.event_loop.alive?).to be(false)
    end
  end

  describe '#stream_deadline' do
    it 'returns configured deadline override as Time' do
      deadline = service.send(:stream_deadline, 'Dummy/Stream')

      expect(deadline).to be_a(Time)
      expect(deadline).to be > Time.now
    end

    it 'returns nil without override' do
      expect(service.send(:stream_deadline, 'Nope/Stream')).to be_nil
    end
  end

  describe '#stats' do
    it 'returns lifecycle stats shape' do
      expect(service.stats).to include(
        :metrics,
        :reconnects,
        :last_event_at,
        :listening,
        :async_status
      )
    end
  end
end
