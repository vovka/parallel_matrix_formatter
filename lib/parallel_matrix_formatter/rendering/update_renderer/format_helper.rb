# This module provides helper methods for formatting and customizing output strings.
# It includes functionality for digit customization based on provided configuration.
module ParallelMatrixFormatter
  module Rendering
    module FormatHelper
      def customize_digits(str, digits_config)
        return str unless digits_config && !digits_config['symbols'].nil? && !digits_config['symbols'].empty?

        digits = digits_config['symbols'].split('')[0..9]
        (0..9).each do |i|
          str = str.gsub(i.to_s, digits[i]) if digits[i]
        end
        str
      end
    end
  end
end
