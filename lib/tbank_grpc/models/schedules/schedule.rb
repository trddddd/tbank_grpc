# frozen_string_literal: true

module TbankGrpc
  module Models
    module Schedules
      # Расписание одной торговой площадки (TradingSchedules).
      class Schedule < BaseModel
        # @return [String, nil] код биржи/площадки
        attr_reader :exchange, :days

        inspectable_attrs :exchange, :days

        # @param pb [Google::Protobuf::MessageExts, nil]
        def initialize(pb = nil)
          super
          @exchange = pb&.exchange
          @days = Array(pb&.days).map { |d| Day.from_grpc(d) }
        end
      end
    end
  end
end
