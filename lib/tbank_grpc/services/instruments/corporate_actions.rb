# frozen_string_literal: true

module TbankGrpc
  module Services
    module Instruments
      # Корпоративные действия: купоны, дивиденды, НКД.
      module CorporateActions
        # График выплат купонов по облигации. GetBondCoupons.
        #
        # @param instrument_id [String]
        # @param from [Time, String, nil] начало периода (UTC), фильтр по coupon_date
        # @param to [Time, String, nil] конец периода (UTC)
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::Coupon>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_bond_coupons(instrument_id:, from: nil, to: nil, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetBondCouponsRequest.new(
            instrument_id: instrument_id,
            from: timestamp_to_proto(from),
            to: timestamp_to_proto(to)
          )
          execute_list_rpc(
            method_name: :get_bond_coupons,
            request: request,
            response_collection: :events,
            model_class: Models::Instruments::Coupon,
            return_metadata: return_metadata
          )
        end

        # Накопленный купонный доход по облигации. GetAccruedInterests.
        #
        # @param instrument_id [String]
        # @param from [Time, String, nil]
        # @param to [Time, String, nil]
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::AccruedInterest>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_accrued_interests(instrument_id:, from: nil, to: nil, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetAccruedInterestsRequest.new(
            instrument_id: instrument_id,
            from: timestamp_to_proto(from),
            to: timestamp_to_proto(to)
          )
          execute_list_rpc(
            method_name: :get_accrued_interests,
            request: request,
            response_collection: :accrued_interests,
            model_class: Models::Instruments::AccruedInterest,
            return_metadata: return_metadata
          )
        end

        # События выплаты дивидендов по инструменту. GetDividends.
        #
        # @param instrument_id [String]
        # @param from [Time, String, nil]
        # @param to [Time, String, nil]
        # @param return_metadata [Boolean] вернуть {TbankGrpc::Response} вместо массива моделей
        # @return [Array<Models::Instruments::Dividend>, TbankGrpc::Response]
        # @raise [TbankGrpc::Error]
        def get_dividends(instrument_id:, from: nil, to: nil, return_metadata: false)
          request = Tinkoff::Public::Invest::Api::Contract::V1::GetDividendsRequest.new(
            instrument_id: instrument_id,
            from: timestamp_to_proto(from),
            to: timestamp_to_proto(to)
          )
          execute_list_rpc(
            method_name: :get_dividends,
            request: request,
            response_collection: :dividends,
            model_class: Models::Instruments::Dividend,
            return_metadata: return_metadata
          )
        end
      end
    end
  end
end
