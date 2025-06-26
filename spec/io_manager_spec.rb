# frozen_string_literal: true

require 'spec_helper'
require 'parallel_matrix_formatter/io_manager'

RSpec.describe ParallelMatrixFormatter::IOManager do
  let(:original_stdout) { $stdout }
  let(:original_stderr) { $stderr }
  let(:original_verbose) { $VERBOSE }

  before do
    # Reset class-level state
    described_class.reset
  end

  after do
    # Restore original IO
    $stdout = original_stdout
    $stderr = original_stderr
    $VERBOSE = original_verbose
  end

  describe '.preserve_original_io' do
    it 'preserves original IO streams' do
      described_class.preserve_original_io
      
      expect(described_class.original_stdout).to eq(original_stdout)
      expect(described_class.original_stderr).to eq(original_stderr)
      expect(described_class.original_verbose).to eq(original_verbose)
      expect(described_class.io_preserved?).to be true
    end

    it 'does not preserve again if already preserved' do
      described_class.preserve_original_io
      first_stdout = described_class.original_stdout
      
      # Change current stdout
      $stdout = StringIO.new
      
      # Try to preserve again
      described_class.preserve_original_io
      
      # Should still be the original one, not the StringIO
      expect(described_class.original_stdout).to eq(first_stdout)
      expect(described_class.original_stdout).not_to be_a(StringIO)
    end
  end

  describe '.reset' do
    it 'resets preservation state' do
      described_class.preserve_original_io
      expect(described_class.io_preserved?).to be true
      
      described_class.reset
      expect(described_class.io_preserved?).to be false
      
      # After reset, these should return nil until preserve is called again
      # Note: We can't test the values directly because accessing them triggers preservation
    end
  end

  describe 'lazy preservation' do
    it 'preserves IO when first accessed' do
      expect(described_class.io_preserved?).to be false
      
      stdout = described_class.original_stdout
      
      expect(described_class.io_preserved?).to be true
      expect(stdout).to eq(original_stdout)
    end
  end
end

RSpec.describe ParallelMatrixFormatter::NullIO do
  let(:null_io) { described_class.new }

  describe 'output methods' do
    it 'accepts all output methods without error' do
      expect { null_io.write('test') }.not_to raise_error
      expect { null_io.puts('test') }.not_to raise_error
      expect { null_io.print('test') }.not_to raise_error
      expect { null_io.printf('%s', 'test') }.not_to raise_error
      expect { null_io.flush }.not_to raise_error
      expect { null_io.sync = true }.not_to raise_error
      expect { null_io.close }.not_to raise_error
    end
  end

  describe 'status methods' do
    it 'returns appropriate status values' do
      expect(null_io.closed?).to be false
      expect(null_io.tty?).to be false
    end
  end
end