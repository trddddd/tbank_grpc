# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      module MarketData
        # Server-side stream рыночных данных: один запрос с параметрами подписок — поток ответов.
        #
        # Параметры как у bidi-подписок (instrument_id, interval, depth и т.д.); формат ответа — :proto или :model.
        class ServerStreamService < BaseServerStreamService
          MODEL_REQUIRES_BLOCK_MESSAGE = 'as: :model requires block form for server-side stream'

          # @param channel_manager [ChannelManager]
          # @param config [Hash]
          # @param interceptors [Array<GRPC::ClientInterceptor>]
          def initialize(channel_manager:, config:, interceptors:)
            ProtoLoader.require!('marketdata')
            super
            model_mapper = ::TbankGrpc::Streaming::MarketData::Responses::ModelMapper.new
            @request_builder = ::TbankGrpc::Streaming::MarketData::ServerSide::RequestBuilder.new(
              params_normalizer: ::TbankGrpc::Streaming::MarketData::Subscriptions::ParamsNormalizer,
              model_mapper: model_mapper,
              type_module: type_module
            )
          end

          # Запуск server-side стрима рыночных данных.
          #
          # @param as [Symbol] :proto или :model
          # @param subscription_params [Hash] параметры подписок (instrument_id, interval, depth,
          #   instrument_ids и т.д. — см. RequestBuilder)
          # @yield [payload] для каждого ответа (обязателен при as: :model)
          # @return [Enumerator, nil] при as: :proto без блока — enumerator по ответам
          def market_data_server_side_stream(as: :proto, **subscription_params, &)
            request = @request_builder.build(**subscription_params)
            run_server_side_stream(
              stub: build_stub(@channel_manager.channel),
              rpc_method: :market_data_server_side_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |response, format:|
                @request_builder.convert_response(response, format: format)
              },
              &
            )
          end

          private

          def build_stub(channel)
            type_module::MarketDataStreamService::Stub.new(
              nil,
              :this_channel_is_insecure,
              channel_override: channel,
              interceptors: @interceptors
            )
          end

          def type_module
            Tinkoff::Public::Invest::Api::Contract::V1
          end
        end
      end
    end
  end
end
