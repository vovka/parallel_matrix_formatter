# frozen_string_literal: true

require 'rspec/core/formatters/base_formatter'
require_relative 'config_loader'
require_relative 'suppression_layer'
require_relative 'orchestrator'
require_relative 'process_formatter'

module ParallelMatrixFormatter
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    # Apply early suppression when the class is loaded if we detect parallel testing
    @@early_suppression_applied = false
    
    def self.apply_early_suppression_if_needed
      return if @@early_suppression_applied
      
      # Only apply early suppression if we detect we're in a parallel testing environment
      # We need to check ENV directly here since config isn't loaded yet
      if ENV['PARALLEL_SPLIT_TEST_PROCESSES'] || ENV['PARALLEL_WORKERS'] || ENV['TEST_ENV_NUMBER']
        begin
          # Apply complete suppression early to prevent output leakage during class loading
          # Use 'runner' level for maximum suppression
          @@early_suppression_layer = SuppressionLayer.new(:runner)
          @@early_suppression_layer.suppress
          @@early_suppression_applied = true
          
          # This will be restored/overridden when the actual formatter is initialized
        rescue => e
          # If early suppression fails, don't break the test run
          # Just continue without early suppression
          # We check ENV directly here since config isn't available yet
          warn "Warning: Early suppression failed: #{e.message}" if ENV['PARALLEL_MATRIX_FORMATTER_DEBUG']
        end
      end
    end
    
    # Apply early suppression as soon as the class is loaded
    apply_early_suppression_if_needed
    
    # Class method to reset state (useful for multiple test runs)
    def self.reset_early_suppression
      if @@early_suppression_applied
        @@early_suppression_layer&.restore
        @@early_suppression_applied = false
      end
    end
    RSpec::Core::Formatters.register self,
                                     :start,
                                     :example_started,
                                     :example_passed,
                                     :example_failed,
                                     :example_pending,
                                     :stop,
                                     :close

    def initialize(output)
      super
      @config = load_config
      @process_formatter = nil
      @orchestrator = nil
      @suppression_layer = nil
      @is_orchestrator_process = false

      setup_environment
    end

    def start(start_notification)
      total_examples = start_notification.count
      
      # Debug: Log the example count (only if debugging is enabled)
      if @config['environment']['debug']
        debug_puts "Process #{Process.pid}: Found #{total_examples} examples, orchestrator: #{@is_orchestrator_process}"
      end

      if @is_orchestrator_process
        start_orchestrator
        # Orchestrator process should also run tests to maximize parallelization
        # Always start process formatter for orchestrator to ensure it participates in testing
        if @config['environment']['debug']
          debug_puts "Process #{Process.pid}: Orchestrator starting process formatter with #{total_examples} examples"
        end
        start_process_formatter(total_examples, orchestrator: @orchestrator, orchestrator_process: true)
      else
        if @config['environment']['debug']
          debug_puts "Process #{Process.pid}: Non-orchestrator starting process formatter with #{total_examples} examples"
        end
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
        # Stop process formatter first if it exists (orchestrator process running tests)
        @process_formatter&.stop
        # Give child processes time to complete
        sleep(@config['update']['interval_seconds'] || 1)
        @orchestrator&.stop
      else
        @process_formatter&.stop
      end
    end

    def close(_close_notification)
      @suppression_layer&.restore
      
      # Also restore early suppression if it's still active
      if @@early_suppression_applied
        begin
          @@early_suppression_layer&.restore
          @@early_suppression_applied = false
        rescue => e
          warn "Warning: Failed to restore early suppression in close: #{e.message}" if @config['environment']['debug']
        end
      end
      
      # Clean up lock file if we're the orchestrator
      if @is_orchestrator_process
        lock_file = '/tmp/parallel_matrix_formatter_orchestrator.lock'
        File.delete(lock_file) if File.exist?(lock_file)
      end
    end

    private

    def load_config
      ConfigLoader.load
    rescue ConfigLoader::ConfigError => e
      warn "Configuration error: #{e.message}"
      exit 1
    end

    def setup_environment
      # Determine if we're the orchestrator first
      @is_orchestrator_process = orchestrator_process?
      
      # Debug output before suppression
      if @config['environment']['debug']
        # Use preserved stderr for debug if available, otherwise fallback to current
        if SuppressionLayer.original_stderr
          SuppressionLayer.original_stderr.puts "Process #{Process.pid}: orchestrator=#{@is_orchestrator_process}"
        else
          $stderr.puts "Process #{Process.pid}: orchestrator=#{@is_orchestrator_process}"
        end
      end
      
      # If early suppression was applied and we're the orchestrator, we need to restore it
      # so the orchestrator can output
      if @@early_suppression_applied && @is_orchestrator_process
        begin
          @@early_suppression_layer&.restore
          @@early_suppression_applied = false
        rescue => e
          warn "Warning: Failed to restore early suppression: #{e.message}" if @config['environment']['debug']
        end
      end
      
      # For role-based suppression: only suppress non-orchestrator processes at the formatter level
      # ProcessFormatter will handle its own suppression regardless of process role
      should_suppress = !@is_orchestrator_process
      
      if should_suppress
        # Apply suppression for non-orchestrator processes
        suppression_level = determine_suppression_level
        @suppression_layer = SuppressionLayer.new(suppression_level)
        
        if @config['environment']['debug']
          debug_puts "Process #{Process.pid}: Applying suppression level #{suppression_level}"
        end
        @suppression_layer.suppress
      else
        # Orchestrator processes: preserve original IO but don't suppress at formatter level
        # ProcessFormatter within orchestrator will handle its own suppression
        SuppressionLayer.preserve_original_io
      end
    end

    def determine_suppression_level
      # Check environment variables for suppression control
      case @config['environment']['suppress_level']
      when 'none', '0', 'false'
        :none
      when 'ruby_warnings', '1'
        :ruby_warnings
      when 'app_warnings', '2'
        :app_warnings
      when 'app_output', '3'
        :app_output
      when 'gem_output', '4'
        :gem_output
      when 'all', '5'
        :all
      when 'runner', '6'
        :runner
      when nil
        # Default behavior: orchestrator uses 'all', non-orchestrator uses 'runner'
        @is_orchestrator_process ? :all : :runner
      else
        # Default to runner suppression for non-orchestrator processes
        @is_orchestrator_process ? :all : :runner
      end
    end

    def orchestrator_process?
      # Check if this is the main process that should act as orchestrator
      # Use a file-based lock to ensure only one process becomes the orchestrator
      
      # If explicitly set as orchestrator, always return true
      return true if @config['environment']['force_orchestrator']
      
      # If server is already running, we're not the orchestrator
      return false if @config['environment']['server_path']
      
      # Use file-based locking to determine orchestrator
      lock_file = '/tmp/parallel_matrix_formatter_orchestrator.lock'
      
      begin
        # Try to create lock file atomically
        File.open(lock_file, File::CREAT | File::EXCL | File::WRONLY) do |f|
          f.write(Process.pid.to_s)
          f.flush
          return true  # We successfully created the lock, so we're the orchestrator
        end
      rescue Errno::EEXIST
        # Lock file already exists, check if the process is still running
        begin
          existing_pid = File.read(lock_file).to_i
          # Check if process is still running
          Process.kill(0, existing_pid)
          return false  # Process is still running, we're not the orchestrator
        rescue Errno::ESRCH, Errno::EPERM
          # Process is not running, remove stale lock and try again
          File.delete(lock_file) rescue nil
          retry
        rescue
          return false  # Can't determine, assume we're not the orchestrator
        end
      rescue
        # If we can't create the lock file, assume we're not the orchestrator
        return false
      end
    end

    def start_orchestrator
      @orchestrator = Orchestrator.new(@config)

      server_path = @orchestrator.start
      if server_path
        # Only output if not suppressed
        unless @config['environment']['no_suppress']
          if SuppressionLayer.original_stderr
            SuppressionLayer.original_stderr.puts 'Matrix Digital Rain formatter started (orchestrator mode)'
            SuppressionLayer.original_stderr.puts "Server: #{server_path}"
          else
            $stderr.puts 'Matrix Digital Rain formatter started (orchestrator mode)'
            $stderr.puts "Server: #{server_path}"
          end
        end
      else
        warn 'Failed to start orchestrator - falling back to standard output' unless @config['environment']['no_suppress']
        @suppression_layer&.restore
      end
    end

    def start_process_formatter(total_examples, orchestrator: nil, orchestrator_process: false)
      # Always start for orchestrator process to ensure it participates in testing
      # For non-orchestrator processes, only start if there are examples to process
      if orchestrator_process || total_examples > 0
        # Give orchestrator process a unique identifier
        process_id = orchestrator_process ? "#{Process.pid}-orchestrator" : nil
        @process_formatter = ProcessFormatter.new(@config, process_id, orchestrator)
        @process_formatter.start(total_examples)
      elsif @config['environment']['debug']
        debug_puts "Process #{Process.pid}: No examples found, skipping process formatter"
      end
    end

    def debug_puts(message)
      # Use original stderr for debug output, bypassing suppression
      if @config['environment']['debug']
        if SuppressionLayer.original_stderr
          SuppressionLayer.original_stderr.puts(message)
        else
          $stderr.puts(message)
        end
      end
    end
  end
end
