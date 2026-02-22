# frozen_string_literal: true

RSpec.describe TbankGrpc::TrackingId do
  describe '.extract' do
    it 'returns nil for nil metadata' do
      expect(described_class.extract(nil)).to be_nil
    end

    it 'returns nil for empty metadata' do
      expect(described_class.extract({})).to be_nil
    end

    it 'extracts value by string key x-tracking-id' do
      expect(described_class.extract('x-tracking-id' => 'abc-123')).to eq('abc-123')
    end

    it 'extracts value by symbol key :"x-tracking-id"' do
      expect(described_class.extract('x-tracking-id': 'sym-456')).to eq('sym-456')
    end

    it 'returns nil when value is empty string' do
      expect(described_class.extract('x-tracking-id' => '')).to be_nil
    end

    it 'returns nil when value is whitespace only' do
      expect(described_class.extract('x-tracking-id' => '   ')).to be_nil
    end

    it 'takes first element when value is Array' do
      expect(described_class.extract('x-tracking-id' => %w[first second])).to eq('first')
    end

    it 'strips value' do
      expect(described_class.extract('x-tracking-id' => '  id  ')).to eq('id')
    end
  end
end
