# frozen_string_literal: true

module TbankGrpc
  module Models
    module Schedules
      # Расписание одной торговой площадки (TradingSchedules).
      class Schedule < BaseModel
        # @return [String, nil] код биржи/площадки
        attr_reader :exchange, :days

        serializable_attr :exchange, :days

        inspectable_attrs :exchange, :days

        # @param proto [Google::Protobuf::MessageExts, nil]
        def initialize(proto = nil)
          super
          @exchange = proto&.exchange
          @days = Array(proto&.days).map { |day| Day.from_grpc(day) }
        end
      end
    end
  end
end
