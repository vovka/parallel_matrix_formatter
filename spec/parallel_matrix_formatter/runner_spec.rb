# frozen_string_literal: true

require 'tempfile'

RSpec.describe ParallelMatrixFormatter::Runner do
  let(:environment) { {} }

  before do
    stub_const('ENV', environment)
    hide_const('ParallelSplitTest')
  end

  describe '.detect' do
    subject(:runner) { described_class.detect }

    context 'without a parallel runner' do
      it 'runs one process' do
        expect(runner.process_count).to eq(1)
      end

      it 'identifies the run by its own pid, which no concurrent run shares' do
        expect(runner.run_id).to eq(Process.pid)
      end

      it 'has no pid file' do
        expect(runner.pid_file).to be_nil
      end
    end

    context 'with parallel_split_test' do
      before { stub_const('ParallelSplitTest', Module.new.tap { |mod| mod.define_singleton_method(:processes) { 3 } }) }

      it 'takes the process count from the runner' do
        expect(runner.process_count).to eq(3)
      end

      it 'identifies the run by the pid of the parent process' do
        expect(runner.run_id).to eq(Process.ppid)
      end

      it 'has no pid file' do
        expect(runner.pid_file).to be_nil
      end
    end

    context 'with parallel_tests' do
      let(:environment) { { 'PARALLEL_TEST_GROUPS' => '4', 'PARALLEL_PID_FILE' => '/tmp/parallel_tests-pidfile1-2-x' } }

      it 'takes the process count from the number of groups' do
        expect(runner.process_count).to eq(4)
      end

      it 'identifies the run by the name of the pid file' do
        expect(runner.run_id).to eq('parallel_tests-pidfile1-2-x')
      end

      it 'knows the pid file' do
        expect(runner.pid_file).to eq('/tmp/parallel_tests-pidfile1-2-x')
      end

      context 'without a pid file' do
        let(:environment) { { 'PARALLEL_TEST_GROUPS' => '2' } }

        it 'falls back to the pid of the parent process' do
          expect(runner.run_id).to eq(Process.ppid)
        end
      end

      context 'when the number of groups is not a number' do
        let(:environment) { { 'PARALLEL_TEST_GROUPS' => '' } }

        it 'runs one process' do
          expect(runner.process_count).to eq(1)
        end
      end
    end
  end

  describe '#live_pids' do
    subject(:live_pids) { described_class.new(process_count: 2, run_id: 1, pid_file: pid_file&.path).live_pids }

    let(:pid_file) { Tempfile.new('pidfile') }
    let(:contents) { '[11,22]' }

    before { pid_file&.write(contents) && pid_file.flush }

    after { pid_file&.close! }

    it 'lists the pids in the pid file' do
      expect(live_pids).to eq([11, 22])
    end

    context 'when the pid file is empty' do
      let(:contents) { '' }

      it { is_expected.to be_nil }
    end

    context 'when the pid file is half written' do
      let(:contents) { '[11,' }

      it { is_expected.to be_nil }
    end

    context 'when the pid file does not hold a list' do
      let(:contents) { '{}' }

      it { is_expected.to be_nil }
    end

    context 'when the pid file is gone' do
      before { File.delete(pid_file.path) }

      it { is_expected.to be_nil }
    end

    context 'without a pid file' do
      let(:pid_file) { nil }

      it { is_expected.to be_nil }
    end
  end
end
