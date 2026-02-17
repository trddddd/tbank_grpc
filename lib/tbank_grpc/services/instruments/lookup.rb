# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Поиск и получение инструментов по идентификаторам.
      #
      # Содержит обёртки над RPC:
      # `GetInstrumentBy`, `ShareBy`, `BondBy`, `FutureBy`, `FindInstrument`.
      module Lookup
        # Получение инструмента по идентификатору (FIGI, ticker, uid). GetInstrumentBy.
        #
        # @param id_type [Symbol, Integer] тип ID, например :INSTRUMENT_ID_TYPE_FIGI, :figi
        # @param id [String] значение идентификатора
        # @param class_code [String, nil] класс инструмента (опционально)
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Instruments::Instrument, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_instrument_by(id_type:, id:, class_code: nil, return_metadata: false)
          handle_request(method_name: 'InstrumentsService/GetInstrumentBy',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::InstrumentRequest.new(
              id_type: resolve_instrument_id_type(id_type),
              id: id,
              class_code: class_code.to_s
            )

            @logger.debug('GetInstrumentBy request', id_type: id_type, id: id, class_code: class_code)

            response = call_rpc(@stub, :get_instrument_by, request, return_metadata: return_op)
            next response if return_metadata

            Models::Instruments::Instrument.from_grpc(response.instrument)
          end
        end

        # Акция по идентификатору. ShareBy.
        #
        # @param id_type [Symbol, Integer]
        # @param id [String]
        # @param class_code [String, nil]
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Instruments::Instrument, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def share_by(id_type:, id:, class_code: nil, return_metadata: false)
          handle_request(method_name: 'InstrumentsService/ShareBy', return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::InstrumentRequest.new(
              id_type: resolve_instrument_id_type(id_type),
              id: id,
              class_code: class_code.to_s
            )
            @logger.debug('ShareBy request', id_type: id_type, id: id, class_code: class_code)
            response = call_rpc(@stub, :share_by, request, return_metadata: return_op)
            next response if return_metadata

            Models::Instruments::Instrument.from_grpc(response.instrument)
          end
        end

        # Поиск инструментов по текстовому запросу. FindInstrument.
        #
        # @param query [String] строка поиска (тикер, название и т.д.)
        # @param instrument_kind [Symbol, Integer, nil] тип из InstrumentType: :futures, :share, :bond, :instrument_type_futures и т.д.
        # @param api_trade_available_flag [Boolean, nil] только торгуемые через API
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::InstrumentShort>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def find_instrument(query:, instrument_kind: nil, api_trade_available_flag: nil, return_metadata: false)
          handle_request(method_name: 'InstrumentsService/FindInstrument',
                         return_metadata: return_metadata) do |return_op:|
            request_opts = { query: query, api_trade_available_flag: api_trade_available_flag }
            if instrument_kind
              request_opts[:instrument_kind] = resolve_enum(
                Tinkoff::Public::Invest::Api::Contract::V1::InstrumentType,
                instrument_kind,
                prefix: 'INSTRUMENT_TYPE'
              )
            end
            request = Tinkoff::Public::Invest::Api::Contract::V1::FindInstrumentRequest.new(**request_opts)

            @logger.debug('FindInstrument request', query: query)

            response = call_rpc(@stub, :find_instrument, request, return_metadata: return_op)
            next response if return_metadata

            Array(response.instruments).map { |pb| Models::Instruments::InstrumentShort.from_grpc(pb) }
          end
        end

        # Облигация по идентификатору. BondBy.
        #
        # @param id_type [Symbol, Integer] тип идентификатора (`FIGI`, `TICKER`, `UID`, ...)
        # @param id [String] значение идентификатора
        # @param class_code [String, nil] класс инструмента (актуально при поиске по тикеру)
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Instruments::Instrument, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def bond_by(id_type:, id:, class_code: nil, return_metadata: false)
          instrument_by(:bond_by, id_type, id, class_code, return_metadata)
        end

        # Фьючерс по идентификатору. FutureBy.
        #
        # @param id_type [Symbol, Integer] тип идентификатора (`FIGI`, `TICKER`, `UID`, ...)
        # @param id [String] значение идентификатора
        # @param class_code [String, nil] класс инструмента (актуально при поиске по тикеру)
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Instruments::Instrument, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def future_by(id_type:, id:, class_code: nil, return_metadata: false)
          instrument_by(:future_by, id_type, id, class_code, return_metadata)
        end

        private

        def instrument_by(method, id_type, id, class_code, return_metadata)
          handle_request(method_name: "InstrumentsService/#{method}", return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::InstrumentRequest.new(
              id_type: resolve_instrument_id_type(id_type),
              id: id,
              class_code: class_code.to_s
            )
            response = call_rpc(@stub, method, request, return_metadata: return_op)
            next response if return_metadata

            Models::Instruments::Instrument.from_grpc(response.instrument)
          end
        end

        def resolve_instrument_id_type(value)
          return value if value.nil?
          return value if value.is_a?(Integer)

          resolve_enum(Tinkoff::Public::Invest::Api::Contract::V1::InstrumentIdType, value,
                       prefix: 'INSTRUMENT_ID_TYPE')
        end
      end
    end
  end
end
