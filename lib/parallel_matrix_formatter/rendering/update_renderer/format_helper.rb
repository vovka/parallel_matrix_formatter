module ParallelMatrixFormatter
  module Rendering
    module FormatHelper
      def customize_digits(str, digits_config)
        return str unless digits_config && !digits_config.empty?

        digits = digits_config['symbols'].split('')[0..9]
        (0..9).each do |i|
          str = str.gsub(i.to_s, digits[i]) if digits[i]
        end
        str
      end
    end
  end
end
