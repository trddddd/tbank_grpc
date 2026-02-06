# frozen_string_literal: true

module TbankGrpc
  module Interceptors
    class AuthInterceptor < GRPC::ClientInterceptor
      def initialize(token)
        @token = token
        super()
      end

      def request_response(request:, call:, method:, metadata:)
        metadata['authorization'] = "Bearer #{@token}"
        yield
      end

      def client_streamer(requests:, call:, method:, metadata:)
        metadata['authorization'] = "Bearer #{@token}"
        yield
      end

      def server_streamer(request:, call:, method:, metadata:)
        metadata['authorization'] = "Bearer #{@token}"
        yield
      end

      def bidi_streamer(requests:, call:, method:, metadata:)
        metadata['authorization'] = "Bearer #{@token}"
        yield
      end
    end
  end
end
