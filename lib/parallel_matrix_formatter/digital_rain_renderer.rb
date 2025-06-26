# frozen_string_literal: true

module ParallelMatrixFormatter
  # DigitalRainRenderer creates the Matrix-style digital rain visual display
  # showing real-time test progress across multiple parallel processes.
  # Simplified version that outputs only ASCII characters without any color codes.
  #
  # Key responsibilities:
  # - Render time display with optional custom digit symbols
  # - Create animated process columns showing test progress percentages
  # - Display individual test results as character symbols (pass/fail/pending)
  # - Generate final summary with test counts and timing information
  # - Output pure ASCII text without any ANSI color codes or terminal formatting
  #
  # Note: All color and debug functionality has been removed as part of refactoring
  # to simplify the codebase and ensure consistent ASCII-only output.
  #
  class DigitalRainRenderer
    def initialize(config)
      @config = config
    end

    def render_time_column
      time_str = Time.now.strftime('%H:%M:%S')
      digit_chars = @config['digits']['symbols_chars']

      if @config['digits']['use_custom'] && @config['display']['show_time_digits']
        # Convert each digit to custom symbol
        time_str.chars.map do |char|
          if char.match?(/\d/)
            digit_chars[char.to_i]
          else
            char # Keep colons as is
          end
        end.join
      else
        time_str
      end
    end

    def render_process_column(process_id, progress_percent, column_width = nil, is_first_completion = false)
      width = column_width || @config['display']['column_width']

      if @config['fade_effect']['enabled']
        render_fade_effect_column(process_id, progress_percent, width, is_first_completion)
      else
        render_simple_column(process_id, progress_percent, width, is_first_completion)
      end
    end

    def render_test_dots(test_results)
      test_results.map do |result|
        # Handle both symbol and string status values (IPC converts symbols to strings)
        status = result[:status] || result['status']
        status_str = status.to_s
        case status_str
        when 'passed'
          @config['pass_symbols_chars'].sample
        when 'failed'
          @config['fail_symbols_chars'].sample
        when 'pending'
          @config['pending_symbol']
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
      lines << 'FAILED EXAMPLES'
      lines << ''

      failures.each_with_index do |failure, index|
        lines << "#{index + 1}. #{failure[:description]}"
        lines << "   Location: #{failure[:location]}" if failure[:location]
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
      summary_parts << "#{failed_tests} failures" if failed_tests.positive?
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

    def render_simple_column(_process_id, progress_percent, width, _is_first_completion = false)
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

      result
    end

    def render_fade_effect_column(process_id, progress_percent, width, _is_first_completion = false)
      rain_chars = @config['katakana_alphabet_chars']
      rain_density = @config['display']['rain_density']
      column_height = @config['fade_effect']['column_height']

      # Create a seed based on process_id for consistent bright spot positioning
      srand_seed = process_id.to_s.hash.abs

      # Generate column matrix (height x width)
      column_matrix = Array.new(column_height) do |_row|
        Array.new(width) do
          if rand < rain_density
            rain_chars.sample
          else
            ' '
          end
        end
      end

      # Determine bright spot position for this column (use seeded random)
      Random.srand(srand_seed + (Time.now.to_i / 5)) # Change every 5 seconds for more dynamic effect
      Random.srand # Reset to unseeded random

      # Overlay progress percentage on the middle row
      percent_str = "#{progress_percent}%"
      percent_row = column_height / 2
      percent_start = (width - percent_str.length) / 2
      percent_start = [0, percent_start].max

      # Replace rain characters with percentage in the middle row
      percent_str.chars.each_with_index do |char, i|
        pos = percent_start + i
        break if pos >= width

        column_matrix[percent_row][pos] = char
      end

      # Convert matrix to string rows
      string_rows = column_matrix.map { |row| row.join }

      # Return the middle row to maintain current display compatibility
      # In the future, this could be enhanced to return the full multi-row display
      string_rows[percent_row] || string_rows.first || ''
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
