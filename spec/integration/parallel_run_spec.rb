# frozen_string_literal: true

require 'tempfile'
require 'timeout'

# Runs the formatter for real: two RSpec processes, each with its own
# formatter, reporting to the orchestrator in process 1 over the socket.
RSpec.describe 'a parallel run' do
  fixtures = File.expand_path('../fixtures', __dir__)
  suite = File.join(fixtures, 'noisy_suite.rb')
  fake_parallel_split_test = File.join(fixtures, 'fake_parallel_split_test.rb')

  def run_process(test_env_number, suite, fake_parallel_split_test, *options)
    output = Tempfile.new('parallel_matrix_formatter')
    command = [Gem.ruby, '-Ilib', Gem.bin_path('rspec-core', 'rspec'), '--require', fake_parallel_split_test,
               '--format', 'ParallelMatrixFormatter::Formatter', *options, suite]
    pid = Process.spawn({ 'TEST_ENV_NUMBER' => test_env_number }, *command, out: output.path, err: output.path)
    [pid, output]
  end

  before(:all) do
    pid1, @output = run_process('', suite, fake_parallel_split_test)
    pid2, @other_output = run_process('2', suite, fake_parallel_split_test)
    Timeout.timeout(60) { @statuses = [pid1, pid2].map { |pid| Process.wait2(pid).last } }
  end

  after(:all) do
    [@output, @other_output].each(&:close!)
  end

  let(:output) { File.read(@output.path, encoding: 'UTF-8') }

  it 'exits with a failure status in both processes' do
    expect(@statuses.map(&:exitstatus)).to eq([1, 1])
  end

  it 'prints the totals of both processes' do
    expect(output).to include('8 examples, 2 failures, 2 pending')
  end

  it 'prints every failure in the style of RSpec' do
    expect(output).to include('1) noisy suite fails', '2) noisy suite fails', 'expected: 3', 'got: 2')
  end

  it 'prints the commands to rerun the failures' do
    expect(output.scan(%r{rspec ./spec/fixtures/noisy_suite.rb:\d+}).size).to eq(2)
  end

  it 'prints a status symbol for every example' do
    expect(output.lines[1]).to match(/\A\d\d:\d\d:\d\d .+/)
  end

  it 'silences the application output of every process' do
    expect(output + File.read(@other_output.path, encoding: 'UTF-8')).not_to include('NOISE')
  end

  it 'prints nothing from the other process' do
    expect(File.read(@other_output.path)).to eq('')
  end

  context 'when aborted by --fail-fast' do
    before(:all) do
      pid1, @output = run_process('', suite, fake_parallel_split_test, '--fail-fast')
      pid2, @other_output = run_process('2', suite, fake_parallel_split_test, '--fail-fast')
      Timeout.timeout(60) { [pid1, pid2].each { |pid| Process.wait(pid) } }
    end

    it 'still prints the summary up to the first failure of each process' do
      expect(output).to include('1) noisy suite fails', '2) noisy suite fails').and match(/[2-7] examples, 2 failures/)
    end
  end
end
