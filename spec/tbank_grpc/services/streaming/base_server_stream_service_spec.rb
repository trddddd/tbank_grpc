# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Services::Streaming::BaseServerStreamService do
  let(:channel_manager) { instance_double(TbankGrpc::ChannelManager, channel: :channel) }
  let(:config) { { deadline_overrides: { 'svc/method' => 1.5 } } }

  let(:service_class) do
    Class.new(described_class) do
      def invoke(**kwargs, &consumer)
        send(:run_server_side_stream, **kwargs, &consumer)
      end

      def deadline_for(name)
        send(:stream_deadline, name)
      end
    end
  end

  subject(:service) { service_class.new(channel_manager: channel_manager, config: config, interceptors: []) }

  describe '#run_server_side_stream' do
    let(:stub) { double('stub') }
    let(:request) { double('request') }

    it 'returns raw stream enumerator without block for as: :proto' do
      stream = [1, 2, 3].to_enum
      allow(stub).to receive(:server_stream).and_return(stream)

      result = service.invoke(
        stub: stub,
        rpc_method: :server_stream,
        request: request,
        method_full_name: 'svc/method',
        as: :proto,
        model_requires_block_message: 'requires block',
        converter: ->(response, format:) { [response, format] }
      )

      expect(result).to eq(stream)
      expect(stub).to have_received(:server_stream).with(
        request,
        hash_including(metadata: {}, deadline: be_a(Time))
      )
    end

    it 'raises for as: :model without block' do
      allow(stub).to receive(:server_stream).and_return([:one].to_enum)

      expect do
        service.invoke(
          stub: stub,
          rpc_method: :server_stream,
          request: request,
          method_full_name: 'svc/method',
          as: :model,
          model_requires_block_message: 'requires block',
          converter: ->(_response, format:) { format }
        )
      end.to raise_error(TbankGrpc::InvalidArgumentError, /requires block/)
    end

    it 'maps responses in block form and skips nil payloads' do
      allow(stub).to receive(:server_stream).and_return([1, 2].to_enum)

      result = []
      service.invoke(
        stub: stub,
        rpc_method: :server_stream,
        request: request,
        method_full_name: 'svc/method',
        as: :model,
        model_requires_block_message: 'requires block',
        converter: lambda { |response, format:|
          value = format == :model ? response * 10 : response
          value == 20 ? nil : value
        }
      ) { |payload| result << payload }

      expect(result).to eq([10])
    end

    it 'handles GRPC::Cancelled without raising' do
      allow(stub).to receive(:server_stream).and_raise(GRPC::Cancelled.new(1, 'cancelled'))

      expect do
        service.invoke(
          stub: stub,
          rpc_method: :server_stream,
          request: request,
          method_full_name: 'svc/method',
          as: :proto,
          model_requires_block_message: 'requires block',
          converter: ->(response, format:) { [response, format] }
        )
      end.not_to raise_error
    end
  end

  describe '#stream_deadline' do
    it 'uses configured override in seconds' do
      deadline = service.deadline_for('svc/method')

      expect(deadline).to be_a(Time)
      expect(deadline).to be > Time.now
    end

    it 'returns nil when override is absent' do
      expect(service.deadline_for('unknown/method')).to be_nil
    end
  end
end
