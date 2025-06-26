# frozen_string_literal: true

module ParallelMatrixFormatter
  # ProgressTracker handles test execution progress tracking and calculation.
  # This class was extracted from ProcessFormatter to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Track current example count and total examples
  # - Calculate progress percentages
  # - Determine when progress updates should be sent
  # - Apply configurable threshold-based update logic
  #
  class ProgressTracker
    def initialize(config, total_examples)
      @config = config
      @total_examples = total_examples
      @current_example = 0
      @last_progress_percent = 0
    end

    # Increment current example count (called when example starts)
    def increment_example
      @current_example += 1
    end

    # Calculate current progress percentage
    # @return [Integer] Progress percentage (0-100)
    def calculate_progress_percent
      return 0 if @total_examples.zero?
      ((@current_example.to_f / @total_examples) * 100).to_i
    end

    # Determine if progress update should be sent based on configured thresholds
    # @param current_percent [Integer] Current progress percentage
    # @return [Boolean] True if update should be sent
    def should_send_progress_update?(current_percent)
      # Always send first update
      return true if @last_progress_percent.zero? && current_percent.positive?

      # Send if progress threshold is met using configured thresholds
      thresholds = @config['update']['percent_thresholds'] || [5]
      progress_diff = current_percent - @last_progress_percent

      thresholds.any? { |threshold| progress_diff >= threshold }
    end

    # Update the last sent progress percentage
    # @param percent [Integer] The progress percentage that was sent
    def update_last_progress_percent(percent)
      @last_progress_percent = percent
    end

    # Get current example count
    # @return [Integer] Current example number
    def current_example
      @current_example
    end

    # Get total examples count
    # @return [Integer] Total number of examples
    def total_examples
      @total_examples
    end
  end
end