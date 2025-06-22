# frozen_string_literal: true

require 'rainbow'

module ParallelMatrixFormatter
  class DigitalRainRenderer
    def initialize(config)
      @config = config
      @terminal_colors = detect_color_support
    end

    def render_time_column
      time_str = Time.now.strftime('%H:%M:%S')
      digit_chars = @config['digits']['symbols_chars']

      if @config['digits']['use_custom'] && @config['display']['show_time_digits']
        # Convert each digit to custom symbol
        custom_time = time_str.chars.map do |char|
          if char.match?(/\d/)
            digit_chars[char.to_i]
          else
            char # Keep colons as is
          end
        end.join
        colorize(custom_time, @config['colors']['time'])
      else
        colorize(time_str, @config['colors']['time'])
      end
    end

    def render_process_column(_process_id, progress_percent, column_width = nil)
      width = column_width || @config['display']['column_width']
      rain_chars = @config['katakana_alphabet_chars']
      rain_density = @config['display']['rain_density']

      # Generate random rain characters
      rain_column = Array.new(width) do
        if rand < rain_density
          rain_chars.sample
        else
          ' '
        end
      end.join

      # Overlay progress percentage
      percent_str = "#{progress_percent}%"
      percent_start = (width - percent_str.length) / 2
      percent_start = [0, percent_start].max
      percent_end = [percent_start + percent_str.length, width].min

      # Replace rain characters with percentage
      result = rain_column.dup
      percent_str.chars.each_with_index do |char, i|
        pos = percent_start + i
        break if pos >= width

        result[pos] = char
      end

      # Apply colors - rain in green, percentage in red
      colored_result = ''
      result.chars.each_with_index do |char, i|
        colored_result += if i >= percent_start && i < percent_end && i - percent_start < percent_str.length
                            colorize(char, @config['colors']['percent'])
                          else
                            colorize(char, @config['colors']['rain'])
                          end
      end

      colored_result
    end

    def render_test_dots(test_results)
      test_results.map do |result|
        case result["status"]&.to_sym
        when :passed
          char = @config['pass_symbols_chars'].sample
          colorize(char, @config['colors']['pass_dot'])
        when :failed
          char = @config['fail_symbols_chars'].sample
          colorize(char, @config['colors']['fail_dot'])
        when :pending
          char = @config['pending_symbol']
          colorize(char, @config['colors']['pending_dot'])
        else
          ' '
        end
      end.join
    end

    def render_matrix_line(time_column, process_columns, test_dots)
      components = [time_column] + process_columns
      components << test_dots if test_dots && !test_dots.empty?
      components.join(' ')
    end

    def render_failure_summary(failures)
      return '' if failures.empty?

      lines = []
      lines << ''
      lines << colorize('FAILED EXAMPLES', 'red')
      lines << ''

      failures.each_with_index do |failure, index|
        lines << colorize("#{index + 1}. #{failure[:description]}", 'red')
        lines << colorize("   Location: #{failure[:location]}", 'cyan') if failure[:location]
        # Split message into lines and indent
        failure[:message]&.split("\n")&.each do |line|
          lines << "   #{line}"
        end
        lines << ''
      end

      lines.join("\n")
    end

    def render_final_summary(total_tests, failed_tests, pending_tests, total_duration, process_durations, process_count)
      lines = []
      lines << ''

      # Results summary
      summary_parts = []
      summary_parts << "#{total_tests} examples"
      summary_parts << colorize("#{failed_tests} failures", 'red') if failed_tests.positive?
      summary_parts << "#{pending_tests} pending" if pending_tests.positive?

      lines << summary_parts.join(', ')

      # Duration summary
      lines << ''
      lines << "Finished in #{format_duration(total_duration)} (parallel)"

      if process_durations && !process_durations.empty?
        lines << 'Process durations:'
        process_durations.each_with_index do |duration, index|
          lines << "  Process #{index + 1}: #{format_duration(duration)}"
        end
        total_process_time = process_durations.sum
        lines << "Total process time: #{format_duration(total_process_time)}"
      end

      lines << "Processes: #{process_count}" if process_count > 1
      lines << ''

      lines.join("\n")
    end

    private

    def detect_color_support
      # Check for color support
      return false if ENV['NO_COLOR']
      return true if ENV['FORCE_COLOR']

      # Check if stdout is a TTY
      $stdout.tty?
    end

    def colorize(text, color)
      return text unless @terminal_colors

      case color.to_s.downcase
      when 'red'
        Rainbow(text).red
      when 'green'
        Rainbow(text).green
      when 'blue'
        Rainbow(text).blue
      when 'yellow'
        Rainbow(text).yellow
      when 'cyan'
        Rainbow(text).cyan
      when 'magenta'
        Rainbow(text).magenta
      when 'white'
        Rainbow(text).white
      when 'black'
        Rainbow(text).black
      else
        text
      end
    end

    def format_duration(seconds)
      if seconds < 1
        "#{(seconds * 1000).round(2)} ms"
      elsif seconds < 60
        "#{seconds.round(2)} seconds"
      else
        minutes = (seconds / 60).to_i
        remaining_seconds = (seconds % 60).round(2)
        "#{minutes}m #{remaining_seconds}s"
      end
    end
  end
end
