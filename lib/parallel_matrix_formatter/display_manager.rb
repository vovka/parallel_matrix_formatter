# frozen_string_literal: true

require_relative 'threshold_checker'

module ParallelMatrixFormatter
  # DisplayManager handles display updates and rendering coordination for the orchestrator.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Determine when display updates should occur based on configured strategies
  # - Manage display state and line rendering
  # - Coordinate with renderer for visual output
  # - Handle live test result display
  #
  class DisplayManager
    def initialize(config, renderer, processes, process_thresholds)
      @config = config
      @renderer = renderer
      @processes = processes
      @process_thresholds = process_thresholds
      @last_update_time = Time.now
      @current_line_rendered = false
      @threshold_checker = ThresholdChecker.new(config, processes, process_thresholds)
    end

    # Check if display should be updated based on configured strategies
    # @return [Boolean] True if display should be updated
    def should_update_display?
      current_time = Time.now.to_f
      threshold_crossed = @threshold_checker.threshold_crossed?

      # Check time-based strategy if configured
      time_based_update = @config['update']['interval_seconds'] &&
                         (current_time - @last_update_time.to_f) / 1_000 >= @config['update']['interval_seconds']

      should_update = threshold_crossed || time_based_update
      @last_update_time = current_time if should_update
      should_update
    end

    # Update the base display (time and process columns)
    def update_base_display
      return if @processes.empty?

      finalize_current_line
      time_column = @renderer.render_time_column

      # Render process columns
      process_columns = @processes.values.map do |process|
        is_first_completion = (process[:progress_percent] >= 100 && !process[:first_completion_shown])
        process[:first_completion_shown] = true if is_first_completion

        @renderer.render_process_column(
          process[:id], process[:progress_percent],
          @config['display']['column_width'], is_first_completion
        )
      end

      # Render base line (time + processes only)
      base_line = @renderer.render_matrix_line(time_column, process_columns, '')
      [base_line, true] # Return display content and rendered state
    end

    # Render a live test result
    # @param test_result [Hash] The test result to render
    # @return [String, nil] The rendered test dot or nil if no base line is rendered
    def render_live_test_result(test_result)
      # Only render if we have a base line rendered
      return nil unless @current_line_rendered

      @renderer.render_test_dots([test_result])
    end

    # Finalize current line display
    def finalize_current_line
      # Move to next line when we're done with current line
      if @current_line_rendered
        @current_line_rendered = false
        true # Indicate line was finalized
      else
        false
      end
    end

    # Set the current line as rendered
    def set_line_rendered
      @current_line_rendered = true
    end
  end
end