module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        reset: "\e[0m"
      }.freeze

      def initialize(test_env_number)
        @test_env_number = test_env_number
        @progress = {}
        @config = ParallelMatrixFormatter::Config.instance.update_renderer_config
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
        update_interval = @config['update_interval_seconds'] || 3
        should_update_time = @previous_progress_update_at.nil? || Time.now - @previous_progress_update_at > update_interval
        should_update_all_complete = !@progress.empty? && @progress.values.all? { |v| v >= 1.0 }

        if (should_update_time || should_update_all_complete) && !@progress.empty?
          @previous_progress_update_at = Time.now
          progress_info = @progress.sort.map { |k, v| "#{k}:#{(v * 100).round(2)}%" }.join(', ')
          format_string = @config['progress_line_format'] || "\nUpdate is run from process {process_number}. Progress: {progress_info} "
          format_string.gsub('{time}', Time.now.strftime("%H:%M:%S")).gsub('{process_number}', @test_env_number.to_s).gsub('{progress_info}', progress_info)
        else
          ""
        end
      end

      def test_example_status(message)
        return "" unless message && message['message'] && message['message']['status']

        status = message['message']['status'].to_sym
        process_symbol = (message['process_number'] - 1 + 'A'.ord).chr
        status_symbol = get_status_symbol(status)

        format_string = @config['test_status_line_format'] || "{status_symbol}{process_symbol}"
        formatted_output = format_string.gsub('{status_symbol}', status_symbol).gsub('{process_symbol}', process_symbol)

        case status
        when :passed
          "#{COLORS[:green]}#{formatted_output}#{COLORS[:reset]}"
        when :failed
          "#{COLORS[:red]}#{formatted_output}#{COLORS[:reset]}"
        when :pending
          "#{COLORS[:yellow]}#{formatted_output}#{COLORS[:reset]}"
        end
      end

      def get_status_symbol(status)
        symbols = @config.dig('status_symbols', status.to_s)
        if symbols.is_a?(String)
          symbols.each_char.to_a.sample
        else
          case status
          when :passed then "✅"
          when :failed then "❌"
          when :pending then "⏳"
          else ""
          end
        end
      end
    end
  end
end
