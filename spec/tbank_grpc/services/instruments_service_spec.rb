# frozen_string_literal: true

RSpec.describe TbankGrpc::Services::InstrumentsService do
  it 'inherits from Unary::BaseUnaryService' do
    expect(described_class).to be < TbankGrpc::Services::Unary::BaseUnaryService
  end

  it 'includes all instrument submodules' do
    expect(described_class).to include(
      TbankGrpc::Services::Instruments::Lookup,
      TbankGrpc::Services::Instruments::Listings,
      TbankGrpc::Services::Instruments::Schedules,
      TbankGrpc::Services::Instruments::CorporateActions,
      TbankGrpc::Services::Instruments::Derivatives,
      TbankGrpc::Services::Instruments::Assets
    )
  end

  describe 'instance interface (contract)' do
    # gRPC Stub requires a real GRPC::Core::Channel (type check); no RPC is called
    let(:channel) { GRPC::Core::Channel.new('localhost:50051', {}, :this_channel_is_insecure) }
    let(:config) { { token: 't', app_name: 'trddddd.tbank_grpc', sandbox: true, timeout: 30 } }
    let(:service) { described_class.new(channel, config, interceptors: []) }

    it 'exposes stub' do
      expect(service.stub).not_to be_nil
    end

    %i[
      get_instrument_by share_by bond_by future_by find_instrument
      shares bonds futures trading_schedules
      get_bond_coupons get_accrued_interests get_dividends get_futures_margin
      get_asset_by get_asset_fundamentals get_asset_reports
    ].each do |method_name|
      it "responds to ##{method_name}" do
        expect(service).to respond_to(method_name)
      end
    end
  end
end
