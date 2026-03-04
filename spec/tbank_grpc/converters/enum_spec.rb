# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Converters::Enum do
  before { TbankGrpc::ProtoLoader.require!('orders') }

  describe '.resolve' do
    let(:enum_module) { TbankGrpc::CONTRACT_V1::OrderExecutionReportStatus }

    it 'accepts partially_fill alias for PARTIALLYFILL proto enum' do
      resolved = described_class.resolve(
        enum_module,
        :partially_fill,
        prefix: 'EXECUTION_REPORT_STATUS'
      )

      expect(resolved).to eq(enum_module::EXECUTION_REPORT_STATUS_PARTIALLYFILL)
    end

    it 'raises InvalidArgumentError for unknown values' do
      expect do
        described_class.resolve(enum_module, :not_existing, prefix: 'EXECUTION_REPORT_STATUS')
      end.to raise_error(TbankGrpc::InvalidArgumentError, /Unknown enum value/)
    end
  end
end
