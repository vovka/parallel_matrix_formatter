# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      class ProgressUpdatePolicy
        def initialize(config)
          @config = config
          @previous_progress_update_at = nil
          @previous_progress_update = {}
        end

        def should_update?(progress)
          return true if @config['update_always']

          return time_based_update?(progress) if time_update_configured?

          return percentage_based_update?(progress) if percentage_update_configured?
        end

        private

        def time_update_configured?
          @config['update_interval_seconds'].to_i > 0
        end

        def percentage_update_configured?
          0 < @config['update_percentage_threshold'].to_f && @config['update_percentage_threshold'].to_f <= 100.0
        end

        def time_based_update?(progress)
          interval = @config['update_interval_seconds'].to_i
          time_ok = @previous_progress_update_at.nil? || Time.now - @previous_progress_update_at > interval
          all_complete = !progress.empty? && progress.values.all? { |v| v >= 1.0 }
          result = (time_ok || all_complete) && !progress.empty?
          @previous_progress_update_at = Time.now if result
          result
        end

        def percentage_based_update?(progress)
          threshold = @config['update_percentage_threshold'].to_f / 100.0
          progress.any? do |process, prgrss|
            should_update = threshold_reached?(process, prgrss, threshold)
            @previous_progress_update[process] = prgrss if should_update
            should_update
          end
        end

        def threshold_reached?(process, progress, threshold)
          prev = @previous_progress_update[process]
          return true if prev.nil?

          return true if progress >= 1.0 && prev < 1.0

          (progress - prev.to_f).abs >= threshold
        end
      end
    end
  end
end
