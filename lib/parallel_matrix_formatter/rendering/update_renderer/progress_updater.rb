# This class is responsible for updating and formatting the progress line displayed in the console.
# It calculates the progress based on test execution, applies formatting rules,
# and incorporates configuration for display elements like padding and colors.
module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      class ProgressUpdater
        include ParallelMatrixFormatter::Rendering::FormatHelper

        def initialize(test_env_number, progress, config)
          @test_env_number = test_env_number
          @progress = progress
          @config = config
          @policy = ProgressUpdatePolicy.new(@config)
        end

        def update
          return "" unless @policy.should_update?(@progress)

          progress_info = build_progress_info
          format_progress_line(progress_info)
        end

        private

        def build_progress_info
          cfg = @config['progress_column'] || {}
          pad_symbol = cfg['pad_symbol'] || '='
          pad_color = cfg['pad_color']
          @progress.sort.map { |k, v| format_progress_column(v, pad_symbol, pad_color) }
            .then { |arr| color_progress_info(arr) }
            .join
        end

        def format_progress_column(v, pad_symbol, pad_color)
          format_cfg = ( @config['progress_column'] && @config['progress_column']['parsed'] ) || { 'align' => '^', 'width' => 6, 'value' => '{v}%', 'color' => 'red' }
          value_template = format_cfg[:value] || format_cfg['value'] || '{v}%'
          value = value_template.gsub('{v}', "#{(v * 100).round(0)}")

          width = format_cfg[:width] || format_cfg['width'] || 10
          align = format_cfg[:align] || format_cfg['align'] || '^'
          pad_total = [width - value.length, 0].max
          left_pad = pad_total / 2
          right_pad = pad_total - left_pad
          lpad, rpad =
            case align
            when '^' then [left_pad, right_pad]
            when '-' then [0, pad_total]
            when '+' then [pad_total, 0]
            else [left_pad, right_pad]
            end
          # Sample from pad_symbol characters if it's a string of characters
          pad_chars = pad_symbol.split('')
          pad_left = lpad.times.map { pad_chars.sample }.join
          pad_right = rpad.times.map { pad_chars.sample }.join

          value = customize_digits(value, @config['digits'])

          # Apply colors
          color = format_cfg[:color] || format_cfg['color']
          value = ParallelMatrixFormatter::Rendering::AnsiColor.send(color) { value } if color && ParallelMatrixFormatter::Rendering::AnsiColor.respond_to?(color)
          if pad_color && ParallelMatrixFormatter::Rendering::AnsiColor.respond_to?(pad_color)
            pad_left = ParallelMatrixFormatter::Rendering::AnsiColor.send(pad_color) { pad_left } unless pad_left.empty?
            pad_right = ParallelMatrixFormatter::Rendering::AnsiColor.send(pad_color) { pad_right } unless pad_right.empty?
          end
          "#{pad_left}#{value}#{pad_right}"
        end

        def color_progress_info(arr)
          color = @config.dig('colors', 'progress_info')
          if color && ParallelMatrixFormatter::Rendering::AnsiColor.respond_to?(color)
            arr.map { |info| ParallelMatrixFormatter::Rendering::AnsiColor.send(color) { info } }
          else
            arr
          end
        end

        def format_progress_line(progress_info)
          format_string = @config['progress_line_format'] || "\nUpdate is run from process {process_number}. Progress: {progress_info} "
          format_string
            .gsub('{time}', customize_digits(Time.now.strftime("%H:%M:%S"), @config['digits']))
            .gsub('{process_number}', @test_env_number.to_s)
            .gsub('{progress_info}', progress_info)
        end
      end
    end
  end
end
