# frozen_string_literal: true

require_relative 'ipc'
require_relative 'digital_rain_renderer'
require_relative 'update_strategies'
require_relative 'suppression_layer'
require_relative 'message_handler'
require_relative 'display_manager'
require_relative 'process_manager'
require_relative 'output_manager'
require_relative 'ipc_server_manager'
require_relative 'workflow_coordinator'

module ParallelMatrixFormatter
  # Orchestrator manages central display and coordinates communication between
  # multiple test processes during parallel execution.
  #
  # Key responsibilities:
  # - Start/stop IPC server for inter-process communication
  # - Process messages and update display in real-time
  # - Track test results and failure counts across processes
  # - Render final summary when all processes complete
  #
  class Orchestrator
    def initialize(config)
      @config = config
      @renderer = DigitalRainRenderer.new(config)
      @update_strategy = UpdateStrategies.create_strategy(config)
      @running = false
      @start_time = nil
      
      # Initialize data structures
      @processes = {}
      @all_failures = []
      @process_thresholds = {}
      
      # Initialize extracted components
      message_handler = MessageHandler.new(config, @processes, @all_failures, @process_thresholds)
      display_manager = DisplayManager.new(config, @renderer, @processes, @process_thresholds)
      @process_manager = ProcessManager.new(config, @processes, @all_failures, nil) # start_time set later
      output_manager = OutputManager.new
      @ipc_server_manager = IpcServerManager.new(config)
      @workflow_coordinator = WorkflowCoordinator.new(message_handler, display_manager, @process_manager, output_manager)
    end

    # Start the orchestrator IPC server and begin processing messages
    # @return [String, nil] Server path if successful, nil if failed
    def start
      @start_time = Time.now
      @running = true
      
      # Update process manager with start time
      @process_manager = ProcessManager.new(@config, @processes, @all_failures, @start_time)

      # Start IPC server
      server_path = @ipc_server_manager.start
      return nil unless server_path

      # Start processing messages
      @ipc_server_manager.process_messages { |message| handle_message(message) }

      server_path
    end

    # Stop the orchestrator and clean up IPC resources
    def stop
      @running = false
      @ipc_server_manager.stop
      
      @workflow_coordinator.finalize_current_line
      @workflow_coordinator.print_final_summary(@renderer)
    end

    def handle_direct_message(message)
      # Public method to handle messages from same-process formatters
      all_complete = @workflow_coordinator.process_message(message)
      @running = false if all_complete
    end

    private

    def handle_message(message)
      all_complete = @workflow_coordinator.process_message(message)
      @running = false if all_complete
    end
  end
end
