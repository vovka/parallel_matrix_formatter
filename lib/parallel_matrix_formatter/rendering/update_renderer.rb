module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        reset: "\e[0m"
      }.freeze
      SECONDS_TO_UPDATE = 3

      def initialize(test_env_number)
        @test_env_number = test_env_number
        @progress = {}
      end

      def update(message)
        if message && message['process_number'] && message['message']
          @progress[message['process_number']] = message['message']['progress']
        end

        str = ""
        str += progress_update
        str += test_example_status(message)
        str
      end

      private

      def progress_update
        should_update_time = @previous_progress_update_at.nil? || Time.now - @previous_progress_update_at > SECONDS_TO_UPDATE
        should_update_all_complete = !@progress.empty? && @progress.values.all? { |v| v >= 1.0 }

        if (should_update_time || should_update_all_complete) && !@progress.empty?
          @previous_progress_update_at = Time.now
          progress_info = @progress.sort.map { |k, v| "#{k}:#{(v * 100).round(2)}%" }.join(', ')
          "\nUpdate is run from process #{@test_env_number}. Progress: #{progress_info} "
        else
          ""
        end
      end

      def test_example_status(message)
        return "" unless message && message['message'] && message['message']['status']

        status = message['message']['status'].to_sym
        symbol = (message['process_number'] - 1 + 'A'.ord).chr

        case status
        when :passed
          render_passed(symbol)
        when :failed
          render_failed(symbol)
        when :pending
          render_pending(symbol)
        end
      end

      def render_passed(symbol)
        "#{COLORS[:green]}#{symbol}#{COLORS[:reset]}"
      end

      def render_failed(symbol)
        "#{COLORS[:red]}#{symbol}#{COLORS[:reset]}"
      end

      def render_pending(symbol)
        "#{COLORS[:yellow]}#{symbol}#{COLORS[:reset]}"
      end
    end
  end
end
