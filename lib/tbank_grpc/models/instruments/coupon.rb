# frozen_string_literal: true

module TbankGrpc
  module Models
    module Instruments
      # Купон облигации (GetBondCoupons — элемент events).
      class Coupon < BaseModel
        grpc_simple :figi, :coupon_number, :coupon_type, :coupon_period
        grpc_money :pay_one_bond
        grpc_timestamp :coupon_date, :fix_date, :coupon_start_date, :coupon_end_date

        inspectable_attrs :figi, :coupon_date, :coupon_number, :coupon_type, :pay_one_bond, :coupon_period
      end
    end
  end
end
