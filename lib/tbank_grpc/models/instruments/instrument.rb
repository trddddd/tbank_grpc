# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Универсальная модель инструмента.
      #
      # Используется в ответах:
      # `GetInstrumentBy`, `ShareBy`, `BondBy`, `FutureBy`, `Shares`, `Bonds`, `Futures`.
      class Instrument < BaseModel
        extend Concerns::InstrumentClassMethods

        # Реэкспорт для const_get в макросах (ищет только в предках класса, не в singleton class).
        VALID_INSTRUMENT_TYPES = Concerns::InstrumentClassMethods::VALID_INSTRUMENT_TYPES

        grpc_simple :figi, :ticker, :class_code, :isin,
                    :currency, :name, :uid, :trading_status, :asset_uid
        grpc_simple_with_fallback :instrument_uid, fallback: :uid
        # lot — только для alias lot_size, в реестр не регистрируем
        define_method(:lot) { @pb.lot if @pb.respond_to?(:lot) }
        grpc_alias :lot_size, :lot
        serializable_attr :instrument_type, :min_price_increment

        inspectable_attrs :figi, :ticker, :name, :class_code, :isin,
                          :instrument_type, :currency, :lot_size,
                          :trading_status, :instrument_uid

        instrument_type_predicates types_constant: :VALID_INSTRUMENT_TYPES
        grpc_alias :stock?, :share?

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

        private

        def resolve_instrument_type(proto)
          return unless proto

          self.class.resolve_instrument_type_from_proto(proto)
        end
      end
    end
  end
end
