# frozen_string_literal: true

module ParallelMatrixFormatter
  class SymbolRenderer
    COLORS = {
      green: "\e[32m",
      red: "\e[31m",
      yellow: "\e[33m",
      reset: "\e[0m"
    }.freeze

    def initialize(test_env_number, output)
      @output = output
      @symbol = (test_env_number - 1 + 'A'.ord).chr
    end

    def render_passed
      @output.print "#{COLORS[:green]}#{@symbol}#{COLORS[:reset]}"
      @output.flush
    end

    def render_failed
      @output.print "#{COLORS[:red]}#{@symbol}#{COLORS[:reset]}"
      @output.flush
    end

    def render_pending
      @output.print "#{COLORS[:yellow]}#{@symbol}#{COLORS[:reset]}"
      @output.flush
    end
  end
end
