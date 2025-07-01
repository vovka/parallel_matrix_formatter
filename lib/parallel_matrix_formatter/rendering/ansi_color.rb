module ParallelMatrixFormatter
  module Rendering
    # The AnsiColor class provides methods for applying ANSI color codes to strings.
    # It defines a set of common colors and dynamically creates methods for each color
    # to wrap a given string (or the result of a block) with the corresponding ANSI codes,
    # effectively coloring the text in the terminal.
    class AnsiColor
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        white: "\e[37m",
        reset: "\e[0m"
      }.freeze

      class << self
        COLORS.each_key do |color|
          define_method(color) do |&block|
            "#{COLORS[color]}#{block.call}#{COLORS[:reset]}"
          end
        end
      end
    end
  end
end
