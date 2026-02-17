# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Свеча по инструменту из ответа `GetCandles`.
      class Candle < BaseModel
        grpc_simple :figi, :volume, :is_complete
        grpc_quotation :open, :high, :low, :close
        grpc_timestamp :time

        inspectable_attrs :figi, :time, :open, :high, :low, :close, :volume, :is_complete

        # Создать модель из protobuf-свечи.
        #
        # @param proto_candle [Google::Protobuf::MessageExts, nil]
        # @param instrument_id [String, nil] явный instrument UID/ID (приоритетнее protobuf-поля)
        # @return [Candle]
        def self.from_grpc(proto_candle, instrument_id: nil)
          new(proto_candle, instrument_id: instrument_id)
        end

        # @param proto_candle [Google::Protobuf::MessageExts, nil]
        # @param instrument_id [String, nil]
        def initialize(proto_candle = nil, instrument_id: nil)
          super(proto_candle)
          @instrument_id_override = instrument_id
          compute_derived_values if @pb
        end

        # Идентификатор инструмента (override из коллекции или значение protobuf).
        #
        # @return [String, nil]
        def instrument_uid
          @instrument_id_override || @pb&.instrument_uid
        end

        # OHLC в виде массива значений.
        #
        # @param precision [Symbol] :float или :decimal
        # @return [Array<Float, BigDecimal, nil>]
        def ohlc(precision: :float)
          @ohlc_cache ||= {}
          @ohlc_cache[precision] ||= begin
            result = calculate_ohlc(precision == :float ? :to_f : :to_d)
            precision == :decimal ? result.freeze : result
          end
        end

        # OHLC в `BigDecimal`.
        #
        # @return [Array<BigDecimal, nil>]
        def ohlc_decimals
          ohlc(precision: :decimal)
        end

        # Размер тела свечи `|close - open|`.
        #
        # @return [BigDecimal, nil]
        def body_size
          return unless open && close

          @body_size ||= (close.to_d - open.to_d).abs
        end

        # Верхняя тень свечи.
        #
        # @return [BigDecimal, nil]
        def upper_shadow
          return unless open && high && close

          @upper_shadow ||= high.to_d - [open.to_d, close.to_d].max
        end

        # Нижняя тень свечи.
        #
        # @return [BigDecimal, nil]
        def lower_shadow
          return unless open && low && close

          @lower_shadow ||= [open.to_d, close.to_d].min - low.to_d
        end

        # Типичная цена `(high + low + close) / 3`.
        #
        # @return [BigDecimal, nil]
        def typical_price
          @typical_price ||= (high.to_d + low.to_d + close.to_d) / 3 if high && low && close
        end

        # Сериализация свечи в Hash.
        #
        # @param precision [Symbol, nil] формат цен (open/high/low/close):
        #   nil — Float, :big_decimal/:decimal — BigDecimal
        # @return [Hash]
        def to_h(precision: nil)
          return {} unless @pb

          serialize_hash({
                           figi: figi,
                           instrument_uid: instrument_uid,
                           time: time,
                           open: open,
                           high: high,
                           low: low,
                           close: close,
                           volume: volume,
                           is_complete: is_complete
                         }, precision: precision)
        end

        # Проверка корректности данных свечи.
        #
        # @return [Boolean]
        def valid?
          identifier? && required_fields? && valid_ohlc_relationship?
        end

        private

        def compute_derived_values
          @typical_price = (high.to_d + low.to_d + close.to_d) / 3 if high && low && close
        end

        def calculate_ohlc(converter)
          [open, high, low, close].map { |v| v&.public_send(converter) }
        end

        def identifier?
          figi.to_s != '' || instrument_uid.to_s != ''
        end

        def required_fields?
          [time, open, high, low, close].all?
        end

        def valid_ohlc_relationship?
          return true unless required_fields?

          high_val = high.to_d
          low_val = low.to_d
          [open.to_d, close.to_d].all? { |price| price.between?(low_val, high_val) }
        end
      end
    end
  end
end
