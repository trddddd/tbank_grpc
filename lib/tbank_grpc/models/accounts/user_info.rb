# frozen_string_literal: true

module TbankGrpc
  module Models
    module Accounts
      # Ответ GetInfo: prem_status, qual_status, qualified_for_work_with, tariff, user_id, risk_level_code.
      class UserInfo < BaseModel
        grpc_simple :prem_status, :qual_status, :qualified_for_work_with, :tariff, :user_id, :risk_level_code

        inspectable_attrs :prem_status, :qual_status, :tariff, :user_id
      end
    end
  end
end
