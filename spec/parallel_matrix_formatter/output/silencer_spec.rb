# frozen_string_literal: true

require_relative '../../support/child_process'

# The silencer reopens the real stdout and stderr, so every example that
# silences runs in a forked child whose output goes to a pipe.
RSpec.describe ParallelMatrixFormatter::Output::Silencer do
  include ChildProcess

  describe '.silence' do
    it 'discards what is written to STDOUT' do
      output = capture_from_child { described_class.silence && STDOUT.write('lost') }
      expect(output).to eq('')
    end

    it 'discards what is written to STDERR' do
      output = capture_from_child { described_class.silence && STDERR.write('lost') }
      expect(output).to eq('')
    end

    it 'writes what is written to STDERR to a log of the process' do
      output = capture_from_child do
        ENV['TEST_ENV_NUMBER'] = Process.pid.to_s
        terminal = described_class.silence
        STDERR.write('kept')
        terminal.write(File.read(described_class.stderr_logs.find { |log| log.include?("-#{Process.pid}.") }))
      end
      expect(output).to eq('kept')
    end

    it 'returns the original stdout' do
      output = capture_from_child { described_class.silence.write('kept') }
      expect(output).to eq('kept')
    end

    it 'returns the same terminal when called again' do
      terminal = nil
      output = capture_from_child do
        terminal = described_class.silence
        terminal.write(described_class.silence.equal?(terminal))
      end
      expect(output).to eq('true')
    end

    it 'silences what a child process writes' do
      output = capture_from_child { described_class.silence && system('echo lost') }
      expect(output).to eq('')
    end
  end

  describe '.stderr_logs' do
    it 'is empty until the process is silenced' do
      output = capture_from_child { STDOUT.write(described_class.stderr_logs.inspect) }
      expect(output).to eq('[]')
    end

    it 'names the log after the process number' do
      output = capture_from_child do
        ENV['TEST_ENV_NUMBER'] = '3'
        described_class.silence.write(described_class.stderr_logs.map { |log| File.basename(log) }.inspect)
      end
      expect(output).to match(/-3\.stderr\.log/)
    end
  end

  describe '.silenced?' do
    it 'is false until the process is silenced' do
      output = capture_from_child { STDOUT.write(described_class.silenced?) }
      expect(output).to eq('false')
    end

    it 'is true once the process is silenced' do
      output = capture_from_child { described_class.silence.write(described_class.silenced?) }
      expect(output).to eq('true')
    end
  end
end
