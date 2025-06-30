require 'singleton'
require 'yaml'
require 'erb'
require_relative 'parser'

module ParallelMatrixFormatter
  class Config
    class Config
      include Singleton

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
end
