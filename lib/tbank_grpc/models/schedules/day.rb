# frozen_string_literal: true

module TbankGrpc
  module Models
    module Schedules
      # Один день из расписания торгов (TradingSchedules).
      class Day < BaseModel
        grpc_simple :is_trading_day
        grpc_timestamp :date, :start_time, :end_time,
                       :opening_auction_start_time, :opening_auction_end_time,
                       :closing_auction_start_time, :closing_auction_end_time,
                       :evening_opening_auction_start_time, :evening_start_time, :evening_end_time,
                       :clearing_start_time, :clearing_end_time,
                       :premarket_start_time, :premarket_end_time
        serializable_attr :intervals
        inspectable_attrs :date, :is_trading_day, :start_time, :end_time, :intervals

        # Список внутридневных интервалов торгов.
        #
        # @return [Array<Interval>]
        def intervals
          Array(@pb&.intervals).map { |i| Interval.from_grpc(i) }
        end
      end
    end
  end
end
