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

      # Преобразование protobuf-сообщения в Hash «как есть» (все поля из дескриптора).
      # Конвертация типов: MoneyValue/Quotation → Float, Timestamp → Time, вложенные сообщения → Hash.
      # Не использует реестр _serializable_attrs и не поддерживает precision.
      #
      # Используется: 1) как fallback в {#to_h}, когда у класса нет зарегистрированных атрибутов;
      # 2) при явном вызове для отладки или дампа произвольного proto без модели.
      #
      # @param proto [Google::Protobuf::MessageExts, nil] сообщение (по умолчанию текущий pb)
      # @return [Hash]
      def pb_to_h(proto = @pb)
        return {} unless proto

        Core::ProtobufToHash.pb_message_to_h(proto)
      end

      # Сериализация в Hash для JSON/логов/API.
      #
      # Два пути:
      # - **По реестру:** если у класса есть зарегистрированные атрибуты (grpc_simple, grpc_money,
      #   serializable_attr и т.д.), в хэш попадают только они; значения проходят через {TbankGrpc::Models::Core::Mixins::Serializable}
      #   с поддержкой precision для денег и котировок.
      # - **Fallback:** если реестр пуст (класс не объявлял атрибуты через DSL), возвращается
      #   полный дамп proto через {#pb_to_h} — все поля из дескриптора, без precision.
      #
      # В геме все модели объявляют атрибуты через DSL; fallback срабатывает только для подклассов
      # без вызовов grpc_* / serializable_attr (например, минимальный wrapper или Class.new(BaseModel)).
      #
      # @param precision [Symbol, nil] формат денежных/ценовых полей (nil, :big_decimal, :decimal)
      # @return [Hash]
      def to_h(precision: nil)
        return {} unless @pb

        names = self.class.serializable_attr_names
        return pb_to_h.compact if names.empty?

        hash = names.each_with_object({}) do |attr, h|
          h[attr] = public_send(attr) if respond_to?(attr)
        end
        serialize_hash(hash, precision: precision)
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
