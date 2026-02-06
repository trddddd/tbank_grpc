# frozen_string_literal: true

RSpec.describe TbankGrpc::ConfigurationError do
  it 'is a kind of TbankGrpc::Error' do
    expect(described_class).to be < TbankGrpc::Error
  end

  it 'stores message' do
    e = described_class.new('token required')

    expect(e.message).to eq('token required')
  end
end

RSpec.describe TbankGrpc::ConnectionFailedError do
  it 'is a kind of ConnectionError' do
    expect(described_class).to be < TbankGrpc::ConnectionError
  end
end
