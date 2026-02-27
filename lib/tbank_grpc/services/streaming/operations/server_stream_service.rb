# frozen_string_literal: true

module TbankGrpc
  module Services
    module Streaming
      module Operations
        # Server-side stream сервиса операций:
        # PortfolioStream, PositionsStream, OperationsStream.
        class ServerStreamService < BaseServerStreamService
          MODEL_REQUIRES_BLOCK_MESSAGE = 'as: :model requires block form for operations stream'

          # @param channel_manager [ChannelManager]
          # @param config [Hash]
          # @param interceptors [Array<GRPC::ClientInterceptor>]
          def initialize(channel_manager:, config:, interceptors:)
            ProtoLoader.require!('operations')
            super
            @response_converter = ::TbankGrpc::Streaming::Operations::Responses::ResponseConverter.new
          end

          # Стрим обновлений портфеля.
          #
          # @param account_ids [Array<String>, String, nil]
          # @param account_id [String, nil]
          # @param accounts [Array<String>, String, nil]
          # @param ping_delay_ms [Integer, nil]
          # @param as [Symbol] :proto или :model
          # @yield [payload] при as: :model обязателен
          # @return [Enumerator, nil]
          def portfolio_stream(account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, as: :proto, &)
            request = TbankGrpc::CONTRACT_V1::PortfolioStreamRequest.new(
              accounts: normalize_accounts(account_ids: account_ids, account_id: account_id, accounts: accounts)
            )
            request.ping_settings = build_ping_settings(ping_delay_ms)
            run_server_side_stream(
              stub: initialize_stub(@channel_manager.channel),
              rpc_method: :portfolio_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |r, format:|
                @response_converter.convert_response(r, format: format, stream_type: :portfolio)
              },
              &
            )
          end

          # Стрим обновлений позиций.
          #
          # @param account_ids [Array<String>, String, nil]
          # @param account_id [String, nil]
          # @param accounts [Array<String>, String, nil]
          # @param with_initial_positions [Boolean]
          # @param ping_delay_ms [Integer, nil]
          # @param as [Symbol] :proto или :model
          # @yield [payload] при as: :model обязателен
          # @return [Enumerator, nil]
          # rubocop:disable Metrics/ParameterLists
          def positions_stream(
            account_ids: nil,
            account_id: nil,
            accounts: nil,
            with_initial_positions: false,
            ping_delay_ms: nil,
            as: :proto,
            &
          )
            request = TbankGrpc::CONTRACT_V1::PositionsStreamRequest.new(
              accounts: normalize_accounts(account_ids: account_ids, account_id: account_id, accounts: accounts),
              with_initial_positions: with_initial_positions
            )
            request.ping_settings = build_ping_settings(ping_delay_ms)
            run_server_side_stream(
              stub: initialize_stub(@channel_manager.channel),
              rpc_method: :positions_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |r, format:|
                @response_converter.convert_response(r, format: format, stream_type: :positions)
              },
              &
            )
          end
          # rubocop:enable Metrics/ParameterLists

          # Стрим обновлений операций.
          #
          # @param account_ids [Array<String>, String, nil]
          # @param account_id [String, nil]
          # @param accounts [Array<String>, String, nil]
          # @param ping_delay_ms [Integer, nil]
          # @param as [Symbol] :proto или :model
          # @yield [payload] при as: :model обязателен
          # @return [Enumerator, nil]
          def operations_stream(account_ids: nil, account_id: nil, accounts: nil, ping_delay_ms: nil, as: :proto, &)
            request = TbankGrpc::CONTRACT_V1::OperationsStreamRequest.new(
              accounts: normalize_accounts(account_ids: account_ids, account_id: account_id, accounts: accounts)
            )
            request.ping_settings = build_ping_settings(ping_delay_ms)
            run_server_side_stream(
              stub: initialize_stub(@channel_manager.channel),
              rpc_method: :operations_stream,
              request: request,
              as: as,
              model_requires_block_message: MODEL_REQUIRES_BLOCK_MESSAGE,
              converter: lambda { |r, format:|
                @response_converter.convert_response(r, format: format, stream_type: :operations)
              },
              &
            )
          end

          private

          def initialize_stub(channel)
            TbankGrpc::CONTRACT_V1::OperationsStreamService::Stub.new(
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

          def build_ping_settings(ping_delay_ms)
            return nil if ping_delay_ms.nil?

            TbankGrpc::CONTRACT_V1::PingDelaySettings.new(ping_delay_ms: Integer(ping_delay_ms))
          rescue ArgumentError, TypeError
            raise InvalidArgumentError, 'ping_delay_ms must be an integer'
          end
        end
      end
    end
  end
end
