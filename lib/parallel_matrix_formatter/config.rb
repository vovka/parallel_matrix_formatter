require 'singleton'

module ParallelMatrixFormatter
  class Config
    include Singleton

    attr_accessor :suppress

    def initialize
      @suppress = true
    end
  end
end
