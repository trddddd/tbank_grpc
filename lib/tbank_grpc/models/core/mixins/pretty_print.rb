# frozen_string_literal: true

module TbankGrpc
  module Models
    module Core
      module Mixins
        # Подмешивается в модели для вывода в pp/inspect по inspectable_attributes.
        module PrettyPrint
          # @param pp [PP]
          # @return [void]
          def pretty_print(pp)
            pp.object_address_group(self) do
              attrs = respond_to?(:inspectable_attributes, true) ? inspectable_attributes : {}
              pp.seplist(attrs, proc { pp.text ',' }) do |(key, value)|
                pp.breakable ' '
                pp.group(1) do
                  pp.text key.to_s
                  pp.text ':'
                  pp.breakable
                  pp.pp value
                end
              end
            end
          end
        end
      end
    end
  end
end
