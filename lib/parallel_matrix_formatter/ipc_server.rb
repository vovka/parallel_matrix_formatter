# frozen_string_literal: true
require 'socket'
require 'json'

module ParallelMatrixFormatter
  class IpcServer
    SOCKET_PATH = "/tmp/parallel_matrix_formatter.sock"

    def initialize
      @server = UNIXServer.new(SOCKET_PATH)
    end

    def start(&block)
      loop do
        client = @server.accept
        Thread.new do
          begin
            while (message = client.gets)
              message = JSON.parse(message) rescue nil
              yield(message) if block_given?
              # Optionally, respond to the client here
            end
          ensure
            client.close
          end
        end
      end
    rescue IOError => e
    end

    def close
      @server.close if @server
      File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)
    end
  end
end
