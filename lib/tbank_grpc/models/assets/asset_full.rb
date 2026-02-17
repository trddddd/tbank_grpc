# frozen_string_literal: true

module TbankGrpc
  module Models
    module Assets
      # Полная информация об активе (GetAssetBy).
      class AssetFull < BaseModel
        grpc_simple :uid, :type, :name, :name_brief, :description, :status,
                    :gos_reg_code, :cfi, :code_nsd, :br_code, :br_code_name

        grpc_timestamp :deleted_at, :updated_at

        inspectable_attrs :uid, :type, :name, :name_brief, :status

        # Перечень требуемых тестов/ограничений для актива.
        #
        # @return [Array<Object>]
        def required_tests
          @pb.respond_to?(:required_tests) ? Array(@pb.required_tests) : []
        end

        # Список инструментов, связанных с активом.
        #
        # @return [Array<AssetInstrument>]
        def instruments
          @instruments ||= Array(@pb&.instruments).map { |pb| AssetInstrument.from_grpc(pb) }
        end

        # Валютный блок protobuf без дополнительного маппинга.
        #
        # @return [Google::Protobuf::MessageExts, nil]
        def currency
          @pb.respond_to?(:currency) ? @pb.currency : nil
        end

        # Блок security protobuf без дополнительного маппинга.
        #
        # @return [Google::Protobuf::MessageExts, nil]
        def security
          @pb.respond_to?(:security) ? @pb.security : nil
        end

        # Данные бренда эмитента.
        #
        # @return [Brand, nil]
        def brand
          return nil unless @pb.respond_to?(:brand) && @pb.brand

          @brand ||= Brand.from_grpc(@pb.brand)
        end

        # Сериализация в Hash с вложенными `instruments` и `brand`.
        #
        # @return [Hash]
        def to_h
          return {} unless @pb

          super.merge(
            instruments: instruments.map(&:to_h),
            brand: brand&.to_h
          ).compact
        end
      end
    end
  end
end
