# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module Operations
      module Responses
        # Конвертация proto-ответов операционных стримов в доменные модели.
        #
        # @param stream_type [Symbol] :portfolio, :positions или :operations
        class ResponseConverter
          # @param response [Object] proto-ответ стрима
          # @param format [Symbol] :proto или :model
          # @param stream_type [Symbol] :portfolio, :positions или :operations
          # @return [Object, nil] модель, proto-ответ или nil (пропустить)
          def convert_response(response, format:, stream_type:)
            return response if format == :proto

            case stream_type
            when :portfolio  then convert_portfolio(response)
            when :positions  then convert_positions(response)
            when :operations then convert_operations(response)
            end
          end

          private

          def convert_portfolio(response)
            Models::Operations::Portfolio.from_grpc(response.portfolio) if response.payload == :portfolio
          end

          def convert_positions(response)
            if response.payload == :position
              Models::Operations::PositionData.from_grpc(response.position)
            elsif response.payload == :initial_positions
              Models::Operations::Positions.from_grpc(response.initial_positions)
            end
          end

          def convert_operations(response)
            Models::Operations::OperationData.from_grpc(response.operation) if response.payload == :operation
          end
        end
      end
    end
  end
end
