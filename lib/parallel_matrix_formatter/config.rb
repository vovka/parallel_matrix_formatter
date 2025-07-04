require 'singleton'
require 'yaml'
require 'erb'

module ParallelMatrixFormatter
  # The Config class is responsible for loading and parsing the configuration
  # for the ParallelMatrixFormatter gem from `config/parallel_matrix_formatter.yml`.
  # It provides access to various configuration settings, including suppression
  # options and update renderer configurations, and uses `Config::Parser` to
  # process specific configuration elements.
  class Config
    @parsers = []

    def self.register_parser(parser)
      @parsers << parser
    end

    register_parser(ProgressColumnParser)

    attr_accessor :output_suppressor, :update_renderer

    def initialize
      raw = YAML.load_file(File.expand_path('../../config/parallel_matrix_formatter.yml', __dir__))
      parsed = parse_config(raw)

      @output_suppressor = parsed['output_suppressor']
      @update_renderer = parsed['update_renderer']
    end

    private

    def parse_config(raw)
      self.class.parse_config(raw)
    end

    def self.parse_config(raw)
      @parsers.each_with_object(raw) do |parser, raw|
        raw = parser.parse(raw)
      end
    end
  end
end
