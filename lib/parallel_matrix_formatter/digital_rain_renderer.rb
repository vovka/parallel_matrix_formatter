# frozen_string_literal: true

require_relative 'ansi_colorizer'
require_relative 'failure_summary_renderer'

module ParallelMatrixFormatter
  # DigitalRainRenderer creates the Matrix-style digital rain visual display
  # showing real-time test progress across multiple parallel processes.
  # 
  # Refactored to only use ANSI color codes without environment detection.
  # This simplifies the codebase by removing debug logic and complex color detection.
  #
  # Key responsibilities:
  # - Render time display with optional custom digit symbols
  # - Create animated process columns showing test progress percentages
  # - Display individual test results as colored dots (pass/fail/pending)
  # - Generate final summary with test counts and timing information
  # - Apply ANSI colors consistently without environment checks
  #
  class DigitalRainRenderer
    def initialize(config)
      @config = config
      @failure_renderer = FailureSummaryRenderer.new(config)
      # Simplified: always use ANSI colors, no environment detection
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
        AnsiColorizer.colorize(custom_time, @config['colors']['time'])
      else
        AnsiColorizer.colorize(time_str, @config['colors']['time'])
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
          AnsiColorizer.colorize(char, @config['colors']['pass_dot'])
        when 'failed'
          char = @config['fail_symbols_chars'].sample
          AnsiColorizer.colorize(char, @config['colors']['fail_dot'])
        when 'pending'
          char = @config['pending_symbol']
          AnsiColorizer.colorize(char, @config['colors']['pending_dot'])
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

    # Delegate failure summary rendering to specialized renderer
    def render_failure_summary(failures)
      @failure_renderer.render_failure_summary(failures)
    end

    # Delegate final summary rendering to specialized renderer  
    def render_final_summary(total_tests, failed_tests, pending_tests, total_duration, process_durations, process_count)
      @failure_renderer.render_final_summary(total_tests, failed_tests, pending_tests, total_duration, process_durations, process_count)
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
                            AnsiColorizer.colorize(char, percent_color)
                          else
                            AnsiColorizer.colorize(char, @config['colors']['rain'])
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
            AnsiColorizer.colorize(char, percent_color)
          else
            # Calculate fade level based on distance from bright spot
            distance_from_bright = (row_index - bright_row).abs
            fade_level = [distance_from_bright + 1, fade_levels].min

            # Apply fade effect coloring
            color = calculate_fade_color(fade_level, fade_levels)
            AnsiColorizer.colorize(char, color)
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
  end
end
