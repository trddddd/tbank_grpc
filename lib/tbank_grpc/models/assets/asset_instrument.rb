# frozen_string_literal: true

module TbankGrpc
  module Models
    module Assets
      # Идентификатор инструмента в составе актива (Asset / AssetFull).
      class AssetInstrument < BaseModel
        grpc_simple :uid, :figi, :instrument_type, :ticker, :class_code,
                    :instrument_kind, :position_uid

        inspectable_attrs :uid, :figi, :ticker, :class_code, :instrument_type

        # Ссылки/референсы из protobuf поля `links`.
        #
        # @return [Array<Object>]
        def links
          @pb.respond_to?(:links) ? Array(@pb.links) : []
        end
      end
    end
  end
end
