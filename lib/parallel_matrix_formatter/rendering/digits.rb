# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Replaces the digits 0-9 of a string with custom characters, e.g. katakana.
    module Digits
      module_function

      def replace(text, symbols)
        return text if symbols.nil? || symbols.empty?

        replacements = symbols.chars
        text.gsub(/\d/) { |digit| replacements[digit.to_i] || digit }
      end
    end
  end
end
