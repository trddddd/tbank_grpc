# frozen_string_literal: true

module TbankGrpc
  module Models
    module MarketData
      # Открытый интерес по инструменту из MarketData stream.
      #
      # @see BaseModel атрибуты и from_grpc
      class OpenInterest < BaseModel
        grpc_simple :instrument_uid, :ticker, :class_code, :open_interest
        grpc_timestamp :time

        inspectable_attrs :instrument_uid, :ticker, :open_interest, :time
      end
    end
  end
end
