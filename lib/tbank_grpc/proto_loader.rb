# frozen_string_literal: true

module TbankGrpc
  # Подключение сгенерированных proto-файлов (_pb, _services_pb).
  # @api private
  module ProtoLoader
    PROTO_DIR = File.expand_path('proto', __dir__).freeze

    # @param name [String] имя набора (например 'instruments' → instruments_pb, instruments_services_pb)
    # @return [true]
    # @raise [ConfigurationError] если файлы не найдены (нужен rake compile_proto)
    def self.require!(name)
      $LOAD_PATH.unshift(PROTO_DIR) unless $LOAD_PATH.include?(PROTO_DIR)
      require "#{name}_pb"
      require "#{name}_services_pb"
      true
    rescue LoadError
      raise ConfigurationError, <<~MSG.strip
        Proto files for #{name} are missing. Run:
          cd path/to/tbank_grpc
          bundle exec rake compile_proto
      MSG
    end
  end
end
