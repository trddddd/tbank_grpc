# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Накопленный купонный доход по облигации (`GetAccruedInterests`).
      class AccruedInterest < BaseModel
        grpc_quotation :value, :value_percent, :nominal
        grpc_timestamp :date

        inspectable_attrs :date, :value, :value_percent, :nominal
      end
    end
  end
end
