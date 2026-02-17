# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Методы по торговым расписаниям.
      module Schedules
        # Расписания торговых площадок. TradingSchedules. Без параметров — по всем площадкам.
        #
        # @param exchange [String, nil] код площадки
        # @param from [Time, String, nil] начало периода (UTC)
        # @param to [Time, String, nil] конец периода (UTC)
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Schedules::Schedule>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def trading_schedules(exchange: nil, from: nil, to: nil, return_metadata: false)
          handle_request(method_name: 'InstrumentsService/TradingSchedules',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::TradingSchedulesRequest.new(
              exchange: exchange,
              from: timestamp_to_proto(from),
              to: timestamp_to_proto(to)
            )
            response = call_rpc(@stub, :trading_schedules, request, return_metadata: return_op)
            next response if return_metadata

            response.exchanges.map { |schedule| Models::Schedules::Schedule.from_grpc(schedule) }
          end
        end
      end
    end
  end
end
