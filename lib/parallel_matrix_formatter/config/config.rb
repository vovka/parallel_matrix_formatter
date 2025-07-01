require 'singleton'
require 'yaml'
require 'erb'
require_relative 'parser'

module ParallelMatrixFormatter
  # The Config class is responsible for loading and parsing the configuration
  # for the ParallelMatrixFormatter gem from `config/parallel_matrix_formatter.yml`.
  # It provides access to various configuration settings, including suppression
  # options and update renderer configurations, and uses `Config::Parser` to
  # process specific configuration elements.
  class Config
    attr_accessor :suppress, :update_renderer_config

    def initialize
      raw = YAML.load_file(File.expand_path('../../../config/parallel_matrix_formatter.yml', __dir__))

      @suppress = raw['suppress'] || true

      @update_renderer_config = parse_config(raw['update_renderer'] || {})
    end

    private

    def parse_config(raw)
      # Use ConfigParser to parse progress_column format and pad
      if raw['progress_column'] && raw['progress_column']['percentage']
        raw['progress_column']['parsed'] = ParallelMatrixFormatter::Config::Parser.parse_progress_column_percentage(raw['progress_column']['percentage'])
        raw['progress_column']['pad_symbol'] = ParallelMatrixFormatter::Config::Parser.pad_symbol(raw)
        raw['progress_column']['pad_color'] = ParallelMatrixFormatter::Config::Parser.pad_color(raw)
      end
      raw
    end
  end
end
