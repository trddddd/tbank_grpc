# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Subscriptions
        # Shared normalization and enum resolution logic for stream subscription params.
        # @api private
        module ParamsNormalizer
          # @param instrument_id [String, #to_s]
          # @return [String]
          # @raise [InvalidArgumentError] если пустая строка после strip
          def self.normalize_instrument_id(instrument_id)
            TbankGrpc::Normalizers::InstrumentIdNormalizer.normalize_single(instrument_id, strip: true)
          end

          # @param instrument_ids [Array, String, #to_s] один id или массив
          # @return [Array<String>] уникальные непустые id
          # @raise [InvalidArgumentError] если после обработки массив пуст
          def self.normalize_instrument_ids(instrument_ids)
            TbankGrpc::Normalizers::InstrumentIdNormalizer.normalize_list(instrument_ids, strip: true, uniq: true)
          end

          # @param depth [Integer, #to_i]
          # @return [Integer] ближайшее допустимое значение (см. Converters::OrderBookDepth)
          def self.normalize_depth(depth)
            Converters::OrderBookDepth.normalize(depth)
          end

          # @param value [Symbol, Integer, nil]
          # @param type_module [Module] контракт (OrderBookType)
          # @param default [Symbol]
          # @return [Integer] значение enum
          # @raise [InvalidArgumentError]
          def self.resolve_order_book_type(value, type_module:, default: :ORDERBOOK_TYPE_ALL)
            resolve_enum(type_module::OrderBookType, value || default, prefix: 'ORDERBOOK_TYPE')
          end

          # @param value [Symbol, Integer, nil]
          # @param type_module [Module]
          # @param default [Symbol]
          # @return [Integer]
          # @raise [InvalidArgumentError]
          def self.resolve_trade_source(value, type_module:, default: :TRADE_SOURCE_ALL)
            resolve_enum(type_module::TradeSourceType, value || default, prefix: 'TRADE_SOURCE')
          end

          # @param value [Symbol, Integer, nil]
          # @param type_module [Module]
          # @param allow_nil [Boolean]
          # @return [Integer, nil]
          # @raise [InvalidArgumentError]
          def self.resolve_candle_source(value, type_module:, allow_nil: true)
            return nil if allow_nil && value.nil?

            resolve_enum(type_module::GetCandlesRequest::CandleSource, value, prefix: 'CANDLE_SOURCE')
          end

          # @param value [Symbol, Integer] интервал свечей (символ из CANDLE_INTERVAL_* или число)
          # @param type_module [Module]
          # @return [Integer] SubscriptionInterval enum value
          # @raise [InvalidArgumentError] если value nil или не поддерживается
          def self.resolve_subscription_interval(value, type_module:)
            raise InvalidArgumentError, 'interval is required' if value.nil?

            if value.is_a?(Integer)
              return value if subscription_interval_values(type_module).include?(value)

              raise InvalidArgumentError, "Unsupported candle interval for stream: #{value.inspect}"
            end

            key = normalize_interval_key(value)
            type_module::SubscriptionInterval.const_get(key.to_s)
          rescue NameError
            raise InvalidArgumentError, "Unsupported candle interval for stream: #{value.inspect}"
          end

          # @param type_module [Module]
          # @return [Array<Integer>] все значения SubscriptionInterval
          def self.subscription_interval_values(type_module)
            type_module::SubscriptionInterval.constants.map do |const_name|
              type_module::SubscriptionInterval.const_get(const_name)
            end
          end

          def self.resolve_enum(enum_module, value, prefix:)
            Converters::Enum.resolve(enum_module, value, prefix: prefix)
          rescue InvalidArgumentError
            raise
          rescue StandardError
            raise InvalidArgumentError, "Unsupported enum value #{value.inspect} for #{enum_module.name}"
          end
          private_class_method :resolve_enum

          def self.normalize_interval_key(value)
            key = value.to_s.upcase.to_sym
            canonical = Converters::CandleInterval.normalize(key)
            mapping = Converters::CandleToSubscriptionInterval::CANDLE_TO_SUBSCRIPTION
            mapping[canonical] || mapping[key] || key
          end
          private_class_method :normalize_interval_key
        end
      end
    end
  end
end
