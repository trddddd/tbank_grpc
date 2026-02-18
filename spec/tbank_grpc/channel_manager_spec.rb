# frozen_string_literal: true

RSpec.describe TbankGrpc::ChannelManager do
  let(:config) do
    {
      token: 't',
      app_name: 'spec',
      sandbox: true
    }
  end

  let(:manager) { described_class.new(config) }

  it 'exposes ENDPOINTS with production and sandbox' do
    expect(described_class::ENDPOINTS[:production]).to eq('invest-public-api.tbank.ru:443')
    expect(described_class::ENDPOINTS[:sandbox]).to eq('sandbox-invest-public-api.tbank.ru:443')
  end

  context 'when endpoint format is invalid' do
    let(:config) { super().merge(endpoint: 'no-port') }

    it 'raises ConfigurationError on channel' do
      expect { manager.channel }.to raise_error(TbankGrpc::ConfigurationError, /Invalid endpoint/)
    end
  end
end
