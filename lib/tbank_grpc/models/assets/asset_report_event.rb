# frozen_string_literal: true

module TbankGrpc
  module Models
    module Assets
      # Событие расписания отчётности эмитента (GetAssetReports — элемент events).
      class AssetReportEvent < BaseModel
        grpc_simple :instrument_id, :period_year, :period_num, :period_type
        grpc_timestamp :report_date, :created_at

        inspectable_attrs :instrument_id, :report_date, :period_year, :period_num, :period_type, :created_at
      end
    end
  end
end
