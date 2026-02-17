# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Модель акции.
      #
      # Может возвращаться как конкретный тип при `ShareBy`, `Shares`, `GetInstrumentBy`.
      class Share < Instrument
        inspectable_attrs :sector, :nominal, :ipo_date
        grpc_simple :sector, :share_type, :issue_size, :issue_size_plan, :country_of_risk,
                    :country_of_risk_name, :div_yield_flag
        grpc_money :nominal
        grpc_timestamp :ipo_date, :first_1min_candle_date, :first_1day_candle_date
        grpc_quotation :dlong_client, :dshort_client
      end
    end
  end
end
