# frozen_string_literal: true

require "rspec/core/formatters/base_formatter"
require_relative "config_loader"
require_relative "suppression_layer"
require_relative "orchestrator"
require_relative "process_formatter"

module ParallelMatrixFormatter
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    RSpec::Core::Formatters.register self,
                                     :start,
                                     :example_started,
                                     :example_passed,
                                     :example_failed,
                                     :example_pending,
                                     :stop,
                                     :close

    def initialize(output)
      super(output)
      @config = load_config
      @process_formatter = nil
      @orchestrator = nil
      @suppression_layer = nil
      @is_orchestrator_process = false
      
      setup_environment
    end

    def start(start_notification)
      total_examples = start_notification.count
      
      if orchestrator_process?
        start_orchestrator
      else
        start_process_formatter(total_examples)
      end
    end

    def example_started(notification)
      @process_formatter&.example_started(notification)
    end

    def example_passed(notification)
      @process_formatter&.example_passed(notification)
    end

    def example_failed(notification)
      @process_formatter&.example_failed(notification)
    end

    def example_pending(notification)
      @process_formatter&.example_pending(notification)
    end

    def stop(_stop_notification)
      if @is_orchestrator_process
        # Give child processes time to complete
        sleep(@config["update"]["interval_seconds"] || 1)
        @orchestrator&.stop
      else
        @process_formatter&.stop
      end
    end

    def close(_close_notification)
      @suppression_layer&.restore
    end

    private

    def load_config
      ConfigLoader.load
    rescue ConfigLoader::ConfigError => e
      $stderr.puts "Configuration error: #{e.message}"
      exit 1
    end

    def setup_environment
      # Apply suppression layer based on configuration
      suppression_level = determine_suppression_level
      @suppression_layer = SuppressionLayer.new(suppression_level)
      @suppression_layer.suppress unless orchestrator_process?
    end

    def determine_suppression_level
      # Check environment variables for suppression control
      case ENV["PARALLEL_MATRIX_FORMATTER_SUPPRESS"]
      when "none", "0", "false"
        :none
      when "ruby_warnings", "1"
        :ruby_warnings
      when "app_warnings", "2"
        :app_warnings
      when "app_output", "3"
        :app_output
      when "gem_output", "4"
        :gem_output
      when "all", "5", nil
        :all
      else
        :all
      end
    end

    def orchestrator_process?
      # Check if this is the main process that should act as orchestrator
      # This could be determined by environment variables set by parallel_split_tests
      # or by being the first process to start
      
      # For now, use a simple heuristic: if no server path is set, we're the orchestrator
      !ENV["PARALLEL_MATRIX_FORMATTER_SERVER"] || ENV["PARALLEL_MATRIX_FORMATTER_ORCHESTRATOR"] == "true"
    end

    def start_orchestrator
      @is_orchestrator_process = true
      @orchestrator = Orchestrator.new(@config)
      
      server_path = @orchestrator.start
      if server_path
        $stdout.puts "Matrix Digital Rain formatter started (orchestrator mode)"
        $stdout.puts "Server: #{server_path}"
      else
        $stderr.puts "Failed to start orchestrator - falling back to standard output"
        @suppression_layer&.restore
      end
    end

    def start_process_formatter(total_examples)
      @process_formatter = ProcessFormatter.new(@config)
      @process_formatter.start(total_examples)
    end
  end
end