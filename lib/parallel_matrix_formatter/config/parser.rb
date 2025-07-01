module ParallelMatrixFormatter
  class Config
    module Parser
      # The Parser module is responsible for parsing specific configuration strings
      # related to the progress column formatting. It extracts details like alignment,
      # width, and color from format strings defined in the configuration file.
      FORMAT_REGEX = /\{v\}%:(\^|\-|\+)?(\d+)/

      def self.parse_progress_column_percentage(percentage)
        match = percentage['format'].match(FORMAT_REGEX)
        {
          value: '{v}%',
          align: match ? match[1] : '^',
          width: match ? match[2].to_i : 10,
          color: percentage['color'] || 'red'
        }
      end

      def self.pad_symbol(config)
        config.dig('progress_column', 'pad', 'symbol') || '='
      end

      def self.pad_color(config)
        config.dig('progress_column', 'pad', 'color')
      end
    end
  end
end
