# frozen_string_literal: true

module TbankGrpc
  module Services
    module Unary
      # Базовый класс для unary-сервисов T-Bank Invest API (gRPC).
      # Подклассы создают stub своего сервиса и вызывают {#execute_rpc} для выполнения запросов
      # с обработкой ошибок, rate limit и опциональным маппингом ответа в модели.
      #
      # @see https://developer.tbank.ru/invest/api
      class BaseUnaryService
        # @return [Object] gRPC stub сервиса (Tinkoff::Public::Invest::Api::Contract::V1::*::Stub)
        attr_reader :stub, :config, :logger

        # @param channel [GRPC::Core::Channel] канал gRPC
        # @param config [Hash] конфигурация клиента (`TbankGrpc.configuration.to_h`)
        # @param interceptors [Array] перехватчики gRPC
        def initialize(channel, config, interceptors: [])
          @channel = channel
          @config = config
          @logger = TbankGrpc.logger
          @interceptors = interceptors
          @stub = initialize_stub
        end

        # Выполняет unary RPC: повтор при rate limit, обёртка ошибок, опционально маппинг в модель.
        #
        # @param method_name [Symbol] имя метода stub (snake_case), например :get_portfolio
        # @param request [Google::Protobuf::MessageExts] сообщение запроса
        # @param stub [Object] stub (по умолчанию текущий сервис)
        # @param return_metadata [Boolean] если true, возвращается {TbankGrpc::Response} с data и metadata
        # @param model [Class, nil] класс модели с .from_grpc(response) для маппинга ответа
        # @yield [response] блок для кастомного маппинга ответа (имеет приоритет над model)
        # @return [Object, TbankGrpc::Response] ответ (proto, модель или результат блока)
        def execute_rpc(method_name:, request:, stub: @stub, return_metadata: false, model: nil, &response_mapper)
          method_full_name = derive_method_full_name(stub, method_name)
          handle_request(method_name: method_full_name, return_metadata: return_metadata) do |return_op:|
            response = call_rpc(stub, method_name, request, return_metadata: return_op)
            next response if return_metadata

            if response_mapper
              response_mapper.call(response)
            elsif model
              model.from_grpc(response)
            else
              response
            end
          end
        end

        # Список из RPC: response.public_send(response_collection) → Array, каждый элемент в model_class.from_grpc.
        #
        # @param method_name [Symbol] имя метода stub
        # @param request [Google::Protobuf::MessageExts]
        # @param response_collection [Symbol] поле ответа с массивом (например :events, :dividends, :accounts)
        # @param model_class [Class] модель с .from_grpc(pb)
        # @param return_metadata [Boolean]
        # @param stub [Object]
        # @return [Array, TbankGrpc::Response]
        # rubocop:disable Metrics/ParameterLists
        def execute_list_rpc(method_name:, request:, response_collection:, model_class:, return_metadata: false,
                             stub: @stub)
          execute_rpc(
            method_name: method_name,
            request: request,
            stub: stub,
            return_metadata: return_metadata
          ) { |response| Array(response.public_send(response_collection)).map { |pb| model_class.from_grpc(pb) } }
        end
        # rubocop:enable Metrics/ParameterLists

        private

        def resolve_instrument_id(instrument_id:)
          TbankGrpc::Normalizers::InstrumentIdNormalizer.normalize_single(instrument_id, strip: true)
        end

        def resolve_instrument_ids(instrument_id:)
          TbankGrpc::Normalizers::InstrumentIdNormalizer.normalize_list(instrument_id, strip: true, uniq: false)
        end

        def timestamp_to_time(timestamp)
          TbankGrpc::Converters::Timestamp.to_time(timestamp)
        end

        def build_quotation(value)
          TbankGrpc::Converters::Quotation.to_pb(value)
        end

        def build_money_value(value, currency: nil)
          TbankGrpc::Converters::Money.to_pb(value, currency: currency)
        end

        def resolve_enum(enum_module, value, prefix: nil)
          TbankGrpc::Converters::Enum.resolve(enum_module, value, prefix: prefix)
        end

        def timestamp_to_proto(time)
          return unless time

          time_obj = time.is_a?(Time) ? time : DateTime.parse(time.to_s).to_time
          Google::Protobuf::Timestamp.new(
            seconds: time_obj.to_i,
            nanos: time_obj.nsec
          )
        end

        def initialize_stub
          raise NotImplementedError, 'Subclasses must implement initialize_stub'
        end

        def derive_method_full_name(stub, method_name)
          service_short = stub.class.name.split('::')[-2]
          method_camel = method_name.to_s.split('_').map(&:capitalize).join
          "#{service_short}/#{method_camel}"
        end

        def handle_request(method_name:, return_metadata: false)
          RateLimitHandler.with_retry(method_name: method_name) do
            if return_metadata
              op = yield(return_op: true)
              response = op.execute
              metadata = extract_response_metadata(op)
              Response.new(response, metadata)
            else
              yield(return_op: false)
            end
          end
        rescue GRPC::BadStatus => e
          tracking_id = extract_tracking_id(e)
          context = { grpc_code: e.code, tracking_id: tracking_id, method: method_name }
          error = ErrorHandler.wrap_grpc_error(e, context)
          logger.error('Request failed', error: error)
          raise error
        end

        def call_rpc(stub, method_name, request, return_metadata:)
          method_full_name = derive_method_full_name(stub, method_name)
          deadline = DeadlineResolver.deadline_for(method_full_name, @config)

          options = { metadata: {} }
          options[:deadline] = deadline if deadline
          options[:return_op] = true if return_metadata

          stub.public_send(method_name, request, **options)
        end

        def extract_tracking_id(grpc_error)
          raw = TrackingId.extract(grpc_error.metadata)
          raw.nil? ? 'unknown' : raw.to_s
        end

        def extract_response_metadata(operation)
          headers = operation&.metadata || {}
          trailers = operation&.trailing_metadata || {}
          merged = headers.merge(trailers) { |_k, _a, b| b }

          {
            tracking_id: extract_tracking_id_from_metadata(merged),
            ratelimit: RateLimitHandler.extract_rate_limit(merged),
            message: extract_message_from_metadata(merged),
            headers: merged
          }
        end

        def extract_tracking_id_from_metadata(metadata)
          raw = TrackingId.extract(metadata)
          raw&.to_s
        end

        def extract_message_from_metadata(metadata)
          raw = metadata&.dig('message')
          return if raw.nil?

          raw.is_a?(Array) ? raw.first.to_s : raw.to_s
        end
      end
    end
  end
end
