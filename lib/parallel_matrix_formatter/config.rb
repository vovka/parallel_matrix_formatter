# frozen_string_literal: true

require 'yaml'

module ParallelMatrixFormatter
  # Loads the configuration: the gem's defaults deep-merged with the project's
  # own file, so a project only has to spell out the keys it changes.
  module Config
    DEFAULTS_PATH = File.expand_path('../../config/parallel_matrix_formatter.yml', __dir__)
    PROJECT_PATHS = ['parallel_matrix_formatter.yml', 'config/parallel_matrix_formatter.yml'].freeze

    module_function

    def load(path = project_path)
      defaults = read(DEFAULTS_PATH)
      path ? deep_merge(defaults, read(path)) : defaults
    end

    def project_path
      ENV['PARALLEL_MATRIX_FORMATTER_CONFIG'] || PROJECT_PATHS.find { |path| File.exist?(path) }
    end

    def read(path)
      YAML.safe_load_file(path) || {}
    end

    def deep_merge(base, overrides)
      base.merge(overrides) do |_key, old_value, new_value|
        old_value.is_a?(Hash) && new_value.is_a?(Hash) ? deep_merge(old_value, new_value) : new_value
      end
    end
  end
end
