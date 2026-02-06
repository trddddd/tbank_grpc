# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    class AppNameInterceptor < GRPC::ClientInterceptor
      def initialize(app_name)
        @app_name = app_name
        super()
      end

      def request_response(request:, call:, method:, metadata:)
        metadata['x-app-name'] = @app_name
        yield
      end

      def client_streamer(requests:, call:, method:, metadata:)
        metadata['x-app-name'] = @app_name
        yield
      end

      def server_streamer(request:, call:, method:, metadata:)
        metadata['x-app-name'] = @app_name
        yield
      end

      def bidi_streamer(requests:, call:, method:, metadata:)
        metadata['x-app-name'] = @app_name
        yield
      end
    end
  end
end
