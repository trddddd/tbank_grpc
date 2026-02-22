# frozen_string_literal: true

module TbankGrpc
  module Streaming
    module MarketData
      module Subscriptions
        # Хранилище активных подписок с учётом лимита и весов (info = 0, остальные по числу instrument_ids/1).
        class Registry
          # @param max_subscriptions [Integer] максимальное число «единиц» подписок
          def initialize(max_subscriptions:)
            @max_subscriptions = max_subscriptions.to_i
            @active_subscriptions = {}
          end

          # @param type [Symbol, String] :orderbook, :candles, :trades, :info, :last_price
          # @param params [Hash] параметры подписки (без дубликатов)
          # @return [void]
          def store(type, params)
            key = type.to_sym
            @active_subscriptions[key] ||= []
            @active_subscriptions[key] << params unless @active_subscriptions[key].include?(params)
          end

          # @param type [Symbol, String]
          # @param params [Hash]
          # @return [void]
          def remove(type, params)
            key = type.to_sym
            return unless @active_subscriptions[key]

            @active_subscriptions[key].delete(params)
            @active_subscriptions.delete(key) if @active_subscriptions[key].empty?
          end

          # @param type [Symbol, String]
          # @param params [Hash]
          # @return [Boolean]
          def include?(type, params)
            key = type.to_sym
            values = @active_subscriptions[key]
            return false unless values

            values.include?(params)
          end

          # Проверяет, что добавление подписки не превысит лимит.
          # @param type [Symbol, String]
          # @param params [Hash]
          # @return [void]
          # @raise [InvalidArgumentError] при превышении лимита
          def ensure_limit!(type, params)
            total = total_subscriptions + subscription_weight(type, params)
            return if total <= @max_subscriptions

            raise InvalidArgumentError, "Subscription limit exceeded: #{total} > #{@max_subscriptions}"
          end

          # @return [Integer] текущий «вес» всех подписок
          def total_subscriptions
            count_subscriptions(@active_subscriptions)
          end

          # @yield [type, params] для каждой подписки
          # @return [Enumerator<Array(Symbol, Hash)>] при вызове без блока
          def each_subscription
            return enum_for(:each_subscription) unless block_given?

            @active_subscriptions.each do |(type, params_list)|
              params_list.each { |params| yield(type, params) }
            end
          end

          private

          def count_subscriptions(subscriptions)
            subscriptions.sum do |(type, params_list)|
              params_list.sum { |params| subscription_weight(type, params) }
            end
          end

          def subscription_weight(type, params)
            return 0 if type.to_sym == :info

            ids = params[:instrument_ids]
            ids && !ids.empty? ? ids.length : 1
          end
        end
      end
    end
  end
end
