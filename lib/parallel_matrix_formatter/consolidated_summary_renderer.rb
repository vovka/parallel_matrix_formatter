# frozen_string_literal: true

module ParallelMatrixFormatter
  # Renders consolidated summary from all parallel test processes
  class ConsolidatedSummaryRenderer
    def initialize(output, start_time)
      @output = output
      @start_time = start_time
    end

    def render(process_summaries)
      totals = calculate_totals(process_summaries)
      
      @output.puts "\n"
      render_failures(totals[:failed_examples])
      render_summary_line(totals)
      render_timing(totals[:total_process_time])
    end

    private

    def calculate_totals(process_summaries)
      {
        total_examples: sum_total_examples(process_summaries),
        failed_examples: collect_failed_examples(process_summaries),
        total_pending: sum_pending_count(process_summaries),
        total_process_time: sum_duration(process_summaries)
      }
    end

    def sum_total_examples(process_summaries)
      process_summaries.values.sum { |summary| summary['total_examples'] }
    end

    def collect_failed_examples(process_summaries)
      process_summaries.values.flat_map { |summary| summary['failed_examples'] }
    end

    def sum_pending_count(process_summaries)
      process_summaries.values.sum { |summary| summary['pending_count'] }
    end

    def sum_duration(process_summaries)
      process_summaries.values.sum { |summary| summary['duration'] }
    end

    def render_failures(failed_examples)
      return if failed_examples.empty?
      
      @output.puts "Failures:"
      @output.puts
      render_individual_failures(failed_examples)
    end

    def render_individual_failures(failed_examples)
      failed_examples.each_with_index do |failure, index|
        render_failure_details(failure, index + 1)
      end
    end

    def render_failure_details(failure, index)
      @output.puts "  #{index}) #{failure['description']}"
      @output.puts "     #{failure['location']}" if failure['location']
      @output.puts "     #{failure['message']}" if failure['message']
      @output.puts "     #{failure['formatted_backtrace']}" if failure['formatted_backtrace']
      @output.puts
    end

    def render_summary_line(totals)
      failure_count = totals[:failed_examples].length
      summary_line = format_summary_line(totals[:total_examples], failure_count, totals[:total_pending])
      @output.puts summary_line
    end

    def render_timing(total_process_time)
      wall_clock_time = Time.now - @start_time
      timing_line = "Finished in #{format_duration(wall_clock_time)} (files took #{format_duration(total_process_time)} to load)"
      @output.puts timing_line
    end

    def format_summary_line(total, failures, pending)
      parts = ["#{total} example#{'s' if total != 1}"]
      parts << "#{failures} failure#{'s' if failures != 1}" if failures > 0
      parts << "#{pending} pending" if pending > 0
      parts.join(', ')
    end

    def format_duration(seconds)
      return "#{seconds.round(2)} seconds" if seconds < 60
      
      minutes = (seconds / 60).floor
      remaining_seconds = seconds % 60
      "#{minutes} minute#{'s' if minutes != 1} #{remaining_seconds.round(2)} seconds"
    end
  end
end