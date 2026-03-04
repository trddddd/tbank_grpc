# frozen_string_literal: true

module TbankGrpc
  module Models
    module Operations
      # Страница ответа GetOperationsByCursor.
      class OperationsByCursorPage < BaseModel
        grpc_simple :has_next, :next_cursor
        serializable_attr :items, :items_count

        inspectable_attrs :has_next, :next_cursor, :items_count

        # Операции страницы.
        #
        # @return [Array<OperationItem>]
        def items
          @items ||= Array(@pb&.items).map { |item| OperationItem.from_grpc(item) }
        end

        # Количество элементов в текущей странице.
        #
        # @return [Integer]
        def items_count
          items.size
        end
      end
    end
  end
end
