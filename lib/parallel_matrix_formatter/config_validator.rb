# frozen_string_literal: true

module ParallelMatrixFormatter
  # ConfigValidator handles configuration validation and constraint checking.
  # This class was extracted from ConfigLoader to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Validate configuration structure and required sections
  # - Check custom digits configuration constraints
  # - Ensure configuration integrity before processing
  # - Provide descriptive error messages for invalid configurations
  #
  class ConfigValidator
    class ConfigError < StandardError; end

    # Validate the final configuration for required sections and constraints
    # @param config [Hash] Configuration to validate
    # @raise [ConfigError] If configuration is invalid
    def self.validate_config(config)
      validate_digits_section(config['digits'])
      validate_required_sections(config)
    end

    # Validate the digits section of configuration
    # @param digits_config [Hash] Digits section configuration
    # @raise [ConfigError] If custom digits configuration is invalid
    def self.validate_digits_section(digits_config)
      return unless digits_config['use_custom']

      symbols = digits_config['symbols']
      return if symbols.nil?

      # Convert to array of characters to handle Unicode properly
      symbol_chars = symbols.chars
      return if symbol_chars.length == 10

      raise ConfigError, "Custom digits must contain exactly 10 symbols, got #{symbol_chars.length}: '#{symbols}'"
    end

    # Validate that required configuration sections are present
    # @param config [Hash] Full configuration
    # @raise [ConfigError] If required sections are missing
    def self.validate_required_sections(config)
      required_sections = %w[colors update display]
      required_sections.each do |section|
        next if config[section].is_a?(Hash)

        raise ConfigError, "Missing or invalid '#{section}' section in configuration"
      end
    end
  end
end