# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Operations::OperationsByCursorPage do
  before { TbankGrpc::ProtoLoader.require!('operations') }

  let(:types) { TbankGrpc::CONTRACT_V1 }

  it 'maps cursor page and items to models' do
    item = types::OperationItem.new(
      id: 'op-1',
      cursor: 'cur-1',
      type: :OPERATION_TYPE_BUY,
      state: :OPERATION_STATE_EXECUTED,
      figi: 'BBG123'
    )
    proto = types::GetOperationsByCursorResponse.new(
      has_next: true,
      next_cursor: 'next-cur',
      items: [item]
    )

    model = described_class.from_grpc(proto)

    expect(model.has_next).to be(true)
    expect(model.next_cursor).to eq('next-cur')
    expect(model.items_count).to eq(1)
    expect(model.items.first).to be_a(TbankGrpc::Models::Operations::OperationItem)
    expect(model.items.first.id).to eq('op-1')
    expect(model.items.first.cursor).to eq('cur-1')
  end
end
