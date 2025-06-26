# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'

module ParallelMatrixFormatter
  module IPC
    class IPCError < StandardError; end

    # FileBasedIPC provides cross-platform IPC using file system messaging
    #
    # This implementation serves as a fallback when Unix sockets are not available
    # (e.g., on Windows) or when explicitly configured. It uses JSON files in
    # dedicated directories for message passing between processes.
    #
    # Configuration Usage:
    # - base_path: Base directory for inbox/outbox folders (provided by centralized config)
    # - All paths configured centrally to avoid scattered file system access
    #
    # Directory Structure:
    # - base_path/inbox/: Messages TO this process
    # - base_path/outbox/: Messages FROM this process  
    class FileBasedIPC
      def initialize(base_path = nil)
        @base_path = base_path || File.join(Dir.tmpdir, "parallel_matrix_formatter_#{Process.pid}")
        @inbox_path = File.join(@base_path, 'inbox')
        @outbox_path = File.join(@base_path, 'outbox')
        @running = false
        @message_files = []
      end

      def start
        FileUtils.mkdir_p(@inbox_path)
        FileUtils.mkdir_p(@outbox_path)
        @running = true
        @base_path
      end

      def stop
        @running = false
        FileUtils.rm_rf(@base_path)
      end

      def send_message(message)
        filename = "#{Time.now.to_f}_#{Process.pid}_#{rand(1000)}.json"
        filepath = File.join(@inbox_path, filename)

        File.write(filepath, JSON.generate(message))
        true
      rescue StandardError => e
        raise IPCError, "Failed to write message file: #{e.message}"
      end

      def each_message(&block)
        return enum_for(:each_message) unless block_given?

        while @running
          process_inbox_messages(&block)
          sleep 0.1 # Polling interval
        end
      end

      private

      def process_inbox_messages
        return unless File.exist?(@inbox_path)

        Dir.glob(File.join(@inbox_path, '*.json')).sort.each do |file|
          next unless File.exist?(file)

          begin
            content = File.read(file)
            message = JSON.parse(content)
            File.unlink(file)
            yield message
          rescue JSON::ParserError => e
            File.unlink(file) # Remove corrupted file
            yield({ type: 'error', error: "JSON parse error: #{e.message}" })
          rescue StandardError
            # Retry on next iteration
            break
          end
        end
      end
    end
  end
end