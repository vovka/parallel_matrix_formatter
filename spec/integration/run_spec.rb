require "spec_helper"
require "parallel_matrix_formatter"
require "parallel_matrix_formatter/ipc/server"

RSpec.describe ParallelMatrixFormatter::Formatter do
  before(:all) do
    @server_thread = Thread.new do
      ParallelMatrixFormatter::Ipc::Server.new.start
    end
    # Give the server a moment to start up
    sleep(0.1)
  end

  after(:all) do
    # Terminate the server thread
    @server_thread.kill if @server_thread && @server_thread.alive?
  end
  let(:output) { File.open(File.expand_path("./parallel_matrix_formatter_output.txt", __dir__), "w+") }
  let(:total_examples) do
    total_processes.times.map { rand(5..10) }
  end
  let(:total_processes) { 3 }

  it do
    total_processes.times.map do |process_number|
      Thread.new do
        formatter = described_class.new(output, (process_number + 1).to_s)
        formatter.start(
          instance_double(
            "RSpec::Core::Notifications::StartNotification",
            count: total_examples[process_number]
          )
        )
        total_examples[process_number].times do |i|
          formatter.example_started(
            instance_double("RSpec::Core::Notifications::ExampleNotification")
          )
          # Simulate some gabberish output
          rand(100).times do
            print (33 + rand(94)).chr
          end
          case rand(3)
          when 0
            formatter.example_passed(
              instance_double("RSpec::Core::Notifications::ExampleNotification")
            )
          when 1
            formatter.example_failed(
              instance_double("RSpec::Core::Notifications::ExampleNotification")
            )
          when 2
            formatter.example_pending(
              instance_double("RSpec::Core::Notifications::ExampleNotification")
            )
          end
          sleep(1)
        end
        formatter.dump_profile(
          instance_double("RSpec::Core::Notifications::ProfileNotification")
        )
        formatter.dump_pending(
          instance_double("RSpec::Core::Notifications::PendingNotification")
        )
        formatter.dump_failures(
          instance_double("RSpec::Core::Notifications::FailuresNotification")
        )
        formatter.dump_summary(
          instance_double("RSpec::Core::Notifications::SummaryNotification")
        )
        formatter.close(
          instance_double("RSpec::Core::Notifications::CloseNotification")
        )
      end
    end.each(&:join)
  end
end
