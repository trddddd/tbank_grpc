# frozen_string_literal: true

module TbankGrpc
  # Обёртка ответа unary RPC при вызове с return_metadata: true.
  # Содержит тело ответа и метаданные (tracking_id, ratelimit, message).
  class Response
    # @return [Object] тело ответа (модель или proto)
    attr_reader :data
    # @return [Hash] метаданные (tracking_id, ratelimit, message, headers)
    attr_reader :metadata

    # @param data [Object] тело ответа
    # @param metadata [Hash] метаданные (обычно из gRPC metadata/trailers)
    def initialize(data, metadata = {})
      @data = data
      @metadata = metadata
    end

    # @return [String, nil] x-tracking-id из ответа API
    def tracking_id
      @metadata[:tracking_id]
    end

    # @return [Hash, nil] данные rate limit (limit, remaining, reset_after, retry_after)
    def ratelimit
      @metadata[:ratelimit]
    end

    # @return [String, nil] сообщение из метаданных ответа
    def message
      @metadata[:message]
    end
  end
end
