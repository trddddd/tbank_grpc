# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      module Orders
        # Server-side stream для ордеров:
        # - TradesStream (сделки пользователя по поручениям)
        # - OrderStateStream (события по состояниям поручений)
        class ServerStreamService < BaseServerStreamService
          MODEL_REQUIRES_BLOCK_MESSAGE = 'as: :model requires block form for orders stream'
          # Диапазон пинга для TradesStream (см. proto для TradesStreamRequest)
          PING_DELAY_MIN_MS = 5_000
          PING_DELAY_MAX_MS = 180_000
          # Диапазон пинга для OrderStateStream (см. proto для OrderStateStreamRequest)
          ORDER_STATE_PING_DELAY_MIN_MS = 1_000
          ORDER_STATE_PING_DELAY_MAX_MS = 120_000

          # @param channel_manager [ChannelManager]
          # @param config [Hash]
          # @param interceptors [Array<GRPC::ClientInterceptor>]
          def initialize(channel_manager:, config:, interceptors:)
            ProtoLoader.require!('orders')
            super
            @response_converter = ::TbankGrpc::Streaming::Orders::Responses::ResponseConverter.new
          end

          # Стрим сделок по заявкам. TradesStream.
          #
          # @param account_ids [Array<String>, String, nil]
          # @param account_id [String, nil]
          # @param accounts [Array<String>, String, nil]
          # @param ping_delay_ms [Integer, nil] 5000..180000
          # @param as [Symbol] :proto или :model
          # @yield [payload] при as: :model обязателен
          # @return [Enumerator, nil]
          def trades_stream(account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, as: :proto, &)
            request = TbankGrpc::CONTRACT_V1::TradesStreamRequest.new(
              accounts: normalize_accounts(account_ids: account_ids, account_id: account_id, accounts: accounts)
            )
            unless ping_delay_ms.nil?
              request.ping_delay_ms = normalize_ping_delay(ping_delay_ms,
                                                           field_name: 'ping_delay_ms')
            end

            run_server_side_stream(
              stub: initialize_stub(@channel_manager.channel),
              rpc_method: :trades_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |response, format:|
                @response_converter.convert_response(response, format: format, stream_type: :trades)
              },
              &
            )
          end

          # Стрим статусов заявок. OrderStateStream.
          #
          # @param account_ids [Array<String>, String, nil]
          # @param account_id [String, nil]
          # @param accounts [Array<String>, String, nil]
          # @param ping_delay_ms [Integer, nil] alias для ping_delay_millis
          # @param ping_delay_millis [Integer, nil] 1000..120000 (OrderStateStream)
          # @param as [Symbol] :proto или :model
          # @yield [payload] при as: :model обязателен
          # @return [Enumerator, nil]
          # rubocop:disable Metrics/ParameterLists
          def order_state_stream(
            account_ids: nil,
            account_id: nil,
            accounts: nil,
            ping_delay_ms: nil,
            ping_delay_millis: nil,
            as: :proto,
            &
          )
            request = TbankGrpc::CONTRACT_V1::OrderStateStreamRequest.new(
              accounts: normalize_accounts(account_ids: account_ids, account_id: account_id, accounts: accounts)
            )
            ping_delay = resolve_order_state_ping_delay(ping_delay_ms: ping_delay_ms,
                                                        ping_delay_millis: ping_delay_millis)
            unless ping_delay.nil?
              request.ping_delay_millis = normalize_order_state_ping_delay_value(
                ping_delay,
                field_name: 'ping_delay_millis'
              )
            end

            run_server_side_stream(
              stub: initialize_stub(@channel_manager.channel),
              rpc_method: :order_state_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |response, format:|
                @response_converter.convert_response(response, format: format, stream_type: :order_state)
              },
              &
            )
          end
          # rubocop:enable Metrics/ParameterLists

          private

          def initialize_stub(channel)
            TbankGrpc::CONTRACT_V1::OrdersStreamService::Stub.new(
              nil,
              :this_channel_is_insecure,
              channel_override: channel,
              interceptors: @interceptors
            )
          end

          def normalize_accounts(account_ids:, account_id:, accounts:)
            variants = [account_ids, account_id, accounts].compact
            raise InvalidArgumentError, 'Provide only one of account_ids, account_id or accounts' if variants.size > 1

            source = variants.first
            Normalizers::AccountIdNormalizer.normalize_list(source, strip: true)
          end

          def normalize_ping_delay(value, field_name:)
            delay = Integer(value)
            if delay < PING_DELAY_MIN_MS || delay > PING_DELAY_MAX_MS
              raise InvalidArgumentError,
                    "#{field_name} must be in range #{PING_DELAY_MIN_MS}..#{PING_DELAY_MAX_MS}"
            end

            delay
          rescue ArgumentError, TypeError
            raise InvalidArgumentError, "#{field_name} must be an integer"
          end

          def normalize_order_state_ping_delay_value(value, field_name:)
            delay = Integer(value)
            if delay < ORDER_STATE_PING_DELAY_MIN_MS || delay > ORDER_STATE_PING_DELAY_MAX_MS
              raise InvalidArgumentError,
                    "#{field_name} must be in range #{ORDER_STATE_PING_DELAY_MIN_MS}..#{ORDER_STATE_PING_DELAY_MAX_MS}"
            end

            delay
          rescue ArgumentError, TypeError
            raise InvalidArgumentError, "#{field_name} must be an integer"
          end

          def resolve_order_state_ping_delay(ping_delay_ms:, ping_delay_millis:)
            return ping_delay_ms if ping_delay_millis.nil?
            return ping_delay_millis if ping_delay_ms.nil?

            raise InvalidArgumentError, 'Provide only one of ping_delay_ms or ping_delay_millis'
          end
        end
      end
    end
  end
end
