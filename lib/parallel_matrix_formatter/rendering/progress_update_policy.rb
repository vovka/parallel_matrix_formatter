# frozen_string_literal: true

module ParallelMatrixFormatter
  module Rendering
    # Decides whether a fresh progress line is due. The first configured rule
    # wins: always, then the time interval, then the percentage threshold.
    class ProgressUpdatePolicy
      def initialize(config, total_processes)
        @total_processes = total_processes
        @always = config['always']
        @interval = config['interval_seconds'].to_f
        @threshold = config['percent_threshold'].to_f
        @last_update_at = nil
        @last_progress = {}
      end

      # @param progress [Hash{Integer => Float}] latest progress of every process
      def update?(progress)
        return true if @always
        return interval_elapsed?(progress) if @interval.positive?
        return threshold_crossed?(progress) if @threshold.positive?

        false
      end

      private

      def interval_elapsed?(progress)
        due = @last_update_at.nil? || Time.now - @last_update_at >= @interval || all_complete?(progress)
        @last_update_at = Time.now if due
        due
      end

      def threshold_crossed?(progress)
        crossed = progress.select { |process, value| crossed?(@last_progress[process], value) }
        @last_progress.merge!(crossed)
        crossed.any?
      end

      def crossed?(previous, current)
        return true if previous.nil?
        return true if current >= 1.0 && previous < 1.0

        (current - previous) * 100 >= @threshold
      end

      def all_complete?(progress)
        progress.size == @total_processes && progress.values.all? { |value| value >= 1.0 }
      end
    end
  end
end
