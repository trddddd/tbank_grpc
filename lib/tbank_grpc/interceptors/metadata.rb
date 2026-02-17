# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    class Metadata < GRPC::ClientInterceptor
      def initialize(token:, app_name:)
        @token = token
        @app_name = app_name
        super()
      end

      %i[request_response client_streamer server_streamer bidi_streamer].each do |rpc_type|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{rpc_type}(**kwargs)
            enrich_metadata(kwargs[:metadata])
            yield
          end
        RUBY
      end

      private

      def enrich_metadata(metadata)
        metadata['authorization'] = "Bearer #{@token}"
        metadata['x-app-name'] = @app_name.to_s
        # x-tracking-id не отправляем: T-Bank добавляет его в ответы сам
      end
    end
  end
end
