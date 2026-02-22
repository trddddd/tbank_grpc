# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TbankGrpc::Models::Instruments::Instrument do
  describe '#instrument_type' do
    context 'when proto contains integer instrument_kind' do
      let(:proto_class) { Struct.new(:instrument_kind, :instrument_type, keyword_init: true) }
      let(:proto) { proto_class.new(instrument_kind: 2, instrument_type: nil) }
      let(:model) { described_class.new(proto) }

      it 'returns mapped instrument type' do
        result = model.instrument_type

        expect(result).to eq(:INSTRUMENT_TYPE_SHARE)
      end
    end

    context 'when proto contains instrument_type string without prefix' do
      let(:proto_class) { Struct.new(:instrument_kind, :instrument_type, keyword_init: true) }
      let(:proto) { proto_class.new(instrument_kind: nil, instrument_type: 'bond') }
      let(:model) { described_class.new(proto) }

      it 'normalizes and returns instrument type' do
        result = model.instrument_type

        expect(result).to eq(:INSTRUMENT_TYPE_BOND)
      end
    end

    context 'when proto has no kind or type but class suffix is Share' do
      let(:proto_class) do
        Module.new do
          # rubocop:disable Lint/ConstantDefinitionInBlock
          class Share
            def instrument_kind
              nil
            end

            def instrument_type
              nil
            end
          end
          # rubocop:enable Lint/ConstantDefinitionInBlock
        end.const_get(:Share)
      end
      let(:proto) { proto_class.new }
      let(:model) { described_class.new(proto) }

      it 'infers type from class name fallback' do
        result = model.instrument_type

        expect(result).to eq(:INSTRUMENT_TYPE_SHARE)
      end
    end

    context 'when proto type is unknown' do
      let(:proto_class) { Struct.new(:instrument_kind, :instrument_type, keyword_init: true) }
      let(:proto) { proto_class.new(instrument_kind: nil, instrument_type: 'unknown_type') }
      let(:model) { described_class.new(proto) }

      it 'returns nil' do
        result = model.instrument_type

        expect(result).to be_nil
      end
    end

    context 'when proto is nil' do
      let(:model) { described_class.new(nil) }

      it 'returns nil' do
        result = model.instrument_type

        expect(result).to be_nil
      end
    end
  end
end
