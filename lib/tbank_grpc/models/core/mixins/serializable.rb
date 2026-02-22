# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module Mixins
        # Сериализация Hash/значений в JSON-дружественный вид (Money, Quotation, Time и т.д.).
        module Serializable
          # @param hash [Hash]
          # @param precision [Symbol, nil] :big_decimal, :float и т.д. для числовых типов
          # @return [Hash]
          def serialize_hash(hash, precision: nil)
            hash.transform_values { |value| serialize_value(value, precision) }
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          def serialize_value(value, precision)
            return value if value.nil?

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
              return value.map { |v| serialize_value(v, precision) } if protobuf_repeated_field?(value)
              return value.to_h.transform_values { |v| serialize_value(v, precision) } if protobuf_map?(value)

              if value.respond_to?(:to_h)
                serialize_object_to_h(value, normalized_precision)
              else
                value
              end
            end
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          private

          def normalize_precision(precision)
            precision == :decimal ? :big_decimal : precision
          end

          def serialize_object_to_h(value, normalized_precision)
            method = value.method(:to_h)
            return value.to_h unless accepts_precision_keyword?(method)

            value.to_h(precision: normalized_precision)
          end

          def accepts_precision_keyword?(method)
            method.parameters.any? { |kind, name| %i[key keyreq].include?(kind) && name == :precision } ||
              method.parameters.any? { |kind, _name| kind == :keyrest }
          end

          def protobuf_repeated_field?(value)
            defined?(Google::Protobuf::RepeatedField) && value.is_a?(Google::Protobuf::RepeatedField)
          end

          def protobuf_map?(value)
            defined?(Google::Protobuf::Map) && value.is_a?(Google::Protobuf::Map)
          end
        end
      end
    end
  end
end
