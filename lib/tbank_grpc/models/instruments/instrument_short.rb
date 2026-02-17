# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Короткая карточка инструмента из `FindInstrument`.
      class InstrumentShort < BaseModel
        grpc_simple :isin, :figi, :ticker, :class_code, :instrument_type, :name,
                    :uid, :position_uid, :instrument_kind,
                    :api_trade_available_flag, :for_iis_flag, :for_qual_investor_flag,
                    :weekend_flag, :blocked_tca_flag, :lot

        grpc_timestamp :first_1min_candle_date, :first_1day_candle_date

        inspectable_attrs :figi, :ticker, :name, :class_code, :instrument_type,
                          :api_trade_available_flag, :lot
      end
    end
  end
end
