# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Formatter do
  subject(:formatter) { described_class.new(output) }

  let(:output) { StringIO.new }
  let(:config) { { 'suppress_output' => false, 'connect_timeout_seconds' => 7 } }
  let(:test_env_number) { '' }
  let(:runner) { ParallelMatrixFormatter::Runner.new(process_count: 1, run_id: 'run-1') }
  let(:orchestrator) { instance_double(ParallelMatrixFormatter::NullOrchestrator, close: nil) }
  let(:client) { instance_double(ParallelMatrixFormatter::Ipc::Client, notify: nil, close: nil) }
  let(:notification) { instance_double(RSpec::Core::Notifications::ExampleNotification) }
  let(:start_notification) { instance_double(RSpec::Core::Notifications::StartNotification, count: 4) }

  before do
    stub_const('ENV', ENV.to_h.merge('TEST_ENV_NUMBER' => test_env_number))
    allow(ParallelMatrixFormatter::Runner).to receive(:detect).and_return(runner)
    allow(ParallelMatrixFormatter::Config).to receive(:load).and_return(config)
    allow(ParallelMatrixFormatter::Orchestrator).to receive(:for).and_return(orchestrator)
    allow(ParallelMatrixFormatter::Ipc::Client).to receive(:connect).and_return(client)
  end

  describe '#initialize' do
    it 'hosts the orchestrator of process 1 with the output and the configuration' do
      formatter
      expect(ParallelMatrixFormatter::Orchestrator).to have_received(:for).with(1, runner, output, config)
    end

    context 'when TEST_ENV_NUMBER is 2' do
      let(:test_env_number) { '2' }

      it 'runs as process 2' do
        formatter
        expect(ParallelMatrixFormatter::Orchestrator).to have_received(:for).with(2, runner, output, config)
      end
    end

    context 'when suppress_output is true' do
      let(:config) { { 'suppress_output' => true } }
      let(:terminal) { StringIO.new }

      before { allow(ParallelMatrixFormatter::Output::Silencer).to receive(:silence).and_return(terminal) }

      it 'renders to the silenced terminal' do
        formatter
        expect(ParallelMatrixFormatter::Orchestrator).to have_received(:for).with(1, runner, terminal, config)
      end

      context 'when RSpec writes to a file' do
        let(:output) { File.new(File::NULL, 'w') }

        after { output.close }

        it 'renders to the file' do
          formatter
          expect(ParallelMatrixFormatter::Orchestrator).to have_received(:for).with(1, runner, output, config)
        end
      end
    end
  end

  describe '#start' do
    it 'connects to the orchestrator of the run' do
      formatter.start(start_notification)
      expect(ParallelMatrixFormatter::Ipc::Client)
        .to have_received(:connect).with(ParallelMatrixFormatter::Ipc.socket_path('run-1'), timeout: 7)
    end

    it 'announces the process, so that it is missed even if it dies before its first example' do
      formatter.start(start_notification)
      expect(client).to have_received(:notify).with(process: 1, pid: Process.pid, ppid: Process.ppid, type: 'hello')
    end
  end

  describe 'reporting an example' do
    before do
      formatter.start(start_notification)
      formatter.example_started(notification)
    end

    it 'notifies about a passed example with the progress' do
      formatter.example_passed(notification)
      expect(client).to have_received(:notify).with(hash_including(type: 'example', status: :passed, progress: 0.25))
    end

    it 'identifies the process by its number and pids' do
      formatter.example_passed(notification)
      expect(client).to have_received(:notify)
        .with(hash_including(type: 'example', process: 1, pid: Process.pid, ppid: Process.ppid))
    end

    it 'notifies about a pending example' do
      formatter.example_pending(notification)
      expect(client).to have_received(:notify).with(hash_including(type: 'example', status: :pending))
    end

    it 'notifies about a failed example' do
      formatter.example_failed(failed_notification)
      expect(client).to have_received(:notify).with(hash_including(type: 'example', status: :failed))
    end

    it 'counts every started example for the progress' do
      formatter.example_started(notification)
      formatter.example_passed(notification)
      expect(client).to have_received(:notify).with(hash_including(progress: 0.5))
    end

    context 'when running as process 2' do
      let(:test_env_number) { '2' }

      it 'notifies as process 2' do
        formatter.example_passed(notification)
        expect(client).to have_received(:notify).with(hash_including(type: 'example', process: 2))
      end
    end
  end

  describe '#dump_summary' do
    let(:summary) do
      instance_double(RSpec::Core::Notifications::SummaryNotification,
                      example_count: 4, failure_count: 1, pending_count: 2, duration: 1.5,
                      errors_outside_of_examples_count: 0, totals_line: '4 examples, 1 failure')
    end

    before do
      formatter.start(start_notification)
      formatter.example_failed(failed_notification)
      formatter.dump_summary(summary)
    end

    it 'sends the counts and the duration' do
      expect(client).to have_received(:notify)
        .with(hash_including(type: 'summary', process: 1, examples: 4, failures: 1, pending: 2, duration: 1.5))
    end

    it 'sends the number of errors outside of the examples' do
      expect(client).to have_received(:notify).with(hash_including(type: 'summary', errors: 0))
    end

    it 'identifies the process by its number and pids' do
      expect(client).to have_received(:notify)
        .with(hash_including(type: 'summary', process: 1, pid: Process.pid, ppid: Process.ppid))
    end

    it 'sends the details of the failed examples' do
      expect(client).to have_received(:notify).with(hash_including(failed_examples: [failure_details]))
    end
  end

  describe 'the totals line for the runner' do
    let(:summary) do
      instance_double(RSpec::Core::Notifications::SummaryNotification,
                      example_count: 4, failure_count: 1, pending_count: 2, duration: 1.5,
                      errors_outside_of_examples_count: 0, totals_line: '4 examples, 1 failure')
    end

    before { formatter.start(start_notification) }

    it 'is not written when the output is the display itself' do
      formatter.dump_summary(summary)
      expect(output.string).to eq('')
    end

    context 'when the display goes to the silenced terminal' do
      let(:config) { { 'suppress_output' => true } }

      before { allow(ParallelMatrixFormatter::Output::Silencer).to receive(:silence).and_return(StringIO.new) }

      it 'is written to the stream RSpec handed over, for parallel_split_test to record' do
        formatter.dump_summary(summary)
        expect(output.string).to eq("4 examples, 1 failure\n")
      end
    end
  end

  describe '#close' do
    it 'closes the client' do
      formatter.start(start_notification)
      formatter.close(notification)
      expect(client).to have_received(:close)
    end

    it 'closes the orchestrator' do
      formatter.close(notification)
      expect(orchestrator).to have_received(:close)
    end
  end

  def failed_notification
    example = instance_double(RSpec::Core::Example, location_rerun_argument: './spec/a_spec.rb:7')
    instance_double(RSpec::Core::Notifications::FailedExampleNotification,
                    description: 'adds up', example: example,
                    colorized_message_lines: ['Failure/Error: boom'],
                    colorized_formatted_backtrace: ['# ./spec/a_spec.rb:7'])
  end

  def failure_details
    { description: 'adds up', location: './spec/a_spec.rb:7',
      message_lines: ['Failure/Error: boom'], backtrace: ['# ./spec/a_spec.rb:7'] }
  end
end
