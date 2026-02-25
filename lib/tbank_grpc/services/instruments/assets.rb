# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Методы по активам: GetAssetBy, GetAssetFundamentals, GetAssetReports.
      module Assets
        # Получить актив по UID. GetAssetBy.
        #
        # @param id [String] UID актива
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо модели
        # @return [Models::Assets::AssetFull, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_asset_by(id:, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::AssetRequest.new(id: id)
          execute_rpc(method_name: :get_asset_by, request: request, return_metadata: return_metadata) do |response|
            Models::Assets::AssetFull.from_grpc(response.asset)
          end
        end

        # Фундаментальные показатели по активу. GetAssetFundamentals.
        #
        # @param assets [Array<String>, String] список UID активов или один UID
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Assets::AssetFundamental>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_asset_fundamentals(assets:, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetAssetFundamentalsRequest.new(
            assets: Array(assets)
          )
          execute_list_rpc(
            method_name: :get_asset_fundamentals,
            request: request,
            response_collection: :fundamentals,
            model_class: Models::Assets::AssetFundamental,
            return_metadata: return_metadata
          )
        end

        # Расписания выхода отчётностей эмитентов. GetAssetReports.
        #
        # @param instrument_id [String] UID/FIGI/другой `instrument_id` эмитента
        # @param from [Time, String, nil]
        # @param to [Time, String, nil]
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Assets::AssetReportEvent>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_asset_reports(instrument_id:, from: nil, to: nil, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetAssetReportsRequest.new(
            instrument_id: instrument_id,
            from: timestamp_to_proto(from),
            to: timestamp_to_proto(to)
          )
          execute_list_rpc(
            method_name: :get_asset_reports,
            request: request,
            response_collection: :events,
            model_class: Models::Assets::AssetReportEvent,
            return_metadata: return_metadata
          )
        end
      end
    end
  end
end
