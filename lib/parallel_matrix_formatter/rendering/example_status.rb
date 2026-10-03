# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Renders the symbol printed for one finished example: a random character
    # from the configured set for its status, in the status's color.
    class ExampleStatus
      def initialize(config)
        @format = config['format']
        @symbols = config['symbols']
        @colors = config['colors']
      end

      # @param status [String] "passed", "failed" or "pending"
      def render(process, status)
        text = @format.gsub('{symbol}', symbol(status)).gsub('{process_letter}', process_letter(process))
        Colors.wrap(text, @colors[status])
      end

      private

      def symbol(status)
        @symbols[status].to_s.chars.sample.to_s
      end

      def process_letter(process)
        ('A'.ord + process - 1).chr
      end
    end
  end
end
