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
    it 'formats quotation fields without internal object dump' do
      model = described_class.from_grpc(proto)
      output = model.inspect

      expect(output).to include('open: 306.15')
      expect(output).to include('close: 305.8')
      expect(output).not_to include('Core::ValueObjects::Quotation')
    end
  end

  describe '#to_h' do
    it 'supports :decimal precision alias for quotation serialization' do
      model = described_class.from_grpc(proto)
      payload = model.to_h(precision: :decimal)

      expect(payload[:open]).to be_a(BigDecimal)
      expect(payload[:close]).to be_a(BigDecimal)
    end
  end
end
