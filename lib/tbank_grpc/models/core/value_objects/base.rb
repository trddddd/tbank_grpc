# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module ValueObjects
        class Base
          include Comparable
          include Core::Mixins::PrettyPrint

          def initialize(**attrs)
            attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
            freeze
          end

          def to_h
            instance_variables.each_with_object({}) do |var, hash|
              hash[var.to_s.delete('@').to_sym] = instance_variable_get(var)
            end
          end

          def ==(other)
            other.is_a?(self.class) && to_h == other.to_h
          end

          def hash
            to_h.hash
          end

          def <=>(other)
            return unless other.is_a?(self.class)

            to_s <=> other.to_s
          end

          def to_s
            to_h.to_s
          end

          def inspect
            "#<#{inspect_short_name} #{self}>"
          end

          private

          def inspectable_attributes
            to_h
          end

          def inspect_short_name
            self.class.name.split('::').last
          end
        end
      end
    end
  end
end
