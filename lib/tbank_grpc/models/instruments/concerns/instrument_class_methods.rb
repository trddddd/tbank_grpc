# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      module Concerns
        # Классовые методы {Instrument}: кэш моделей, from_grpc, определение типа по proto.
        module InstrumentClassMethods
          INSTRUMENT_KIND_MAP = {
            0 => :INSTRUMENT_TYPE_UNSPECIFIED,
            1 => :INSTRUMENT_TYPE_BOND,
            2 => :INSTRUMENT_TYPE_SHARE,
            3 => :INSTRUMENT_TYPE_CURRENCY,
            4 => :INSTRUMENT_TYPE_ETF,
            5 => :INSTRUMENT_TYPE_FUTURES,
            6 => :INSTRUMENT_TYPE_SP,
            7 => :INSTRUMENT_TYPE_OPTION,
            8 => :INSTRUMENT_TYPE_CLEARING_CERTIFICATE
          }.freeze

          VALID_INSTRUMENT_TYPES = %i[
            INSTRUMENT_TYPE_SHARE INSTRUMENT_TYPE_BOND INSTRUMENT_TYPE_ETF
            INSTRUMENT_TYPE_FUTURES INSTRUMENT_TYPE_OPTION INSTRUMENT_TYPE_CURRENCY
            INSTRUMENT_TYPE_SP INSTRUMENT_TYPE_CLEARING_CERTIFICATE
          ].freeze

          # instrument_kind/instrument_type → ключ в model_cache (имя класса)
          INSTRUMENT_KIND_TO_CACHE_KEY = {
            INSTRUMENT_TYPE_BOND: 'Bond',
            INSTRUMENT_TYPE_SHARE: 'Share',
            INSTRUMENT_TYPE_ETF: 'ETF',
            INSTRUMENT_TYPE_FUTURES: 'Future',
            INSTRUMENT_TYPE_OPTION: 'Option',
            INSTRUMENT_TYPE_CURRENCY: 'Currency',
            INSTRUMENT_TYPE_SP: 'StructuredNote'
          }.freeze

          # Маппинг суффикса имени proto-класса → тип инструмента (fallback при отсутствии kind/type).
          PROTO_CLASS_TO_TYPE = {
            'Currency' => :INSTRUMENT_TYPE_CURRENCY,
            'Future' => :INSTRUMENT_TYPE_FUTURES,
            'Share' => :INSTRUMENT_TYPE_SHARE,
            'Bond' => :INSTRUMENT_TYPE_BOND,
            'Etf' => :INSTRUMENT_TYPE_ETF,
            'Option' => :INSTRUMENT_TYPE_OPTION,
            'StructuredNote' => :INSTRUMENT_TYPE_SP
          }.freeze

          MODEL_CACHE_MUTEX = Mutex.new

          def model_cache
            return @model_cache if instance_variable_defined?(:@model_cache)

            MODEL_CACHE_MUTEX.synchronize do
              return @model_cache if instance_variable_defined?(:@model_cache)

              @model_cache = Instruments.constants.filter_map do |const|
                next if const.to_s.start_with?('_')

                klass = Instruments.const_get(const)
                [const.to_s, klass] if klass.is_a?(Class)
              end.to_h.freeze
            end
            @model_cache
          end

          # Собирает конкретную модель инструмента (например, {Bond} / {Share} / {Future})
          # на основе типа protobuf-сообщения и полей kind/type.
          #
          # @param proto_instrument [Google::Protobuf::MessageExts, nil]
          # @return [Instrument, nil]
          def from_grpc(proto_instrument)
            return unless proto_instrument

            cache = model_cache
            model_class = cache[proto_class_key(proto_instrument)]
            if model_class.nil? || model_class == self
              model_class = cache[INSTRUMENT_KIND_TO_CACHE_KEY[resolve_instrument_type_from_proto(proto_instrument)]]
            end
            (model_class || self).new(proto_instrument)
          end

          # Вычисляет символьный тип инструмента из protobuf.
          #
          # @param proto [Google::Protobuf::MessageExts, nil]
          # @return [Symbol, nil]
          def resolve_instrument_type_from_proto(proto)
            return unless proto

            sym = type_from_instrument_kind(proto) || type_from_instrument_type(proto)
            sym || PROTO_CLASS_TO_TYPE[proto_class_key(proto)]
          end

          private

          def proto_class_key(proto)
            class_name = proto.class.name
            return if class_name.to_s.empty?

            class_name.split('::').last
          end

          def type_from_instrument_kind(proto)
            kind = proto.instrument_kind if proto.respond_to?(:instrument_kind)
            return unless kind

            sym = kind.is_a?(Integer) ? INSTRUMENT_KIND_MAP[kind] : kind
            sym if VALID_INSTRUMENT_TYPES.include?(sym)
          end

          def type_from_instrument_type(proto)
            val = proto.instrument_type if proto.respond_to?(:instrument_type)
            return unless val

            return val if VALID_INSTRUMENT_TYPES.include?(val)

            normalized = TbankGrpc::Normalizers::TickerNormalizer.normalize(val)
            normalized = "INSTRUMENT_TYPE_#{normalized}" unless normalized.start_with?('INSTRUMENT_TYPE_')
            sym = normalized.to_sym
            sym if VALID_INSTRUMENT_TYPES.include?(sym)
          end
        end
      end
    end
  end
end
