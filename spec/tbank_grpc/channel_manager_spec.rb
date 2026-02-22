# frozen_string_literal: true

RSpec.describe TbankGrpc::ChannelManager do
  let(:config) do
    {
      token: 't',
      app_name: 'trddddd.tbank_grpc',
      sandbox: true
    }
  end

  let(:manager) { described_class.new(config) }

  it 'exposes ENDPOINTS with production and sandbox' do
    expect(described_class::ENDPOINTS[:production]).to eq('invest-public-api.tbank.ru:443')
    expect(described_class::ENDPOINTS[:sandbox]).to eq('sandbox-invest-public-api.tbank.ru:443')
  end

  it 'exposes ENDPOINTS_INSECURE (Tinkoff hosts for insecure mode)' do
    expect(described_class::ENDPOINTS_INSECURE[:production]).to eq('invest-public-api.tinkoff.ru:443')
    expect(described_class::ENDPOINTS_INSECURE[:sandbox]).to eq('sandbox-invest-public-api.tinkoff.ru:443')
  end

  context 'when insecure and no explicit endpoint' do
    let(:config) { super().merge(sandbox: false, insecure: true) }

    it 'creates channel to Tinkoff production host with TLS (system certs)' do
      allow(GRPC::Core::Channel).to receive(:new).and_return(instance_double(GRPC::Core::Channel, close: nil))
      manager.channel
      expect(GRPC::Core::Channel).to have_received(:new).with(
        'invest-public-api.tinkoff.ru:443',
        anything,
        an_instance_of(GRPC::Core::ChannelCredentials)
      )
    end
  end

  context 'when endpoint format is invalid' do
    let(:config) { super().merge(endpoint: 'no-port') }

    it 'raises ConfigurationError on channel' do
      expect { manager.channel }.to raise_error(TbankGrpc::ConfigurationError, /Invalid endpoint/)
    end
  end

  it 'reset closes active pooled channels' do
    fake_channel = instance_double(GRPC::Core::Channel, close: nil)
    allow(manager).to receive(:create_channel).and_return(fake_channel)

    manager.channel
    manager.reset

    expect(fake_channel).to have_received(:close)
  end
end
