# frozen_string_literal: true

module ParallelMatrixFormatter
  # Runs in process 1 only. Receives the messages of every test process over
  # IPC, renders them as they arrive and prints the consolidated summary once
  # every process has reported its summary or disconnected.
  #
  # The runner's process count is only a lower bound: parallel_tests drops
  # empty groups and numbers processes by group under --only-group. So the
  # processes to wait for are the ones that actually connected, plus, without
  # a pid file, the ones the count promises. With a pid file the orchestrator
  # also waits for every live test process it has not heard from yet. A process
  # counts as heard from when its pid, or its parent's (a wrapper such as spring
  # that parallel_tests started instead of rspec), arrived in a message.
  # Without a pid file, a process that has not connected within the connect
  # timeout counts as gone: it died before loading the formatter, or gave up.
  # Either way it only finishes once the server has read every connection.
  class Orchestrator
    POLL_INTERVAL = 1

    def self.for(process_number, runner, output, config)
      return NullOrchestrator.new unless process_number == 1

      new(runner, output, Rendering::Display.new(config, runner.process_count), config['connect_timeout_seconds'])
    end

    def initialize(runner, output, display, connect_timeout = Ipc::Client::CONNECT_TIMEOUT)
      @runner = runner
      @output = output
      @display = display
      @summaries = {}
      @disconnected = []
      @processes = []
      @known_pids = []
      @connect_deadline = Time.now + connect_timeout
      @server = Ipc::Server.new(Ipc.socket_path(runner.run_id))
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
      @server.each_message(poll_interval: POLL_INTERVAL) do |message|
        handle(message) if message
        break if all_finished?
      end
    end

    def handle(message)
      remember(message)
      case message['type']
      when 'example' then print_example(message)
      when 'summary' then @summaries[message['process']] = message
      when 'disconnected' then @disconnected << message['process']
      end
    end

    def remember(message)
      @processes |= [message['process']]
      @known_pids |= message.values_at('pid', 'ppid').compact
    end

    def print_example(message)
      @output.print @display.example(message['process'], message['status'], message['progress'])
      @output.flush
    end

    def all_finished?
      missing_processes.all? { |process| gone?(process) } && no_unknown_live_process? && @server.idle?
    end

    def gone?(process)
      @disconnected.include?(process) || (!@processes.include?(process) && Time.now > @connect_deadline)
    end

    def missing_processes
      awaited_processes.reject { |process| @summaries.key?(process) }
    end

    def awaited_processes
      @runner.pid_file ? @processes : @processes | (1..@runner.process_count).to_a
    end

    def no_unknown_live_process?
      return true unless @runner.pid_file

      live = @runner.live_pids
      !live.nil? && (live - @known_pids).empty?
    end
  end
end
