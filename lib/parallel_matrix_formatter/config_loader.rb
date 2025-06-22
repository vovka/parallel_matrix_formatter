# frozen_string_literal: true

require "psych"
require "pathname"

module ParallelMatrixFormatter
  class ConfigLoader
    class ConfigError < StandardError; end

    DEFAULT_CONFIG_PATHS = [
      "parallel_matrix_formatter.yml",
      "config/parallel_matrix_formatter.yml",
      ".parallel_matrix_formatter.yml"
    ].freeze

    DEFAULT_CONFIG = {
      "digits" => {
        "use_custom" => false,
        "symbols" => "0123456789"
      },
      "katakana_alphabet" => "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン",
      "pass_symbols" => "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン",
      "fail_symbols" => "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ",
      "pending_symbol" => "🥄",
      "colors" => {
        "time" => "green",
        "percent" => "red",
        "rain" => "green",
        "pass_dot" => "green",
        "fail_dot" => "red",
        "pending_dot" => "white"
      },
      "update" => {
        "interval_seconds" => 1,
        "percent_thresholds" => [5]
      },
      "display" => {
        "column_width" => 15,
        "show_time_digits" => true,
        "rain_density" => 0.7
      }
    }.freeze

    def self.load
      new.load
    end

    def load
      config_path = find_config_file
      config = config_path ? load_config_file(config_path) : {}
      merged_config = merge_with_defaults(config)
      validate_config(merged_config)
      process_config(merged_config)
    end

    private

    def find_config_file
      # Check environment variable first
      if ENV["PARALLEL_MATRIX_FORMATTER_CONFIG"]
        path = Pathname.new(ENV["PARALLEL_MATRIX_FORMATTER_CONFIG"])
        return path if path.exist?
        raise ConfigError, "Config file specified in PARALLEL_MATRIX_FORMATTER_CONFIG not found: #{path}"
      end

      # Check default paths
      DEFAULT_CONFIG_PATHS.each do |path|
        pathname = Pathname.new(path)
        return pathname if pathname.exist?
      end

      nil
    end

    def load_config_file(path)
      Psych.safe_load(File.read(path))
    rescue Psych::SyntaxError => e
      raise ConfigError, "Invalid YAML in config file #{path}: #{e.message}"
    rescue StandardError => e
      raise ConfigError, "Error loading config file #{path}: #{e.message}"
    end

    def merge_with_defaults(config)
      deep_merge(DEFAULT_CONFIG, config)
    end

    def validate_config(config)
      validate_digits_section(config["digits"])
      validate_required_sections(config)
    end

    def validate_digits_section(digits_config)
      return unless digits_config["use_custom"]

      symbols = digits_config["symbols"]
      return if symbols.nil?

      # Convert to array of characters to handle Unicode properly
      symbol_chars = symbols.chars
      return if symbol_chars.length == 10

      raise ConfigError, "Custom digits must contain exactly 10 symbols, got #{symbol_chars.length}: '#{symbols}'"
    end

    def validate_required_sections(config)
      required_sections = %w[colors update display]
      required_sections.each do |section|
        next if config[section].is_a?(Hash)

        raise ConfigError, "Missing or invalid '#{section}' section in configuration"
      end
    end

    def process_config(config)
      # Convert symbol strings to character arrays for easier sampling
      config["katakana_alphabet_chars"] = config["katakana_alphabet"].chars
      config["pass_symbols_chars"] = config["pass_symbols"].chars
      config["fail_symbols_chars"] = config["fail_symbols"].chars
      
      # Process digits
      if config["digits"]["use_custom"]
        config["digits"]["symbols_chars"] = config["digits"]["symbols"].chars
      else
        config["digits"]["symbols_chars"] = "0123456789".chars
      end

      config
    end

    def deep_merge(hash1, hash2)
      result = hash1.dup
      hash2.each do |key, value|
        if result[key].is_a?(Hash) && value.is_a?(Hash)
          result[key] = deep_merge(result[key], value)
        else
          result[key] = value
        end
      end
      result
    end
  end
end