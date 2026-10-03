# frozen_string_literal: true

module ParallelMatrixFormatter
  # Runs in process 1 only. Receives the messages of every test process over
  # IPC, renders them as they arrive and prints the consolidated summary once
  # every process has reported its summary or disconnected.
  class Orchestrator
    def self.for(process_number, total_processes, output, config)
      return NullOrchestrator.new unless process_number == 1

      new(total_processes, output, Rendering::Display.new(config, total_processes))
    end

    def initialize(total_processes, output, display)
      @total_processes = total_processes
      @output = output
      @display = display
      @summaries = {}
      @disconnected = []
      @server = Ipc::Server.new
      @collector = Thread.new { collect_messages }
    end

    # Blocks until every process is done, then prints the summary.
    def close
      @collector.join
      @output.puts @display.summary(@summaries.values, missing_processes)
      @output.flush
      @server.close
    end

    private

    def collect_messages
      @server.each_message do |message|
        handle(message)
        break if all_finished?
      end
    end

    def handle(message)
      case message['type']
      when 'example' then print_example(message)
      when 'summary' then @summaries[message['process']] = message
      when 'disconnected' then @disconnected << message['process']
      end
    end

    def print_example(message)
      @output.print @display.example(message['process'], message['status'], message['progress'])
      @output.flush
    end

    def all_finished?
      missing_processes.all? { |process| @disconnected.include?(process) }
    end

    def missing_processes
      (1..@total_processes).reject { |process| @summaries.key?(process) }
    end
  end
end
