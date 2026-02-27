# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      # Базовый класс для server-side stream RPC: один запрос — поток ответов с сервера.
      #
      # Подклассы вызывают {#run_server_side_stream} с stub, методом, request и converter.
      class BaseServerStreamService
        # @return [ChannelManager]
        attr_reader :channel_manager
        # @return [Hash]
        attr_reader :config

        # @param channel_manager [ChannelManager]
        # @param config [Hash]
        # @param interceptors [Array<GRPC::ClientInterceptor>]
        def initialize(channel_manager:, config:, interceptors:)
          @channel_manager = channel_manager
          @config = config
          @interceptors = interceptors
        end

        private

        # Создаёт gRPC stub для канала. Подклассы реализуют.
        # @param channel [GRPC::Core::Channel]
        # @return [Object] gRPC stub
        def initialize_stub(channel)
          raise NotImplementedError, 'Subclasses must implement initialize_stub(channel)'
        end

        # @param stub [Object] gRPC stub
        # @param rpc_method [Symbol] имя RPC-метода (например :market_data_server_side_stream)
        # @param request [Object] proto-запрос
        # @param as [Symbol] :proto или :model — формат payload в consumer
        # @param model_requires_block_message [String] сообщение при as: :model без блока
        # @param converter [Proc] (response, format:) -> payload для consumer
        # @yield [payload] для каждого ответа стрима (обязателен при as: :model)
        # @return [Enumerator, nil] при отсутствии consumer и as: :proto — enumerator по стриму
        # @raise [InvalidArgumentError] при as: :model без блока
        # rubocop:disable Metrics/ParameterLists
        def run_server_side_stream(
          stub:,
          rpc_method:,
          request:,
          as:,
          model_requires_block_message:,
          converter:,
          &consumer
        )
          # rubocop:enable Metrics/ParameterLists
          format = TbankGrpc::Normalizers::PayloadFormatNormalizer.normalize(as)
          method_full_name = Grpc::MethodName.full_name(stub, rpc_method)
          deadline = stream_deadline(method_full_name)
          stream = stub.public_send(rpc_method, request, metadata: {}, deadline: deadline)

          return stream if consumer.nil? && format == :proto

          raise InvalidArgumentError, model_requires_block_message if consumer.nil?

          stream.each do |response|
            payload = converter.call(response, format: format)
            next if payload.nil?

            consumer.call(payload)
          end
        rescue Interrupt
          TbankGrpc.logger.info('Server-side stream stopped by interrupt')
        rescue GRPC::Cancelled => e
          TbankGrpc.logger.debug('Server-side stream cancelled', error: e.message)
        end

        # @param method_full_name [String, Symbol]
        # @return [Time, nil] deadline из config[:deadline_overrides], DEFAULT_DEADLINES по сервису или nil
        def stream_deadline(method_full_name)
          overrides = @config[:deadline_overrides] || {}
          seconds = overrides[method_full_name] ||
                    overrides[method_full_name.to_s] ||
                    overrides[method_full_name.to_sym]
          service_name = method_full_name.to_s.split('/').first
          seconds ||= Grpc::DeadlineResolver::DEFAULT_DEADLINES[service_name]
          return nil if seconds.nil?

          Time.now + seconds.to_f
        end
      end
    end
  end
end
