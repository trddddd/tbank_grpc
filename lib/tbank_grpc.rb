# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module TbankGrpc
  class << self
    def version
      VERSION
    end
  end
end

loader.eager_load
