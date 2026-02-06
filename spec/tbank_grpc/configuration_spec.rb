# frozen_string_literal: true

RSpec.describe TbankGrpc::Configuration do
  let(:config) { described_class.new }

  it 'has default app_name' do
    expect(config.app_name).to eq('trddddd.tbank_grpc')
  end

  it 'has default endpoint nil' do
    expect(config.endpoint).to be_nil
  end

  it 'has default sandbox false' do
    expect(config.sandbox).to be false
  end

  it 'has default timeout' do
    expect(config.timeout).to eq(30)
  end

  it 'returns to_h including set token, app_name, endpoint and sandbox' do
    config.token = 'test'
    config.app_name = 'spec'
    config.endpoint = 'localhost:50051'

    h = config.to_h

    expect(h).to include(token: 'test', app_name: 'spec', sandbox: false, endpoint: 'localhost:50051')
  end
end

RSpec.describe TbankGrpc do
  describe '.configure' do
    after { TbankGrpc.reset_configuration }

    it 'yields configuration and sets token and app_name' do
      TbankGrpc.configure do |c|
        c.token = 't'
        c.app_name = 'a'
      end

      expect(TbankGrpc.configuration).to have_attributes(token: 't', app_name: 'a')
    end
  end
end
