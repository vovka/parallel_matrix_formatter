# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Ipc do
  describe '.socket_path' do
    it 'is in the temporary directory' do
      expect(described_class.socket_path).to start_with(Dir.tmpdir)
    end

    it 'identifies the run by the pid of the parent process' do
      expect(described_class.socket_path).to end_with("parallel_matrix_formatter-#{Process.ppid}.sock")
    end
  end
end
