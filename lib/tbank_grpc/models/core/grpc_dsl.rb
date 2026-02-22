# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module GrpcDsl
        def _register_serializable_attrs(*names)
          @_serializable_attrs ||= []
          names.each { |n| @_serializable_attrs << n unless @_serializable_attrs.include?(n) }
        end
        private :_register_serializable_attrs

        # Вычисляемые поля, попадающие в to_h: serializable_attr :instrument_uid, :spread
        def serializable_attr(*names)
          _register_serializable_attrs(*names)
        end

        # Собирает поля по цепочке наследования (Future < Instrument < BaseModel), порядок объявления.
        def serializable_attr_names
          ancestors.grep(Class).reverse.flat_map { |k| k.instance_variable_get(:@_serializable_attrs) || [] }.uniq
        end

        def grpc_simple(*attr_names)
          _register_serializable_attrs(*attr_names)
          attr_names.each do |attr|
            define_method(attr) { @pb.public_send(attr) if @pb.respond_to?(attr) }
          end
        end

        def grpc_simple_with_fallback(attr, fallback:)
          _register_serializable_attrs(attr)
          define_method(attr) do
            if @pb.respond_to?(attr)
              v = @pb.public_send(attr)
              return v unless v.nil? || (v.respond_to?(:empty?) && v.empty?)
            end
            public_send(fallback)
          end
        end

        def grpc_timestamp(*attr_names)
          _register_serializable_attrs(*attr_names)
          attr_names.each do |attr|
            ivar = :"@#{attr}"
            define_method(attr) do
              return unless @pb.respond_to?(attr)
              return instance_variable_get(ivar) if instance_variable_defined?(ivar)

              raw = @pb.public_send(attr)
              instance_variable_set(ivar, raw ? timestamp_to_time(raw) : nil)
            end
          end
        end

        def grpc_money(*attr_names)
          _register_serializable_attrs(*attr_names)
          attr_names.each do |attr|
            ivar = :"@#{attr}"
            define_method(attr) do
              return unless @pb.respond_to?(attr)
              return instance_variable_get(ivar) if instance_variable_defined?(ivar)

              raw = @pb.public_send(attr)
              instance_variable_set(ivar, raw ? Core::ValueObjects::Money.from_grpc(raw) : nil)
            end
          end
        end

        def grpc_quotation(*attr_names)
          _register_serializable_attrs(*attr_names)
          attr_names.each do |attr|
            ivar = :"@#{attr}"
            define_method(attr) do
              return unless @pb.respond_to?(attr) && @pb.public_send(attr)
              return instance_variable_get(ivar) if instance_variable_defined?(ivar)

              raw = @pb.public_send(attr)
              instance_variable_set(ivar, raw ? Core::ValueObjects::Quotation.from_grpc(raw) : nil)
            end
          end
        end

        def inspectable_attrs_list
          const_defined?(:INSPECTABLE_ATTRS, false) ? self::INSPECTABLE_ATTRS : []
        end

        def inspectable_attrs(*extra)
          base = superclass.respond_to?(:inspectable_attrs_list, true) ? superclass.inspectable_attrs_list : []
          value = (base + extra).uniq.freeze
          remove_const(:INSPECTABLE_ATTRS) if const_defined?(:INSPECTABLE_ATTRS, false)
          const_set(:INSPECTABLE_ATTRS, value)
        end

        def grpc_alias(new_name, old_name)
          _register_serializable_attrs(new_name)
          alias_method new_name, old_name
        end

        def instrument_type_predicates(types_constant:)
          const_get(types_constant).each do |type|
            suffix = type.to_s.sub(/\AINSTRUMENT_TYPE_/, '').downcase
            next if suffix.empty?

            define_method(:"#{suffix}?") do
              instrument_type == type
            end
          end
        end
      end
    end
  end
end
