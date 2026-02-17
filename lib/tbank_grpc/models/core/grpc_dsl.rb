# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module GrpcDsl
        def grpc_timestamp(*attr_names)
          attr_names.each do |attr|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{attr}
                return unless @pb.respond_to?(:#{attr})
                ivar = :"@#{attr}"
                return instance_variable_get(ivar) if instance_variable_defined?(ivar)
                raw = @pb.public_send(:#{attr})
                instance_variable_set(ivar, raw ? timestamp_to_time(raw) : nil)
              end
            RUBY
          end
        end

        def grpc_simple(*attr_names)
          attr_names.each do |attr|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{attr}
                @pb.public_send(:#{attr}) if @pb.respond_to?(:#{attr})
              end
            RUBY
          end
        end

        def grpc_simple_with_fallback(attr, fallback:)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{attr}
              if @pb.respond_to?(:#{attr})
                v = @pb.public_send(:#{attr})
                return v unless v.nil? || (v.respond_to?(:empty?) && v.empty?)
              end
              public_send(:#{fallback})
            end
          RUBY
        end

        def grpc_money(*attr_names)
          attr_names.each do |attr|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{attr}
                return unless @pb.respond_to?(:#{attr})
                ivar = :"@#{attr}"
                return instance_variable_get(ivar) if instance_variable_defined?(ivar)
                raw = @pb.public_send(:#{attr})
                instance_variable_set(ivar, raw ? Core::ValueObjects::Money.from_grpc(raw) : nil)
              end
            RUBY
          end
        end

        def grpc_quotation(*attr_names)
          attr_names.each do |attr|
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{attr}
                return unless @pb.respond_to?(:#{attr}) && @pb.#{attr}
                ivar = :"@#{attr}"
                return instance_variable_get(ivar) if instance_variable_defined?(ivar)
                raw = @pb.public_send(:#{attr})
                instance_variable_set(ivar, raw ? Core::ValueObjects::Quotation.from_grpc(raw) : nil)
              end
            RUBY
          end
        end

        def inspectable_attrs_list
          const_defined?(:INSPECTABLE_ATTRS, false) ? self::INSPECTABLE_ATTRS : []
        end

        def inspectable_attrs(*extra)
          base = superclass.respond_to?(:inspectable_attrs_list, true) ? superclass.inspectable_attrs_list : []
          const_set(:INSPECTABLE_ATTRS, (base + extra).uniq.freeze)
        end

        def grpc_alias(new_name, old_name)
          alias_method new_name, old_name
        end

        def instrument_type_predicates(types_constant:)
          const_get(types_constant).each do |type|
            suffix = type.to_s.sub(/\AINSTRUMENT_TYPE_/, '').downcase
            next if suffix.empty?

            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{suffix}?
                instrument_type == :#{type}
              end
            RUBY
          end
        end
      end
    end
  end
end
