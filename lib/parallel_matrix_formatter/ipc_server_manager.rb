# frozen_string_literal: true

require_relative 'ipc'

module ParallelMatrixFormatter
  # IpcServerManager handles IPC server lifecycle management for the orchestrator.
  # This class was extracted from Orchestrator to reduce class size
  # and improve separation of concerns.
  #
  # Key responsibilities:
  # - Start and stop IPC server
  # - Manage server path configuration and discovery files
  # - Handle environment variable setup for fallback discovery
  # - Process incoming messages from IPC clients
  #
  class IpcServerManager
    def initialize(config)
      @config = config
      @ipc_server = nil
      @running = false
    end

    # Start the IPC server and setup discovery mechanisms
    # @return [String, nil] Server path if successful, nil if failed
    def start
      # Start IPC server using centralized configuration
      ipc_config = @config['ipc']
      @ipc_server = IPC.create_server(
        prefer_unix_socket: ipc_config['prefer_unix_socket'],
        server_path: ipc_config['server_path']
      )
      server_path = @ipc_server.start

      # Store server path for child processes to connect using configured fallback method
      # This is the only ENV assignment allowed, and only when fallback discovery is enabled
      # via config['environment']['force_orchestrator'] or config['ipc']['server_path_file']
      if @config['environment']['force_orchestrator'] || ipc_config['server_path_file']
        ENV['PARALLEL_MATRIX_FORMATTER_SERVER'] = server_path
        
        # Write to configured server path file for fallback discovery if specified
        # This provides an alternative discovery mechanism when ENV variables aren't available
        if ipc_config['server_path_file']
          File.write(ipc_config['server_path_file'], server_path)
        end
      end

      @running = true
      server_path
    rescue IPC::IPCError => e
      warn "Failed to start orchestrator: #{e.message}" unless @config['suppression']['no_suppress']
      nil
    end

    # Stop the IPC server and clean up resources
    def stop
      @running = false
      @ipc_server&.stop

      # Clean up server path file using configured path
      ipc_config = @config['ipc']
      if ipc_config['server_path_file'] && File.exist?(ipc_config['server_path_file'])
        File.delete(ipc_config['server_path_file'])
      end
    end

    # Start processing messages in a separate thread
    # @param message_handler [Proc] Block to handle each message
    def process_messages(&message_handler)
      Thread.new do
        @ipc_server.each_message(&message_handler)
      end
    end

    # Check if server is running
    # @return [Boolean] True if server is running
    def running?
      @running
    end
  end
end