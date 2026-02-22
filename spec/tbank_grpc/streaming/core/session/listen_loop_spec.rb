# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Streaming::Core::Session::ListenLoop do
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, reset: nil) }
  let(:reconnection_strategy) { instance_double(TbankGrpc::Streaming::Core::Runtime::ReconnectionStrategy, call: nil) }
  let(:dispatch_response) { instance_double(Proc, call: nil) }
  let(:increment_reconnects) { instance_double(Proc, call: nil) }
  let(:stop_running) { instance_double(Proc, call: nil) }
  let(:running_flag) { true }

  subject(:loop_runner) do
    described_class.new(
      channel_manager: channel_manager,
      reconnection_strategy: reconnection_strategy,
      open_stream: open_stream,
      running: -> { running_flag },
      stop_running: stop_running,
      dispatch_response: dispatch_response,
      increment_reconnects: increment_reconnects
    )
  end

  let(:types) { Tinkoff::Public::Invest::Api::Contract::V1 }

  before { TbankGrpc::ProtoLoader.require!('marketdata') }

  context 'process stream behavior' do
    context 'when stream disconnects after receiving event' do
      let(:open_stream) do
        lambda do
          Enumerator.new do |yielder|
            yielder << types::MarketDataResponse.new(ping: types::Ping.new)
            raise GRPC::DeadlineExceeded, 'deadline'
          end
        end
      end

      it 'returns true and dispatches received response' do
        result = loop_runner.send(:process_stream)

        expect(result).to be(true)
        expect(dispatch_response).to have_received(:call).once
      end
    end

    context 'when auth error happens before events' do
      let(:open_stream) { -> { raise GRPC::PermissionDenied, 'denied' } }

      it 'returns false and asks caller to stop running' do
        result = loop_runner.send(:process_stream)

        expect(result).to be(false)
        expect(stop_running).to have_received(:call)
      end
    end
  end

  context 'failure counter semantics' do
    let(:open_stream) { -> { [].to_enum } }

    it 'does not increment failures when stream was opened but produced no events' do
      allow(loop_runner).to receive(:process_stream) do
        loop_runner.instance_variable_set(:@last_iteration_stream_opened, true)
        false
      end
      allow(loop_runner).to receive(:running?).and_return(true)
      allow(loop_runner).to receive(:reconnect_after_iteration)

      result = loop_runner.send(:process_iteration, 3)

      expect(result).to eq(0)
      expect(loop_runner).to have_received(:reconnect_after_iteration).with(0)
    end

    it 'increments failures when stream was not opened' do
      allow(loop_runner).to receive(:process_stream) do
        loop_runner.instance_variable_set(:@last_iteration_stream_opened, false)
        false
      end
      allow(loop_runner).to receive(:running?).and_return(true)
      allow(loop_runner).to receive(:reconnect_after_iteration)

      result = loop_runner.send(:process_iteration, 3)

      expect(result).to eq(4)
      expect(loop_runner).to have_received(:reconnect_after_iteration).with(4)
    end
  end
end
