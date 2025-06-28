require 'singleton'
require 'yaml'
require 'erb'

module ParallelMatrixFormatter
  class Config
    include Singleton

    attr_accessor :suppress, :update_renderer_config

    def initialize
      @suppress = true
      load_config
    end

    private

    def load_config
      config_file = File.expand_path('../../../config/parallel_matrix_formatter.yml', __FILE__)
      if File.exist?(config_file)
        config = YAML.load(ERB.new(File.read(config_file)).result)
        @update_renderer_config = config['update_renderer'] || {}
      else
        @update_renderer_config = {}
      end
    end
  end
end
