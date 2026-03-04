# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Orders
      module Responses
        # Конвертация proto-ответов ордерных стримов.
        #
        # В model-режиме передаются только целевые payload, ping/subscription пропускаются.
        class ResponseConverter
          # @param response [Object] proto-ответ стрима
          # @param format [Symbol] :proto или :model
          # @param stream_type [Symbol] :trades или :order_state
          # @return [Object, nil] payload, proto-ответ или nil (пропустить)
          def convert_response(response, format:, stream_type:)
            return response if format == :proto

            case stream_type
            when :trades      then convert_trades(response)
            when :order_state then convert_order_state(response)
            end
          end

          private

          def convert_trades(response)
            return unless response.payload == :order_trades

            Models::Orders::OrderTrades.from_grpc(response.order_trades)
          end

          def convert_order_state(response)
            return unless response.payload == :order_state

            Models::Orders::OrderStreamState.from_grpc(response.order_state)
          end
        end
      end
    end
  end
end
