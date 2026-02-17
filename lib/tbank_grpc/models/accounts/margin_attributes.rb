# frozen_string_literal: true

module TbankGrpc
  module Models
    module Accounts
      # Маржинальные показатели счёта из ответа `GetMarginAttributes`.
      class MarginAttributes < BaseModel
        grpc_money :liquid_portfolio, :starting_margin, :minimal_margin,
                   :amount_of_missing_funds, :corrected_margin
        grpc_quotation :funds_sufficiency_level

        inspectable_attrs :liquid_portfolio, :funds_sufficiency_level
      end
    end
  end
end
