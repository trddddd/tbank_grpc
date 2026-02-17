# frozen_string_literal: true

module TbankGrpc
  module Models
    module Assets
      # Бренд/эмитент, связанный с активом.
      class Brand < BaseModel
        grpc_simple :uid, :name, :description, :info, :company, :sector,
                    :country_of_risk, :country_of_risk_name

        inspectable_attrs :uid, :name, :company, :sector
      end
    end
  end
end
