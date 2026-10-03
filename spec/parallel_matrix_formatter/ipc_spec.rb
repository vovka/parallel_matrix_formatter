# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Ipc do
  describe '.socket_path' do
    it 'is in the temporary directory' do
      expect(described_class.socket_path(42)).to start_with(Dir.tmpdir)
    end

    it 'identifies the run' do
      expect(described_class.socket_path('parallel_tests-pidfile20240101-7-abc'))
        .to end_with('parallel_matrix_formatter-parallel_tests-pidfile20240101-7-abc.sock')
    end
  end
end
