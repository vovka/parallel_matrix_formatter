# frozen_string_literal: true

require 'shellwords'
require 'tempfile'
require 'timeout'

# Runs the formatter under the real parallel_rspec of parallel_tests, asking
# for three processes although there are only two spec files. parallel_tests
# drops the empty group but still reports three, so the formatter must not wait
# for a third process.
RSpec.describe 'a parallel_tests run' do
  fixtures = File.expand_path('../fixtures', __dir__)
  files = %w[noisy_suite.rb second_suite.rb].map { |name| File.join(fixtures, name) }
  totals = '6 examples, 1 failure, 1 pending'

  before(:all) do
    @output = Tempfile.new('parallel_matrix_formatter')
    rspec = [Gem.ruby, '-Ilib', Gem.bin_path('rspec-core', 'rspec')].shelljoin
    command = [Gem.ruby, Gem.bin_path('parallel_tests', 'parallel_rspec'), '-n', '3',
               '-o', '--format ParallelMatrixFormatter::Formatter', *files]
    pid = Process.spawn({ 'PARALLEL_TESTS_EXECUTABLE' => rspec }, *command, out: @output.path, err: @output.path)
    Timeout.timeout(60) { @status = Process.wait2(pid).last }
  end

  after(:all) { @output.close! }

  let(:output) { File.read(@output.path, encoding: 'UTF-8') }

  it 'exits with a failure status' do
    expect(@status.exitstatus).to eq(1)
  end

  it 'prints the failure in the style of RSpec' do
    expect(output).to include('1) noisy suite fails', 'expected: 3', 'got: 2')
  end

  it 'prints the totals of both processes once, and parallel_tests agrees' do
    expect(output.scan(totals).size).to eq(2)
  end

  it 'prints a status symbol for every example' do
    expect(output).to match(/^\d\d:\d\d:\d\d .+/)
  end

  it 'silences the application output of every process' do
    expect(output).not_to include('NOISE')
  end

  it 'does not warn about a missing process' do
    expect(output).not_to include('WARNING')
  end
end
