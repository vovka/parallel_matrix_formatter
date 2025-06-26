# frozen_string_literal: true

module ParallelMatrixFormatter
  # ThresholdChecker handles threshold-based update logic for display management.
  # This utility was extracted to keep DisplayManager under 100 lines.
  #
  # Key responsibilities:
  # - Check if processes have crossed configured percentage thresholds
  # - Track threshold progress for each process
  # - Determine when updates are needed based on threshold changes
  #
  class ThresholdChecker
    def initialize(config, processes, process_thresholds)
      @config = config
      @processes = processes
      @process_thresholds = process_thresholds
    end

    # Check if any process has crossed a threshold
    # @return [Boolean] True if a threshold was crossed
    def threshold_crossed?
      thresholds = @config['update']['percent_thresholds'] || [5]
      
      @processes.each do |process_id, process|
        current_progress = process[:progress_percent]
        last_threshold = @process_thresholds[process_id] || 0

        thresholds.each do |threshold|
          current_level = (current_progress / threshold).floor * threshold
          last_level = (last_threshold / threshold).floor * threshold

          if current_level > last_level
            @process_thresholds[process_id] = current_progress
            return true
          end
        end
      end
      false
    end
  end
end