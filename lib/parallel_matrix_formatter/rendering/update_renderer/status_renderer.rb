# This class is responsible for rendering the status of individual test examples.
# It selects appropriate status symbols and applies color formatting based on the test result
# and configured symbols.
module ParallelMatrixFormatter
  module Rendering
    class UpdateRenderer
      class StatusRenderer
        include ParallelMatrixFormatter::Rendering::FormatHelper

        def initialize(config)
          @config = config
        end

        def render(message)
          return "" unless message&.dig('message', 'status')

          status = message['message']['status'].to_sym
          process_symbol = (message['process_number'] - 1 + 'A'.ord).chr
          status_symbol = get_status_symbol(status)
          formatted_output = (@config['test_status_line_format'] || "{status_symbol}{process_symbol}")
            .gsub('{status_symbol}', status_symbol)
            .gsub('{process_symbol}', process_symbol)

          color = @config.dig('colors', {
            passed: 'pass_dot',
            failed: 'fail_dot',
            pending: 'pending_dot'
          }[status]) || ({ passed: 'green', failed: 'red', pending: 'yellow' }[status])

          color && AnsiColor.respond_to?(color) ? AnsiColor.send(color) { formatted_output } : formatted_output
        end

        private

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
end
