# frozen_string_literal: true

begin
  require 'rainbow'
rescue LoadError
  # Rainbow gem not available - will use ANSI fallback
end

module ParallelMatrixFormatter
  class DigitalRainRenderer
    def initialize(config)
      @config = config
      @terminal_colors = detect_color_support
      @color_method = determine_color_method
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
          char = @config['pass_symbols_chars'].sample
          colorize(char, @config['colors']['pass_dot'])
        when 'failed'
          char = @config['fail_symbols_chars'].sample
          colorize(char, @config['colors']['fail_dot'])
        when 'pending'
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

    def render_simple_column(_process_id, progress_percent, width, is_first_completion = false)
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

      # Determine percentage color based on completion status
      percent_color = determine_percent_color(progress_percent, is_first_completion)

      # Apply colors - rain in green, percentage in determined color
      colored_result = ''
      result.chars.each_with_index do |char, i|
        colored_result += if i >= percent_start && i < percent_end && i - percent_start < percent_str.length
                            colorize(char, percent_color)
                          else
                            colorize(char, @config['colors']['rain'])
                          end
      end

      colored_result
    end

    def render_fade_effect_column(process_id, progress_percent, width, is_first_completion = false)
      rain_chars = @config['katakana_alphabet_chars']
      rain_density = @config['display']['rain_density']
      column_height = @config['fade_effect']['column_height']
      fade_levels = @config['fade_effect']['fade_levels']

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
      bright_row = Random.rand(column_height)
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

      # Determine percentage color based on completion status
      percent_color = determine_percent_color(progress_percent, is_first_completion)

      # Convert matrix to colored string rows
      colored_rows = column_matrix.map.with_index do |row, row_index|
        row.map.with_index do |char, col_index|
          # Determine if this is part of the percentage display
          is_percent = row_index == percent_row &&
                       col_index >= percent_start &&
                       col_index < percent_start + percent_str.length

          if is_percent
            colorize(char, percent_color)
          else
            # Calculate fade level based on distance from bright spot
            distance_from_bright = (row_index - bright_row).abs
            fade_level = [distance_from_bright + 1, fade_levels].min

            # Apply fade effect coloring
            color = calculate_fade_color(fade_level, fade_levels)
            colorize(char, color)
          end
        end.join
      end

      # Return the middle row to maintain current display compatibility
      # In the future, this could be enhanced to return the full multi-row display
      colored_rows[percent_row] || colored_rows.first || ''
    end

    def determine_percent_color(progress_percent, is_first_completion)
      if progress_percent >= 100
        if is_first_completion
          # First time showing 100% - use red
          @config['colors']['percent']
        else
          # Subsequent times showing 100% - use background color (green)
          @config['colors']['rain']
        end
      else
        # Not at 100% yet - use regular percent color (red)
        @config['colors']['percent']
      end
    end

    def calculate_fade_color(fade_level, max_levels)
      # fade_level: 1 = brightest, max_levels = dimmest
      bright_color = @config['fade_effect']['bright_color']
      dim_color = @config['fade_effect']['dim_color']

      case fade_level
      when 1
        bright_color
      when max_levels
        dim_color
      else
        # Intermediate levels - create gradient effect
        case fade_level
        when 2
          bright_color # Still quite bright
        when 3
          @config['colors']['rain'] # Medium brightness
        else
          dim_color # Dimmer levels
        end
      end
    end

    def detect_color_support
      # Check for explicit color disabling
      return false if ENV['NO_COLOR']

      # Check for explicit color forcing
      return true if ENV['FORCE_COLOR']

      # Check configuration method
      color_method = @config.dig('colors', 'method')&.to_s&.downcase
      return false if color_method == 'none'

      # Check for CI environments that support colors
      ci_environments = %w[
        CI CONTINUOUS_INTEGRATION
        GITHUB_ACTIONS GITHUB_WORKFLOW
        TRAVIS CIRCLECI JENKINS_URL
        BUILDKITE GITLAB_CI
        APPVEYOR TEAMCITY_VERSION
      ]

      return true if ci_environments.any? { |env| ENV[env] }

      # Check if stdout is a TTY (traditional terminal detection)
      $stdout.tty?
    end

    def determine_color_method
      color_method = @config.dig('colors', 'method')&.to_s&.downcase || 'auto'

      case color_method
      when 'rainbow'
        :rainbow
      when 'ansi'
        :ansi
      when 'none'
        :none
      else # 'auto'
        :auto
      end
    end

    def colorize(text, color)
      return text unless @terminal_colors

      case @color_method
      when :ansi
        colorize_with_ansi(text, color)
      when :rainbow
        colorize_with_rainbow(text, color)
      when :auto
        # Try rainbow first, fallback to ANSI
        begin
          colorize_with_rainbow(text, color)
        rescue StandardError
          colorize_with_ansi(text, color)
        end
      else
        text
      end
    end

    def colorize_with_rainbow(text, color)
      # Check if Rainbow is available
      return colorize_with_ansi(text, color) unless defined?(Rainbow)

      case color.to_s.downcase
      when 'red'
        Rainbow(text).red
      when 'green'
        Rainbow(text).green
      when 'bright_green'
        Rainbow(text).green.bright
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

    def colorize_with_ansi(text, color)
      return text unless @terminal_colors

      # ANSI color codes
      color_codes = {
        'red' => "\e[31m",
        'green' => "\e[32m",
        'bright_green' => "\e[1;32m",
        'blue' => "\e[34m",
        'yellow' => "\e[33m",
        'cyan' => "\e[36m",
        'magenta' => "\e[35m",
        'white' => "\e[37m",
        'black' => "\e[30m"
      }

      reset_code = "\e[0m"
      color_code = color_codes[color.to_s.downcase]

      if color_code
        "#{color_code}#{text}#{reset_code}"
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
