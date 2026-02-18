# frozen_string_literal: true

module TbankGrpc
  module Models
    # Базовая модель-обёртка над protobuf сообщением.
    #
    # Предоставляет DSL-методы доступа к полям, сериализацию и pretty-print.
    class BaseModel
      extend Core::GrpcDsl
      include Core::Mixins::PrettyPrint
      include Core::Mixins::Serializable
      include Core::ProtobufToHash

      # Исходный protobuf-объект.
      #
      # @return [Google::Protobuf::MessageExts, nil]
      attr_reader :pb

      # Преобразование protobuf в Hash.
      #
      # @param proto [Google::Protobuf::MessageExts, nil]
      # @return [Hash]
      def pb_to_h(proto = @pb)
        return {} unless proto

        Core::ProtobufToHash.pb_message_to_h(proto)
      end

      # Сериализация текущего объекта в Hash.
      #
      # @return [Hash]
      def to_h
        return {} unless @pb

        pb_to_h.compact
      end

      # Хэш атрибутов (удобно для сериализации, логов, совместимости с ожиданиями из Rails/ActiveModel).
      #
      # @return [Hash]
      def attributes
        to_h
      end

      # Фабрика модели из protobuf.
      #
      # @param proto [Google::Protobuf::MessageExts, nil]
      # @return [BaseModel]
      def self.from_grpc(proto)
        new(proto)
      end

      # @param proto [Google::Protobuf::MessageExts, nil]
      def initialize(proto = nil)
        @pb = proto
      end

      def inspect
        attrs = inspectable_attributes
        attrs_str = attrs.any? ? inspection_string(attrs) : ''
        "#<#{inspect_short_name} #{attrs_str}>"
      end

      def inspection_string(attrs)
        attrs.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
      end

      def inspect_short_name
        self.class.name.split('::').last
      end

      def inspectable_attributes
        list = self.class.inspectable_attrs_list
        return {} if list.nil? || list.empty?

        list.each_with_object({}) do |attr_name, result|
          value = public_send(attr_name)
          next unless value

          result[attr_name] = Formatters::InspectableValue.format(value)
        end
      end

      private

      def timestamp_to_time(timestamp)
        TbankGrpc::Converters::Timestamp.to_time(timestamp)
      end
    end
  end
end
