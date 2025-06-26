# frozen_string_literal: true

module ParallelMatrixFormatter
  # AnsiColorizer provides simple ANSI color code application to text.
  # This class only supports ANSI escape codes and doesn't check environment variables
  # or terminal capabilities. It always applies colors when requested.
  #
  # This is a simplified replacement for the complex color detection logic that
  # was previously in DigitalRainRenderer. By removing environment checks,
  # the formatting is more predictable and easier to test.
  class AnsiColorizer
    # ANSI color codes mapping
    COLOR_CODES = {
      'red' => "\e[31m",
      'green' => "\e[32m",
      'bright_green' => "\e[1;32m",
      'blue' => "\e[34m",
      'yellow' => "\e[33m",
      'cyan' => "\e[36m",
      'magenta' => "\e[35m",
      'white' => "\e[37m",
      'black' => "\e[30m"
    }.freeze

    RESET_CODE = "\e[0m"

    # Apply ANSI color codes to text
    # @param text [String] Text to colorize
    # @param color [String] Color name (from COLOR_CODES keys)
    # @return [String] Text with ANSI color codes applied
    def self.colorize(text, color)
      return text if color.nil? || color.empty?

      color_code = COLOR_CODES[color.to_s.downcase]
      return text unless color_code

      "#{color_code}#{text}#{RESET_CODE}"
    end

    # Check if a color is supported
    # @param color [String] Color name to check
    # @return [Boolean] true if color is supported
    def self.supported_color?(color)
      COLOR_CODES.key?(color.to_s.downcase)
    end

    # Get list of supported colors
    # @return [Array<String>] Array of supported color names
    def self.supported_colors
      COLOR_CODES.keys
    end
  end
end