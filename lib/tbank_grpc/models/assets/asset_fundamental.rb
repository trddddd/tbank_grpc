# frozen_string_literal: true

module TbankGrpc
  module Models
    module Assets
      # Фундаментальные показатели по активу (GetAssetFundamentals — элемент fundamentals).
      class AssetFundamental < BaseModel
        grpc_simple :asset_uid, :currency,
                    :market_capitalization, :high_price_last_52_weeks, :low_price_last_52_weeks,
                    :average_daily_volume_last_10_days, :average_daily_volume_last_4_weeks,
                    :beta, :free_float, :forward_annual_dividend_yield, :shares_outstanding,
                    :revenue_ttm, :ebitda_ttm, :net_income_ttm, :eps_ttm, :diluted_eps_ttm,
                    :free_cash_flow_ttm, :five_year_annual_revenue_growth_rate,
                    :three_year_annual_revenue_growth_rate, :pe_ratio_ttm, :price_to_sales_ttm,
                    :price_to_book_ttm, :price_to_free_cash_flow_ttm, :total_enterprise_value_mrq,
                    :ev_to_ebitda_mrq, :net_margin_mrq, :net_interest_margin_mrq,
                    :roe, :roa, :roic, :total_debt_mrq, :total_debt_to_equity_mrq,
                    :total_debt_to_ebitda_mrq, :free_cash_flow_to_price, :net_debt_to_ebitda,
                    :current_ratio_mrq, :fixed_charge_coverage_ratio_fy,
                    :dividend_yield_daily_ttm, :dividend_rate_ttm, :dividends_per_share,
                    :five_years_average_dividend_yield, :five_year_annual_dividend_growth_rate,
                    :dividend_payout_ratio_fy, :buy_back_ttm, :one_year_annual_revenue_growth_rate,
                    :domicile_indicator_code, :adr_to_common_share_ratio, :number_of_employees,
                    :revenue_change_five_years, :eps_change_five_years, :ebitda_change_five_years,
                    :total_debt_change_five_years, :ev_to_sales

        grpc_timestamp :ex_dividend_date, :fiscal_period_start_date, :fiscal_period_end_date

        inspectable_attrs :asset_uid, :currency,
                          :market_capitalization, :total_enterprise_value_mrq,
                          :pe_ratio_ttm, :price_to_book_ttm, :price_to_sales_ttm, :ev_to_ebitda_mrq,
                          :revenue_ttm, :ebitda_ttm, :net_income_ttm, :eps_ttm,
                          :roe, :roa, :net_margin_mrq,
                          :free_float, :dividend_yield_daily_ttm, :dividends_per_share,
                          :high_price_last_52_weeks, :low_price_last_52_weeks, :beta
      end
    end
  end
end
