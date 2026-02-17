# frozen_string_literal: true

require 'date'

module TbankGrpc
  module Formatters
    class InspectableValue
      def self.format(value)
        new(value).format
      end

      def initialize(value)
        @value = value
      end

      def format
        case @value
        when Models::Core::ValueObjects::Money
          @value.to_s
        when Models::Core::ValueObjects::Quotation
          @value.to_f
        when Time
          @value.strftime('%Y-%m-%d %H:%M:%S')
        when Date, DateTime
          @value.strftime('%Y-%m-%d')
        when Float
          @value.round(8)
        else
          @value
        end
      end
    end
  end
end
