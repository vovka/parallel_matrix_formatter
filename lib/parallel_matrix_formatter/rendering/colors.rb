# frozen_string_literal: true

require 'rspec/core/formatters/console_codes'

module ParallelMatrixFormatter
  module Rendering
    # Wraps text in ANSI color codes. Accepts the color names RSpec knows
    # (red, green, bold_blue, ...) as well as RSpec's semantic names (failure,
    # detail, ...), so it doubles as the colorizer for RSpec's failure output.
    # Colors are always on, since CI logs render them, unless NO_COLOR is set.
    module Colors
      module_function

      def wrap(text, color)
        return text.to_s if color.nil? || text.to_s.empty? || disabled?

        code = RSpec::Core::Formatters::ConsoleCodes.console_code_for(color.to_sym)
        "\e[#{code}m#{text}\e[0m"
      end

      def disabled?
        !ENV['NO_COLOR'].to_s.empty?
      end
    end
  end
end
