# frozen_string_literal: true

module TbankGrpc
  module Helpers
    # Утилитарные методы для типовых сценариев с {Services::InstrumentsService}.
    class InstrumentsHelper
      # @param client [TbankGrpc::Client]
      def initialize(client)
        @client = client
      end

      # Получить инструмент по FIGI.
      #
      # @param figi [String]
      # @return [Models::Instruments::Instrument]
      def get_by_figi(figi)
        @client.instruments.get_instrument_by(
          id_type: Tinkoff::Public::Invest::Api::Contract::V1::InstrumentIdType::INSTRUMENT_ID_TYPE_FIGI,
          id: figi
        )
      end

      # Получить инструмент по UID.
      #
      # @param uid [String]
      # @return [Models::Instruments::Instrument]
      def get_by_uid(uid)
        @client.instruments.get_instrument_by(
          id_type: Tinkoff::Public::Invest::Api::Contract::V1::InstrumentIdType::INSTRUMENT_ID_TYPE_UID,
          id: uid
        )
      end

      # Получить инструмент по position UID.
      #
      # @param position_uid [String]
      # @return [Models::Instruments::Instrument]
      def get_by_position_uid(position_uid)
        @client.instruments.get_instrument_by(
          id_type: Tinkoff::Public::Invest::Api::Contract::V1::InstrumentIdType::INSTRUMENT_ID_TYPE_POSITION_UID,
          id: position_uid
        )
      end

      # Получить инструмент по тикеру и class code.
      #
      # @param ticker [String]
      # @param class_code [String]
      # @return [Models::Instruments::Instrument]
      def get_by_ticker(ticker, class_code:)
        @client.instruments.get_instrument_by(
          id_type: Tinkoff::Public::Invest::Api::Contract::V1::InstrumentIdType::INSTRUMENT_ID_TYPE_TICKER,
          id: ticker,
          class_code: class_code
        )
      end

      # Найти инструмент по тикеру среди всех class code и вернуть «лучшее» совпадение.
      #
      # Приоритет:
      # 1) тикер, совпавший точно и доступный для API-торговли;
      # 2) любое точное совпадение тикера.
      #
      # @param ticker [String]
      # @return [Models::Instruments::Instrument]
      # @raise [TbankGrpc::Error] если инструмент не найден
      def get_by_ticker_any_class(ticker)
        normalized = ticker.to_s.strip.upcase
        shorts = @client.instruments.find_instrument(query: normalized, api_trade_available_flag: false)
        exact = shorts.select { |item| item.ticker.to_s.upcase == normalized }
        chosen = exact.find(&:api_trade_available_flag) || exact.first
        raise TbankGrpc::Error, "Instrument with ticker #{ticker.inspect} not found" if chosen.nil?

        get_by_figi(chosen.figi)
      end

      # Вызов `ShareBy` с заданным типом идентификатора.
      #
      # @param id_type [Symbol, Integer]
      # @param id [String]
      # @param class_code [String, nil]
      # @param return_metadata [Boolean]
      # @return [Models::Instruments::Instrument, TbankGrpc::Response]
      def share_by_id(id_type:, id:, class_code: nil, return_metadata: false)
        @client.instruments.share_by(
          id_type: id_type,
          id: id,
          class_code: class_code,
          return_metadata: return_metadata
        )
      end

      # Получить «сырой» protobuf-массив акций из `Shares`.
      #
      # @param instrument_status [Symbol, Integer, nil]
      # @param instrument_exchange [Symbol, Integer, nil]
      # @return [Array<Google::Protobuf::MessageExts>]
      def shares_raw(instrument_status: nil, instrument_exchange: nil)
        @client.instruments.shares(
          instrument_status: instrument_status,
          instrument_exchange: instrument_exchange,
          return_metadata: true
        ).data.instruments
      end
    end
  end
end
