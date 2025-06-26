# frozen_string_literal: true

require_relative 'ipc_config_processor'

module ParallelMatrixFormatter
  # ConfigProcessor handles configuration processing and transformation.
  # This class was extracted from ConfigLoader to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Process configuration by converting strings to character arrays
  # - Compute derived configuration values
  # - Apply IPC configuration processing
  # - Prepare configuration for application use
  #
  class ConfigProcessor
    # Process configuration by converting strings to more usable formats
    # @param config [Hash] Configuration to process
    # @return [Hash] Processed configuration with character arrays and computed values
    def self.process_config(config)
      # Convert symbol strings to character arrays for easier sampling
      config['katakana_alphabet_chars'] = config['katakana_alphabet'].chars
      config['pass_symbols_chars'] = config['pass_symbols'].chars
      config['fail_symbols_chars'] = config['fail_symbols'].chars

      # Process digits
      config['digits']['symbols_chars'] = if config['digits']['use_custom']
                                            config['digits']['symbols'].chars
                                          else
                                            '0123456789'.chars
                                          end

      # Process IPC configuration - generate paths and validate settings
      IpcConfigProcessor.process_ipc_config(config)

      config
    end

    # Deep merge two hashes, with second hash taking precedence
    # @param hash1 [Hash] Base hash
    # @param hash2 [Hash] Hash to merge in (takes precedence)
    # @return [Hash] Merged hash
    def self.deep_merge(hash1, hash2)
      result = hash1.dup
      hash2.each do |key, value|
        result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
                        deep_merge(result[key], value)
                      else
                        value
                      end
      end
      result
    end

    # Freeze the configuration object recursively to prevent modifications
    # @param config [Hash] Configuration to freeze
    # @return [Hash] Frozen configuration
    def self.freeze_config(config)
      case config
      when Hash
        config.each { |k, v| freeze_config(v) }
        config.freeze
      when Array
        config.each { |v| freeze_config(v) }
        config.freeze
      else
        config.freeze if config.respond_to?(:freeze)
      end
    end
  end
end