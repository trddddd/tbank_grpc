# frozen_string_literal: true

module TbankGrpc
  # Повтор запроса при rate limit / resource_exhausted с экспоненциальной задержкой.
  # @api private
  class RateLimitHandler
    MAX_RETRIES = 3
    DEFAULT_BACKOFF = 1.0
    MAX_BACKOFF = 60.0

    # @param method_name [String, Symbol] имя метода для логов
    # @yield блок вызова RPC
    # @return [Object] результат блока
    # @raise [GRPC::BadStatus] при не-retriable ошибке или после исчерпания попыток
    def self.with_retry(method_name:)
      attempts = 0
      max_retries = TbankGrpc.configuration.retry_attempts || MAX_RETRIES

      loop do
        attempts += 1

        begin
          return yield
        rescue GRPC::BadStatus => e
          raise unless retriable_error?(e) && attempts < max_retries

          delay = calculate_delay(e, attempts)
          ratelimit = extract_rate_limit(e.metadata || {})

          TbankGrpc.logger.warn(
            'Request failed, retrying',
            method: method_name,
            attempt: attempts,
            retry_after_seconds: delay.round(2),
            error_code: e.code,
            ratelimit_limit: ratelimit[:limit],
            ratelimit_remaining: ratelimit[:remaining],
            ratelimit_reset_after: ratelimit[:reset_after],
            ratelimit_retry_after: ratelimit[:retry_after]
          )

          sleep(delay)
          next
        end
      end
    end

    # @param metadata [Hash] gRPC metadata (ответ или ошибка)
    # @return [Hash] limit, remaining, reset_after, retry_after (ключи могут отсутствовать)
    def self.extract_rate_limit(metadata)
      return {} unless metadata

      {
        limit: to_int(first_value(metadata, 'x-ratelimit-limit')),
        remaining: to_int(first_value(metadata, 'x-ratelimit-remaining')),
        reset_after: normalize_reset(first_value(metadata, 'x-ratelimit-reset')),
        retry_after: normalize_reset(first_value(metadata, 'retry-after'))
      }.compact
    end

    class << self
      private

      def retriable_error?(grpc_error)
        case grpc_error.code
        when :unavailable, :deadline_exceeded, :resource_exhausted,
             :internal, :unauthenticated
          true
        else
          false
        end
      end

      def calculate_delay(grpc_error, attempt)
        metadata = grpc_error.metadata || {}
        retry_after = normalize_reset(first_value(metadata, 'retry-after'))
        reset_after = normalize_reset(first_value(metadata, 'x-ratelimit-reset'))
        delay_hint = retry_after || reset_after

        if delay_hint&.positive?
          jitter = (delay_hint * 0.1) * (rand - 0.5)
          return [delay_hint + jitter, MAX_BACKOFF].min.abs
        end

        base_delay = DEFAULT_BACKOFF * (2**(attempt - 1))
        jitter = (base_delay * 0.1) * (rand - 0.5)
        delay = base_delay + jitter
        [delay, MAX_BACKOFF].min
      end

      def first_value(metadata, key)
        value = metadata[key]
        value.is_a?(Array) ? value.first : value
      end

      def to_int(value)
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      def normalize_reset(value)
        return if value.nil?

        seconds = value.to_f
        return if seconds <= 0

        seconds -= Time.now.to_i if seconds > 1_000_000_000
        seconds.positive? ? seconds : nil
      end
    end
  end
end
