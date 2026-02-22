# frozen_string_literal: true

require 'bigdecimal'

module TbankGrpc
  module Converters
    # Константы для units/nano (Quotation, MoneyValue): делители 1e9.
    # NANO_DIVISOR (Float), NANO_DIVISOR_BD (BigDecimal).
    module Constants
      NANO_DIVISOR = 1_000_000_000.0
      NANO_DIVISOR_BD = BigDecimal('1000000000')
    end
  end
end
