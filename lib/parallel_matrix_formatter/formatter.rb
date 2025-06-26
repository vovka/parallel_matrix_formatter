# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'
require_relative 'config_loader'
require_relative 'suppression_layer'
require_relative 'orchestrator'
require_relative 'process_formatter'
require_relative 'early_suppression_manager'
require_relative 'process_role_detector'
require_relative 'formatter_suppression_manager'
require_relative 'orchestrator_starter'

module ParallelMatrixFormatter
  # Formatter is the main RSpec formatter class that coordinates the matrix digital rain display
  # during parallel test execution. It acts as either an orchestrator or worker process.
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    # Apply early suppression as soon as the class is loaded
    EarlySuppressionManager.apply_early_suppression_if_needed
    
    # Reset early suppression state (useful for testing)
    # @return [void]
    def self.reset_early_suppression
      EarlySuppressionManager.reset_early_suppression
    end

    RSpec::Core::Formatters.register self, :start, :example_started, :example_passed,
                                     :example_failed, :example_pending, :stop, :close

    def initialize(output)
      super
      @config = load_config
      @process_formatter = nil
      @orchestrator = nil
      @is_orchestrator_process = false
      @suppression_manager = FormatterSuppressionManager.new(@config)
      @orchestrator_starter = OrchestratorStarter.new(@config)
      setup_environment
    end

    def start(start_notification)
      total_examples = start_notification.count

      if @is_orchestrator_process
        @orchestrator = @orchestrator_starter.start_orchestrator
        @suppression_manager.restore_suppression unless @orchestrator
        start_process_formatter(total_examples, orchestrator: @orchestrator, orchestrator_process: true)
      else
        start_process_formatter(total_examples)
      end
    end

    def example_started(notification); @process_formatter&.example_started(notification); end
    def example_passed(notification); @process_formatter&.example_passed(notification); end
    def example_failed(notification); @process_formatter&.example_failed(notification); end
    def example_pending(notification); @process_formatter&.example_pending(notification); end

    def stop(_stop_notification)
      if @is_orchestrator_process
        @process_formatter&.stop
        sleep(@config['update']['interval_seconds'] || 1)
        @orchestrator&.stop
      else
        @process_formatter&.stop
      end
    end

    def close(_close_notification)
      @suppression_manager.restore_suppression
      EarlySuppressionManager.restore_early_suppression_if_needed
      ProcessRoleDetector.cleanup_lock_file(@config) if @is_orchestrator_process
    end

    private

    def load_config
      ConfigLoader.load
    rescue ConfigLoader::ConfigError => e
      warn "Configuration error: #{e.message}"
      exit 1
    end

    def setup_environment
      @is_orchestrator_process = ProcessRoleDetector.orchestrator_process?(@config)
      @suppression_manager.setup_suppression(@is_orchestrator_process)
    end

    def start_process_formatter(total_examples, orchestrator: nil, orchestrator_process: false)
      if orchestrator_process || total_examples > 0
        process_id = orchestrator_process ? "#{Process.pid}-orchestrator" : nil
        @process_formatter = ProcessFormatter.new(@config, process_id, orchestrator)
        @process_formatter.start(total_examples)
      end
    end
  end
end