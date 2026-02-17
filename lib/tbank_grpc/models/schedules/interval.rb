# frozen_string_literal: true

module TbankGrpc
  module Models
    module Schedules
      # Торговый интервал дня (type + начало/конец по UTC).
      class Interval < BaseModel
        # Тип интервала из protobuf (`MAIN`, `PREMARKET`, ...).
        #
        # @return [String, Symbol, Integer, nil]
        def type
          @pb&.type
        end

        # Время начала интервала.
        #
        # @return [Time, nil]
        def start_time
          return unless @pb&.interval&.start_ts

          timestamp_to_time(@pb.interval.start_ts)
        end

        # Время окончания интервала.
        #
        # @return [Time, nil]
        def end_time
          return unless @pb&.interval&.end_ts

          timestamp_to_time(@pb.interval.end_ts)
        end

        inspectable_attrs :type, :start_time, :end_time
      end
    end
  end
end
