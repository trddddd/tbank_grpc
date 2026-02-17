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
          handle_request(method_name: 'InstrumentsService/GetBondCoupons',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::GetBondCouponsRequest.new(
              instrument_id: instrument_id,
              from: timestamp_to_proto(from),
              to: timestamp_to_proto(to)
            )
            response = call_rpc(@stub, :get_bond_coupons, request, return_metadata: return_op)
            next response if return_metadata

            Array(response.events).map { |pb| Models::Instruments::Coupon.from_grpc(pb) }
          end
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
          handle_request(method_name: 'InstrumentsService/GetAccruedInterests',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::GetAccruedInterestsRequest.new(
              instrument_id: instrument_id,
              from: timestamp_to_proto(from),
              to: timestamp_to_proto(to)
            )
            response = call_rpc(@stub, :get_accrued_interests, request, return_metadata: return_op)
            next response if return_metadata

            Array(response.accrued_interests).map { |pb| Models::Instruments::AccruedInterest.from_grpc(pb) }
          end
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
          handle_request(method_name: 'InstrumentsService/GetDividends',
                         return_metadata: return_metadata) do |return_op:|
            request = Tinkoff::Public::Invest::Api::Contract::V1::GetDividendsRequest.new(
              instrument_id: instrument_id,
              from: timestamp_to_proto(from),
              to: timestamp_to_proto(to)
            )
            response = call_rpc(@stub, :get_dividends, request, return_metadata: return_op)
            next response if return_metadata

            Array(response.dividends).map { |pb| Models::Instruments::Dividend.from_grpc(pb) }
          end
        end
      end
    end
  end
end
