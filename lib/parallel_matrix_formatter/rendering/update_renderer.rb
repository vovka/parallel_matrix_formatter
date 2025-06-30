module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      def initialize(test_env_number)
        @test_env_number = test_env_number
        @progress = {}
        @config = ParallelMatrixFormatter::Config::Config.instance.update_renderer_config
      end

      def update(message)
        if message && message['process_number'] && message['message']
          @progress[message['process_number']] = message['message']['progress']
        end

        str = ""
        str += progress_update
        str += test_example_status(message)
        str
      end

      private

      def progress_update
        return "" unless should_update_progress?
        @previous_progress_update_at = Time.now
        progress_info = build_progress_info
        format_progress_line(progress_info)
      end

      def should_update_progress?
        update_interval = @config['update_interval_seconds'] || 3
        time_ok = @previous_progress_update_at.nil? || Time.now - @previous_progress_update_at > update_interval
        all_complete = !@progress.empty? && @progress.values.all? { |v| v >= 1.0 }
        (time_ok || all_complete) && !@progress.empty?
      end

      def build_progress_info
        cfg = @config['progress_column'] || {}
        format_cfg = cfg['parsed'] || { align: '^', width: 6, value: '{v}%', color: 'red' }
        pad_symbol = cfg['pad_symbol'] || '='
        pad_color = cfg['pad_color']
        @progress.sort.map { |k, v| format_progress_column(v, format_cfg, pad_symbol, pad_color) }
          .then { |arr| color_progress_info(arr) }
          .join
      end

      def format_progress_column(v, format_cfg, pad_symbol, pad_color)
        value = format_cfg[:value].gsub('{v}', "#{(v * 100).round(2)}")
        width = format_cfg[:width] || 10
        align = format_cfg[:align] || '^'
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
        pad_left = lpad.times.map { pad_symbol.split('').sample }.join
        pad_right = rpad.times.map { pad_symbol.split('').sample }.join

        value = AnsiColor.send(format_cfg[:color]) { value } if format_cfg[:color] && AnsiColor.respond_to?(format_cfg[:color])
        if pad_color && AnsiColor.respond_to?(pad_color)
          pad_left = AnsiColor.send(pad_color) { pad_left } unless pad_left.empty?
          pad_right = AnsiColor.send(pad_color) { pad_right } unless pad_right.empty?
        end
        "#{pad_left}#{value}#{pad_right}"
      end

      def color_progress_info(arr)
        color = @config.dig('colors', 'progress_info')
        if color && AnsiColor.respond_to?(color)
          arr.map { |info| AnsiColor.send(color) { info } }
        else
          arr
        end
      end

      def format_progress_line(progress_info)
        format_string = @config['progress_line_format'] || "\nUpdate is run from process {process_number}. Progress: {progress_info} "
        format_string
          .gsub('{time}', Time.now.strftime("%H:%M:%S"))
          .gsub('{process_number}', @test_env_number.to_s)
          .gsub('{progress_info}', progress_info)
      end

      def test_example_status(message)
        return "" unless message&.dig('message', 'status')

        status = message['message']['status'].to_sym
        process_symbol = (message['process_number'] - 1 + 'A'.ord).chr
        status_symbol = get_status_symbol(status)
        formatted_output = (@config['test_status_line_format'] || "{status_symbol}{process_symbol}")
          .gsub('{status_symbol}', status_symbol)
          .gsub('{process_symbol}', process_symbol)

        color = @config.dig('colors', {
          passed: 'pass_dot',
          failed: 'fail_dot',
          pending: 'pending_dot'
        }[status]) || ({ passed: 'green', failed: 'red', pending: 'yellow' }[status])

        color && AnsiColor.respond_to?(color) ? AnsiColor.send(color) { formatted_output } : formatted_output
      end

      def get_status_symbol(status)
        symbols = @config.dig('status_symbols', status.to_s)
        if symbols.is_a?(String)
          symbols.each_char.to_a.sample
        else
          case status
          when :passed then "✅"
          when :failed then "❌"
          when :pending then "⏳"
          else ""
          end
        end
      end
    end
  end
end
