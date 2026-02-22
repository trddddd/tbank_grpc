# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::MarketData::Candle do
  let(:timestamp_proto_class) { Struct.new(:seconds, :nanos, keyword_init: true) }
  let(:quotation_proto_class) { Struct.new(:units, :nano, keyword_init: true) }
  let(:candle_proto_class) do
    Struct.new(
      :figi, :instrument_uid, :time, :open, :high, :low, :close, :volume, :is_complete,
      keyword_init: true
    )
  end

  let(:proto) do
    candle_proto_class.new(
      figi: nil,
      instrument_uid: 'BBG004730N88',
      time: timestamp_proto_class.new(seconds: 1_707_750_000, nanos: 0),
      open: quotation_proto_class.new(units: 306, nano: 150_000_000),
      high: quotation_proto_class.new(units: 306, nano: 290_000_000),
      low: quotation_proto_class.new(units: 305, nano: 350_000_000),
      close: quotation_proto_class.new(units: 305, nano: 800_000_000),
      volume: 1_936_617,
      is_complete: true
    )
  end

  describe '#inspect' do
    it 'includes open quotation in human-readable form' do
      model = described_class.from_grpc(proto)
      expect(model.inspect).to include('open: 306.15')
    end

    it 'includes close quotation in human-readable form' do
      model = described_class.from_grpc(proto)
      expect(model.inspect).to include('close: 305.8')
    end

    it 'omits internal Quotation class name from output' do
      model = described_class.from_grpc(proto)
      expect(model.inspect).not_to include('Core::ValueObjects::Quotation')
    end
  end

  describe '#to_h' do
    it 'serializes quotation fields as BigDecimal with :decimal precision' do
      model = described_class.from_grpc(proto)
      payload = model.to_h(precision: :decimal)

      expect(payload).to include(open: a_kind_of(BigDecimal), close: a_kind_of(BigDecimal))
    end
  end
end
