# frozen_string_literal: true

RSpec.describe TbankGrpc::Client do
  let(:client) { described_class.new }

  before do
    TbankGrpc.configure do |c|
      c.token = 'test_token'
      c.app_name = 'spec_app'
    end
  end

  after { TbankGrpc.reset_configuration }

  it 'uses global config for token and app_name' do
    expect(client.config).to include(token: 'test_token', app_name: 'spec_app')
  end

  it 'exposes channel_manager' do
    expect(client.channel_manager).to be_a(TbankGrpc::ChannelManager)
  end

  it 'responds to close' do
    expect(client).to respond_to(:close)
  end

  it '#close does not raise' do
    expect { client.close }.not_to raise_error
  end

  it 'exposes #instruments as InstrumentsService' do
    # gRPC Stub requires a real GRPC::Core::Channel (type check); no RPC is called
    channel = GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure)
    allow(client.channel_manager).to receive(:get_channel).and_return(channel)
    expect(client.instruments).to be_a(TbankGrpc::Services::InstrumentsService)
    expect(client.instruments).to equal(client.instruments)
  end

  it 'exposes #helpers as Facade' do
    expect(client.helpers).to be_a(TbankGrpc::Helpers::Facade)
    expect(client.helpers.instruments).to be_a(TbankGrpc::Helpers::InstrumentsHelper)
    expect(client.helpers).to equal(client.helpers)
  end

  context 'when token is empty' do
    before do
      TbankGrpc.configure do |c|
        c.token = ''
        c.app_name = 'x'
      end
    end

    it 'raises ConfigurationError with message about token' do
      expect { described_class.new }.to raise_error(TbankGrpc::ConfigurationError, /Token is required/)
    end
  end

  context 'when app_name is empty' do
    before do
      TbankGrpc.configure do |c|
        c.token = 't'
        c.app_name = ''
      end
    end

    it 'raises ConfigurationError with message about app name' do
      expect { described_class.new }.to raise_error(TbankGrpc::ConfigurationError, /App name is required/)
    end
  end
end
