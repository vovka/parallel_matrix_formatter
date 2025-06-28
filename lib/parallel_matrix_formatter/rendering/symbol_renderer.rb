# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    class SymbolRenderer
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        reset: "\e[0m"
      }.freeze

      def initialize(test_env_number)
        @symbol = (test_env_number - 1 + 'A'.ord).chr
      end

      def render_symbol(status)
        case status
        when :passed
          render_passed
        when :failed
          render_failed
        when :pending
          render_pending
        end
      end

      def render_passed(msg = nil)
        content = msg ? "#{msg}" : @symbol
        "#{COLORS[:green]}#{content}#{COLORS[:reset]}"
      end

      def render_failed(msg = nil)
        content = msg ? "#{msg}" : @symbol
        "#{COLORS[:red]}#{content}#{COLORS[:reset]}"
      end

      def render_pending(msg = nil)
        content = msg ? "#{msg}" : @symbol
        "#{COLORS[:yellow]}#{content}#{COLORS[:reset]}"
      end
    end
  end
end
