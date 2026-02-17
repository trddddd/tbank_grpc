# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Списки инструментов (Shares, Bonds, Futures).
      module Listings
        # Список акций. Shares.
        #
        # @param instrument_status [Symbol, Integer, nil] фильтр по статусу инструмента
        # @param instrument_exchange [Symbol, Integer, nil] фильтр по бирже/режиму листинга
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::Instrument>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def shares(instrument_status: nil, instrument_exchange: nil, return_metadata: false)
          list_instruments(:shares, instrument_status, instrument_exchange, return_metadata)
        end

        # Список облигаций. Bonds.
        #
        # @param instrument_status [Symbol, Integer, nil] фильтр по статусу инструмента
        # @param instrument_exchange [Symbol, Integer, nil] фильтр по бирже/режиму листинга
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::Instrument>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def bonds(instrument_status: nil, instrument_exchange: nil, return_metadata: false)
          list_instruments(:bonds, instrument_status, instrument_exchange, return_metadata)
        end

        # Список фьючерсов. Futures.
        #
        # @param instrument_status [Symbol, Integer, nil] фильтр по статусу инструмента
        # @param instrument_exchange [Symbol, Integer, nil] фильтр по бирже/режиму листинга
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::Instrument>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def futures(instrument_status: nil, instrument_exchange: nil, return_metadata: false)
          list_instruments(:futures, instrument_status, instrument_exchange, return_metadata)
        end

        private

        def list_instruments(method, instrument_status, instrument_exchange, return_metadata)
          handle_request(method_name: "InstrumentsService/#{method.to_s.capitalize}",
                         return_metadata: return_metadata) do |return_op:|
            request = build_instruments_request(instrument_status, instrument_exchange)
            response = call_rpc(@stub, method, request, return_metadata: return_op)
            next response if return_metadata

            response.instruments.map { |item| Models::Instruments::Instrument.from_grpc(item) }
          end
        end

        def build_instruments_request(instrument_status, instrument_exchange)
          opts = { instrument_status: instrument_status, instrument_exchange: instrument_exchange }.compact
          resolved = opts.each_with_object({}) do |(key, value), acc|
            enum_module, prefix = instruments_request_enum_config[key]
            acc[key] = resolve_enum(enum_module, value, prefix: prefix)
          end
          Tinkoff::Public::Invest::Api::Contract::V1::InstrumentsRequest.new(**resolved)
        end

        def instruments_request_enum_config
          @instruments_request_enum_config ||= {
            instrument_status: [
              Tinkoff::Public::Invest::Api::Contract::V1::InstrumentStatus,
              'INSTRUMENT_STATUS'
            ],
            instrument_exchange: [
              Tinkoff::Public::Invest::Api::Contract::V1::InstrumentExchangeType,
              'INSTRUMENT_EXCHANGE'
            ]
          }.freeze
        end
      end
    end
  end
end
