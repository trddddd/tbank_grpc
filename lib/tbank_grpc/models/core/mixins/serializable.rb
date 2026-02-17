# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module Mixins
        module Serializable
          def serialize_hash(hash, precision: nil)
            hash.transform_values { |value| serialize_value(value, precision) }
          end

          def serialize_value(value, precision)
            normalized_precision = normalize_precision(precision)

            case value
            when Core::ValueObjects::Money
              value.to_h(precision: normalized_precision)
            when Core::ValueObjects::Quotation
              normalized_precision == :big_decimal ? value.to_d : value.to_f
            when Time
              value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
            when Array
              value.map { |v| serialize_value(v, precision) }
            when Hash
              value.transform_values { |v| serialize_value(v, precision) }
            else
              value
            end
          end

          private

          def normalize_precision(precision)
            precision == :decimal ? :big_decimal : precision
          end
        end
      end
    end
  end
end
