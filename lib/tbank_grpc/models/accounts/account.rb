# frozen_string_literal: true

module TbankGrpc
  module Models
    module Accounts
      # Счёт пользователя из ответа GetAccounts.
      #
      # @see BaseModel атрибуты и from_grpc
      class Account < BaseModel
        grpc_simple :id, :type, :name, :status, :access_level
        grpc_timestamp :opened_date, :closed_date

        inspectable_attrs :id, :type, :name, :status
      end
    end
  end
end
