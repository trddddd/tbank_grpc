# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Портфель по счёту из GetPortfolio.
      class Portfolio < BaseModel
        grpc_simple :account_id
        grpc_money :total_amount_shares, :total_amount_bonds, :total_amount_etf,
                   :total_amount_currencies, :total_amount_futures, :total_amount_options,
                   :total_amount_sp, :total_amount_portfolio, :daily_yield
        grpc_quotation :expected_yield, :daily_yield_relative
        serializable_attr :positions, :virtual_positions

        inspectable_attrs :account_id, :total_amount_portfolio, :positions

        # Позиции портфеля (лениво из proto).
        #
        # @return [Array<PortfolioPosition>]
        def positions
          @positions ||= Array(@pb&.positions).map { |p| PortfolioPosition.from_grpc(p) }
        end

        # Виртуальные позиции (лениво, массив хэшей для сериализации).
        #
        # @return [Array<Hash>]
        def virtual_positions
          @virtual_positions ||= Array(@pb&.virtual_positions).map { |vp| virtual_position_to_h(vp) }
        end

        # Сумма портфеля в Float (total_amount_portfolio).
        #
        # @return [Float, nil]
        def total
          total_amount_portfolio&.to_f
        end

        private

        def virtual_position_to_h(virtual_position)
          quantity = Core::ValueObjects::Quotation.from_grpc(virtual_position.quantity).to_f
          {
            position_uid: virtual_position.position_uid,
            instrument_uid: virtual_position.instrument_uid,
            figi: virtual_position.figi,
            instrument_type: virtual_position.instrument_type,
            quantity: quantity,
            ticker: virtual_position.ticker,
            class_code: virtual_position.class_code
          }.compact
        end
      end
    end
  end
end
