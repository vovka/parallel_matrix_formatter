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

  describe '.silenced?' do
    it 'is false until the process is silenced' do
      expect(described_class.silenced?).to be(false)
    end

    it 'is true once the process is silenced' do
      output = capture_from_child { described_class.silence.write(described_class.silenced?) }
      expect(output).to eq('true')
    end
  end
end
