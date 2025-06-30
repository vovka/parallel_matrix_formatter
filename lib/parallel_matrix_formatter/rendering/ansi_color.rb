module ParallelMatrixFormatter
  module Rendering
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
