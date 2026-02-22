# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      # Рекурсивное преобразование proto-сообщений в Hash; Money/Quotation/Timestamp через конвертеры.
      module ProtobufToHash
        SPECIAL_CONVERTERS = {
          'Money' => TbankGrpc::Converters::Money,
          'MoneyValue' => TbankGrpc::Converters::Money,
          'Quotation' => TbankGrpc::Converters::Quotation
        }.freeze

        # @param pb_msg [Google::Protobuf::Message, nil]
        # @return [Hash<Symbol, Object>] поля в виде символов ключей; вложенные сообщения и
        #   повторяющиеся поля рекурсивно
        def self.pb_message_to_h(pb_msg)
          return {} unless pb_msg

          descriptor = pb_msg.class.descriptor
          result = {}
          field_names = descriptor_field_names(descriptor)
          if field_names.any?
            field_names.each do |name|
              next unless pb_msg.respond_to?(name)

              result[name.to_sym] = transform_field_value(pb_msg.public_send(name))
            end
          elsif pb_msg.respond_to?(:to_h)
            pb_msg.to_h.each { |k, v| result[k.to_sym] = transform_field_value(v) }
          end
          result
        end

        # @param descriptor [Object] дескриптор сообщения
        # @return [Array<String>]
        def self.descriptor_field_names(descriptor)
          return [] unless descriptor

          descriptor.map { |fd| fd.name.to_s }
        rescue NoMethodError => e
          warn "ProtobufToHash: failed to extract field names from descriptor: #{e.message}"
          []
        end

        # @param value [Object] поле proto (примитив, Timestamp, Message, RepeatedField)
        # @return [Object] Ruby-представление (Time, Float, Hash, Array и т.д.)
        def self.transform_field_value(value)
          case value
          when nil
            nil
          when Array, Google::Protobuf::RepeatedField
            value.map { |v| transform_field_value(v) }
          when Google::Protobuf::Timestamp
            TbankGrpc::Converters::Timestamp.to_time(value)
          else
            converted = convert_special_type(value)
            if converted
              converted
            elsif protobuf_message?(value)
              pb_message_to_h(value)
            else
              value
            end
          end
        end

        def self.convert_special_type(value)
          return nil unless value.respond_to?(:units)

          class_suffix = value.class.name.split('::').last
          converter = SPECIAL_CONVERTERS[class_suffix]
          converter&.to_f(value)
        end

        def self.protobuf_message?(value)
          return false if value.nil?
          return true if defined?(Google::Protobuf::Message) && value.is_a?(Google::Protobuf::Message)

          value.class.respond_to?(:descriptor) && value.class.descriptor
        end
      end
    end
  end
end
