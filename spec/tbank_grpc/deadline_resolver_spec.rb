# frozen_string_literal: true

RSpec.describe TbankGrpc::DeadlineResolver do
  describe '.deadline_for' do
    it 'returns nil when method_full_name is nil' do
      expect(described_class.deadline_for(nil, {})).to be_nil
    end

    it 'returns Time in future for known service and default config' do
      config = { timeout: 30 }
      deadline = described_class.deadline_for('InstrumentsService/GetBondBy', config)
      expect(deadline).to be_a(Time).and be > Time.now
    end

    it 'uses DEFAULT_DEADLINES for InstrumentsService' do
      config = {}
      deadline = described_class.deadline_for('InstrumentsService/GetBondBy', config)
      expect(deadline - Time.now).to be_between(179, 181)
    end

    it 'uses deadline_overrides by method full name' do
      config = { deadline_overrides: { 'InstrumentsService/GetBondBy' => 10 } }
      deadline = described_class.deadline_for('InstrumentsService/GetBondBy', config)
      expect(deadline - Time.now).to be_between(9, 11)
    end

    it 'uses deadline_overrides by service name' do
      config = { deadline_overrides: { 'InstrumentsService' => 5 } }
      deadline = described_class.deadline_for('InstrumentsService/GetBondBy', config)
      expect(deadline - Time.now).to be_between(4, 6)
    end

    it 'falls back to config :timeout for unknown service' do
      config = { timeout: 20 }
      deadline = described_class.deadline_for('UnknownService/SomeMethod', config)
      expect(deadline - Time.now).to be_between(19, 21)
    end

    it 'returns nil when no deadline can be resolved' do
      config = {}
      expect(described_class.deadline_for('UnknownService/Foo', config)).to be_nil
    end
  end
end
