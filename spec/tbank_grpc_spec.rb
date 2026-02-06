# frozen_string_literal: true

RSpec.describe TbankGrpc do
  it 'has a version number' do
    expect(TbankGrpc::VERSION).to be_a(String)
    expect(TbankGrpc::VERSION).not_to be_empty
  end

  it 'exposes version via .version' do
    expect(TbankGrpc.version).to eq(TbankGrpc::VERSION)
  end
end
