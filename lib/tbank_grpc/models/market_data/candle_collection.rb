# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Коллекция свечей по инструменту.
      class CandleCollection < BaseModel
        include Enumerable

        # @return [Array<Candle>] свечи коллекции
        # @return [String, nil] идентификатор инструмента
        attr_reader :candles, :instrument_id

        # Создать коллекцию свечей из protobuf-массива.
        #
        # @param proto_candles [Array<Google::Protobuf::MessageExts>]
        # @param instrument_id [String, nil]
        # @return [CandleCollection]
        def self.from_grpc(proto_candles, instrument_id: nil)
          candle_objects = proto_candles.map { |c| Candle.from_grpc(c, instrument_id: instrument_id) }
          new(candle_objects, instrument_id: instrument_id)
        end

        # @param candles [Array<Candle>, Candle]
        # @param instrument_id [String, nil]
        # Коллекция не оборачивает proto напрямую (pb всегда nil), to_h реализован вручную.
        def initialize(candles = [], instrument_id: nil)
          super(nil)
          @candles = Array(candles)
          @instrument_id = instrument_id
        end

        inspectable_attrs :candles_count, :instrument_id

        # Количество свечей.
        #
        # @return [Integer]
        def candles_count
          @candles.size
        end

        # Итерация по свечам.
        #
        # @yieldparam candle [Candle]
        # @return [Enumerator, Array<Candle>]
        def each(&)
          @candles.each(&)
        end

        # Размер коллекции.
        #
        # @return [Integer]
        def length
          @candles.length
        end

        alias size length

        # Пустая ли коллекция.
        #
        # @return [Boolean]
        def empty?
          @candles.empty?
        end

        # Доступ к свече по индексу.
        #
        # @param index [Integer]
        # @return [Candle, nil]
        def [](index)
          @candles[index]
        end

        # Первая свеча.
        #
        # @return [Candle, nil]
        def first
          @candles.first
        end

        # Последняя свеча.
        #
        # @return [Candle, nil]
        def last
          @candles.last
        end

        # Открытия свечей.
        #
        # @return [Array<Float, nil>]
        def prices_open
          @prices_open ||= @candles.map { |c| c.open&.to_f }
        end

        # Закрытия свечей.
        #
        # @return [Array<Float, nil>]
        def prices_close
          @prices_close ||= @candles.map { |c| c.close&.to_f }
        end

        # Максимумы свечей.
        #
        # @return [Array<Float, nil>]
        def prices_high
          @prices_high ||= @candles.map { |c| c.high&.to_f }
        end

        # Минимумы свечей.
        #
        # @return [Array<Float, nil>]
        def prices_low
          @prices_low ||= @candles.map { |c| c.low&.to_f }
        end

        # Объёмы свечей.
        #
        # @return [Array<Integer, nil>]
        def volumes
          @candles.map(&:volume)
        end

        # Фильтрация свечей по временному диапазону.
        #
        # @param from_time [Time]
        # @param to_time [Time]
        # @return [CandleCollection]
        def between(from_time, to_time)
          filtered = @candles.select { |c| c.time&.between?(from_time, to_time) }
          self.class.new(filtered, instrument_id: instrument_id)
        end

        # Сортировка свечей по времени.
        #
        # @param order [Symbol] :asc или :desc
        # @return [CandleCollection]
        def sort_by_time(order: :asc)
          sorted = @candles.sort_by { |c| c.time || Time.at(0) }
          sorted.reverse! if order == :desc
          self.class.new(sorted, instrument_id: instrument_id)
        end

        # Сериализация коллекции в Hash (реестр BaseModel не используется, pb всегда nil).
        #
        # @param precision [Symbol, nil] формат цен: nil — Float, :big_decimal или :decimal — BigDecimal
        # @return [Hash]
        def to_h(precision: nil)
          {
            instrument_id: instrument_id,
            candles: @candles.map { |c| c.to_h(precision: precision) }
          }
        end

        # Сериализация свечей в массив Hash (не переопределяем Enumerable#to_a).
        #
        # @param precision [Symbol, nil] формат цен: nil — Float, :big_decimal или :decimal — BigDecimal
        # @return [Array<Hash>]
        def serialize_candles(precision: nil)
          @candles.map { |c| c.to_h(precision: precision) }
        end
      end
    end
  end
end
