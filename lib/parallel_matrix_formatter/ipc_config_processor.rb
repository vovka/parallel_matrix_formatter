# frozen_string_literal: true

require 'tmpdir'
require 'socket'

module ParallelMatrixFormatter
  # IpcConfigProcessor handles IPC configuration processing and path generation
  # for the parallel matrix formatter. This class was extracted from ConfigLoader
  # to reduce class size and improve separation of concerns.
  #
  # This processor centralizes all IPC path generation and configuration validation
  # to eliminate scattered path generation throughout the codebase. It ensures
  # consistent path resolution and validates IPC mode settings.
  #
  # Key Responsibilities:
  # ===================
  # - Generate default IPC paths (server paths, temp directories, lock files)
  # - Validate IPC mode settings and handle platform-specific fallbacks
  # - Resolve relative paths to absolute paths for consistency
  # - Integrate environment variable server paths with config-driven defaults
  # - Provide Unix socket platform capability detection
  #
  # Configuration Processing:
  # ========================
  # 
  # Path Generation:
  # - temp_dir: Base directory for all IPC files (defaults to system temp)
  # - server_path: Socket path or base directory for IPC server
  # - orchestrator_lock_file: Lock file for orchestrator process coordination
  # - server_path_file: File for fallback server path discovery
  #
  # Mode Resolution:
  # - auto: Automatically selects unix_socket or file_based based on platform support
  # - unix_socket: Uses Unix domain sockets (falls back to file_based if unsupported)
  # - file_based: Uses file-based IPC for cross-platform compatibility
  #
  class IpcConfigProcessor
    class << self
      # Process IPC configuration by generating default paths and validating settings
      #
      # This method centralizes all IPC path generation and configuration validation
      # to eliminate scattered path generation throughout the codebase.
      #
      # @param config [Hash] Configuration to process (will be modified in place)
      # @raise [ParallelMatrixFormatter::ConfigLoader::ConfigError] If IPC mode is invalid
      def process_ipc_config(config)
        ipc_config = config['ipc']
        
        # Set default temp directory if not specified
        ipc_config['temp_dir'] ||= Dir.tmpdir
        
        # Generate default server path if not specified
        # Use environment server path if provided, otherwise generate default
        if config['environment']['server_path']
          ipc_config['server_path'] = config['environment']['server_path']
        elsif ipc_config['server_path'].nil?
          # Generate appropriate default path based on mode preference
          if ipc_config['prefer_unix_socket'] && unix_socket_supported?
            ipc_config['server_path'] = File.join(ipc_config['temp_dir'], "parallel_matrix_formatter_#{Process.pid}.sock")
          else
            ipc_config['server_path'] = File.join(ipc_config['temp_dir'], "parallel_matrix_formatter_#{Process.pid}")
          end
        end
        
        # Generate orchestrator lock file path if not specified
        ipc_config['orchestrator_lock_file'] ||= File.join(ipc_config['temp_dir'], 'parallel_matrix_formatter_orchestrator.lock')
        
        # Generate server path file for fallback discovery if not specified
        ipc_config['server_path_file'] ||= File.join(ipc_config['temp_dir'], 'parallel_matrix_formatter_server.path')
        
        # Validate and process mode setting
        case ipc_config['mode']
        when 'auto'
          # Auto mode: prefer unix_socket if supported and preferred, otherwise file_based
          ipc_config['resolved_mode'] = if ipc_config['prefer_unix_socket'] && unix_socket_supported?
                                          'unix_socket'
                                        else
                                          'file_based'
                                        end
        when 'unix_socket'
          unless unix_socket_supported?
            # Fall back to file_based if unix_socket not supported
            ipc_config['resolved_mode'] = 'file_based'
          else
            ipc_config['resolved_mode'] = 'unix_socket'
          end
        when 'file_based'
          ipc_config['resolved_mode'] = 'file_based'
        else
          raise ParallelMatrixFormatter::ConfigLoader::ConfigError, "Invalid IPC mode '#{ipc_config['mode']}'. Must be 'auto', 'unix_socket', or 'file_based'"
        end
        
        # Ensure paths are absolute for consistency
        %w[server_path temp_dir orchestrator_lock_file server_path_file].each do |path_key|
          ipc_config[path_key] = File.expand_path(ipc_config[path_key]) if ipc_config[path_key]
        end
      end

      # Check if Unix sockets are supported on this platform
      #
      # Unix sockets provide superior performance and reliability compared to file-based IPC,
      # but are not available on all platforms (notably Windows).
      #
      # @return [Boolean] True if Unix sockets are supported and available
      def unix_socket_supported?
        # Check if Unix sockets are supported (not on Windows in general)
        !Gem.win_platform? && defined?(UNIXSocket)
      end
    end
  end
end