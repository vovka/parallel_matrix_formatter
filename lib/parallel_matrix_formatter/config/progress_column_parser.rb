class ParallelMatrixFormatter::Config
  class ProgressColumnParser
    # The ProgressColumnParser module is responsible for parsing specific configuration strings
    # related to the progress column formatting. It extracts details like alignment,
    # width, and color from format strings defined in the configuration file.
    FORMAT_REGEX = /\{v\}%:(\^|\-|\+)?(\d+)/

    def self.parse(raw)
      # Parse update_renderer section if it exists
      parse_update_renderer_section(raw['update_renderer'])if raw['update_renderer']
      # Also parse root level for backward compatibility
      parse_update_renderer_section(raw) if raw['progress_column'] && raw['progress_column']['percentage']
      raw
    end

    def self.parse_update_renderer_section(update_renderer)
      if update_renderer['progress_column'] && update_renderer['progress_column']['percentage']
        update_renderer['progress_column']['parsed'] = parse_progress_column_percentage(update_renderer['progress_column']['percentage'])
      end

      if update_renderer['progress_column'] && update_renderer['progress_column']['pad']
        update_renderer['progress_column']['pad_symbol'] = pad_symbol_from_config(update_renderer, 'progress_column')
        update_renderer['progress_column']['pad_color'] = pad_color_from_config(update_renderer, 'progress_column')
      end
    end

    def self.parse_progress_column_percentage(percentage)
      match = percentage['format'].match(FORMAT_REGEX)
      {
        value: '{v}%',
        align: match[1] || '^',
        width: match ? match[2].to_i : 10,
        color: percentage['color'] || 'red'
      }
    end

    def self.pad_symbol_from_config(config, section)
      config.dig(section, 'pad', 'symbol') || '='
    end

    def self.pad_color_from_config(config, section)
      config.dig(section, 'pad', 'color')
    end

    # Backward compatibility methods
    def self.pad_symbol(config)
      pad_symbol_from_config(config, 'progress_column')
    end

    def self.pad_color(config)
      pad_color_from_config(config, 'progress_column')
    end
  end
end
