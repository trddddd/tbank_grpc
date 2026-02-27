# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Operations::Operation do
  before { TbankGrpc::ProtoLoader.require!('operations') }

  let(:proto) do
    TbankGrpc::CONTRACT_V1::Operation.new(
      id: 'op-1',
      parent_operation_id: '',
      currency: 'rub',
      state: :OPERATION_STATE_EXECUTED,
      quantity: 1,
      quantity_rest: 0,
      figi: 'BBG123',
      instrument_type: 'share',
      type: 'Покупка ЦБ',
      operation_type: :OPERATION_TYPE_BUY,
      position_uid: 'pos-1',
      instrument_uid: 'inst-1'
    )
  end

  describe '.from_grpc' do
    it 'returns Operation with id, type, state, figi' do
      model = described_class.from_grpc(proto)

      expect(model).to be_a(described_class)
      expect(model.id).to eq('op-1')
      expect(model.type).to eq('Покупка ЦБ')
      expect(model.state).to eq(:OPERATION_STATE_EXECUTED)
      expect(model.figi).to eq('BBG123')
    end
  end
end
