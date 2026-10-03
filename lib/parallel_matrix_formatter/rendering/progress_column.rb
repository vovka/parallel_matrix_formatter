# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Renders the percentage of one process padded to a fixed width with random
    # "rain" symbols, e.g. "ｷｺｼ89%ﾚﾐｴ".
    class ProgressColumn
      def initialize(config, digits)
        @width = config['width'].to_i
        @align = config['align']
        @color = config['color']
        @pad_symbols = config['pad_symbols'].to_s.chars
        @pad_symbols = [' '] if @pad_symbols.empty?
        @pad_color = config['pad_color']
        @digits = digits
      end

      def render(progress)
        value = Digits.replace("#{(progress * 100).round}%", @digits)
        left, right = padding_sizes([@width - value.length, 0].max)
        Colors.wrap(rain(left), @pad_color) + Colors.wrap(value, @color) + Colors.wrap(rain(right), @pad_color)
      end

      private

      def padding_sizes(total)
        case @align
        when 'left' then [0, total]
        when 'right' then [total, 0]
        else [total / 2, total - (total / 2)]
        end
      end

      def rain(size)
        Array.new(size) { @pad_symbols.sample }.join
      end
    end
  end
end
