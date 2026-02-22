# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Модель облигации.
      #
      # Может возвращаться как конкретный тип при BondBy, Bonds, GetInstrumentBy.
      # @see Instrument базовые поля
      class Bond < Instrument
        grpc_simple :coupon_quantity_per_year, :sector, :country_of_risk, :country_of_risk_name,
                    :floating_coupon_flag, :perpetual_flag, :amortization_flag, :issue_size,
                    :issue_kind, :bond_type, :issue_size_plan
        grpc_money :nominal, :initial_nominal, :aci_value, :placement_price
        grpc_quotation :dlong_client, :dshort_client
        grpc_timestamp :maturity_date, :placement_date, :state_reg_date, :call_date

        inspectable_attrs :nominal, :maturity_date, :coupon_quantity_per_year,
                          :sector, :floating_coupon_flag, :perpetual_flag
      end
    end
  end
end
