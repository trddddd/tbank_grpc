# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Универсальная модель инструмента.
      #
      # Используется в ответах:
      # `GetInstrumentBy`, `ShareBy`, `BondBy`, `FutureBy`, `Shares`, `Bonds`, `Futures`.
      class Instrument < BaseModel
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

        # Маппинг instrument_kind/instrument_type → ключ в model_cache (имя класса)
        INSTRUMENT_KIND_TO_CACHE_KEY = {
          INSTRUMENT_TYPE_BOND: 'Bond',
          INSTRUMENT_TYPE_SHARE: 'Share',
          INSTRUMENT_TYPE_ETF: 'ETF',
          INSTRUMENT_TYPE_FUTURES: 'Future',
          INSTRUMENT_TYPE_OPTION: 'Option',
          INSTRUMENT_TYPE_CURRENCY: 'Currency',
          INSTRUMENT_TYPE_SP: 'StructuredNote'
        }.freeze

        def self.model_cache
          return @model_cache if defined?(@model_cache) && @model_cache

          synchronize_model_cache do
            return @model_cache if defined?(@model_cache) && @model_cache

            mod = Instruments
            @model_cache = mod.constants.each_with_object({}) do |const, cache|
              next if const.to_s.start_with?('_')

              klass = mod.const_get(const)
              cache[const.to_s] = klass if klass.is_a?(Class)
            end.freeze
          end
          @model_cache
        end

        def self.synchronize_model_cache(&)
          @model_cache_mutex ||= Mutex.new
          @model_cache_mutex.synchronize(&)
        end
        private_class_method :synchronize_model_cache

        grpc_simple :figi, :ticker, :class_code, :isin, :lot,
                    :currency, :name, :uid, :trading_status, :asset_uid
        grpc_simple_with_fallback :instrument_uid, fallback: :uid
        grpc_alias :lot_size, :lot

        inspectable_attrs :figi, :ticker, :name, :class_code, :isin,
                          :instrument_type, :currency, :lot_size,
                          :trading_status, :instrument_uid

        instrument_type_predicates types_constant: :VALID_INSTRUMENT_TYPES
        grpc_alias :stock?, :share?

        class << self
          # Собирает конкретную модель инструмента (например, {Bond} / {Share} / {Future})
          # на основе типа protobuf-сообщения и полей kind/type.
          #
          # @param proto_instrument [Google::Protobuf::MessageExts, nil]
          # @return [Instrument, nil]
          def from_grpc(proto_instrument)
            return unless proto_instrument

            key = proto_instrument.class.name.split('::').last
            model_class = model_cache[key]
            if !model_class || model_class == self
              kind = resolve_instrument_type_from_proto(proto_instrument)
              cache_key = kind && INSTRUMENT_KIND_TO_CACHE_KEY[kind]
              model_class = model_cache[cache_key] if cache_key
            end
            model_class ? model_class.new(proto_instrument) : new(proto_instrument)
          end

          # Вычисляет символьный тип инструмента из protobuf.
          #
          # @param proto [Google::Protobuf::MessageExts, nil]
          # @return [Symbol, nil]
          def resolve_instrument_type_from_proto(proto)
            return unless proto

            if proto.respond_to?(:instrument_kind) && proto.instrument_kind
              kind = proto.instrument_kind
              sym = kind.is_a?(Integer) ? INSTRUMENT_KIND_MAP[kind] : kind
              return sym if VALID_INSTRUMENT_TYPES.include?(sym)
            end

            if proto.respond_to?(:instrument_type) && proto.instrument_type
              val = proto.instrument_type
              return val if VALID_INSTRUMENT_TYPES.include?(val)

              normalized = val.to_s.strip.upcase
              normalized = "INSTRUMENT_TYPE_#{normalized}" unless normalized.start_with?('INSTRUMENT_TYPE_')
              sym = normalized.to_sym
              return sym if VALID_INSTRUMENT_TYPES.include?(sym)
            end

            case proto.class.name
            when /::Currency$/ then :INSTRUMENT_TYPE_CURRENCY
            when /::Future$/ then :INSTRUMENT_TYPE_FUTURES
            when /::Share$/ then :INSTRUMENT_TYPE_SHARE
            when /::Bond$/ then :INSTRUMENT_TYPE_BOND
            when /::Etf$/ then :INSTRUMENT_TYPE_ETF
            when /::Option$/ then :INSTRUMENT_TYPE_OPTION
            when /::StructuredNote$/ then :INSTRUMENT_TYPE_SP
            end
          end
        end

        # Тип инструмента в нормализованном формате `INSTRUMENT_TYPE_*`.
        #
        # @return [Symbol, nil]
        def instrument_type
          @instrument_type ||= resolve_instrument_type(@pb)
        end

        # Минимальный шаг цены в `Float`.
        #
        # @return [Float, nil]
        def min_price_increment
          return @min_price_increment if defined?(@min_price_increment)

          q = @pb&.min_price_increment
          val = q ? TbankGrpc::Converters::Quotation.to_f(q) : nil
          @min_price_increment = val&.positive? ? val : nil
        end

        # Признак возможности обычной биржевой торговли.
        #
        # @return [Boolean]
        def tradable?
          trading_status == :SECURITY_TRADING_STATUS_NORMAL_TRADING
        end

        # Сериализует protobuf в Hash c нормализованными полями.
        #
        # @return [Hash]
        def to_h
          return {} unless @pb

          result = pb_to_h
          result[:instrument_type] = instrument_type
          result[:instrument_uid] = instrument_uid
          result[:lot_size] = result[:lot] if result.key?(:lot)
          result
        end

        private

        def resolve_instrument_type(proto)
          return unless proto

          if proto.respond_to?(:instrument_kind) && proto.instrument_kind
            kind = proto.instrument_kind
            sym = kind.is_a?(Integer) ? INSTRUMENT_KIND_MAP[kind] : kind
            return sym if VALID_INSTRUMENT_TYPES.include?(sym)
          end

          if proto.respond_to?(:instrument_type) && proto.instrument_type
            val = proto.instrument_type
            return val if VALID_INSTRUMENT_TYPES.include?(val)

            res = string_to_instrument_type(val.to_s)
            return res if res
          end

          infer_instrument_type(proto)
        end

        def string_to_instrument_type(s)
          return if s.to_s.strip.empty?

          prefix = 'INSTRUMENT_TYPE_'
          clean_s = s.upcase
          normalized = clean_s.start_with?(prefix) ? clean_s : "#{prefix}#{clean_s}"
          sym = normalized.to_sym
          VALID_INSTRUMENT_TYPES.include?(sym) ? sym : nil
        end

        def infer_instrument_type(proto)
          case proto.class.name
          when /::Currency$/ then :INSTRUMENT_TYPE_CURRENCY
          when /::Future$/ then :INSTRUMENT_TYPE_FUTURES
          when /::Share$/ then :INSTRUMENT_TYPE_SHARE
          when /::Bond$/ then :INSTRUMENT_TYPE_BOND
          when /::Etf$/ then :INSTRUMENT_TYPE_ETF
          when /::Option$/ then :INSTRUMENT_TYPE_OPTION
          when /::StructuredNote$/ then :INSTRUMENT_TYPE_SP
          end
        end
      end
    end
  end
end
