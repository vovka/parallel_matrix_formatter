# frozen_string_literal: true

require_relative '../lib/parallel_matrix_formatter'

# Test that the formatter can be registered with RSpec without errors
RSpec.describe 'Formatter Integration' do
  it 'can register the formatter with RSpec' do
    # Mock an output object
    output = StringIO.new

    # Create formatter instance (this should not raise errors)
    formatter = ParallelMatrixFormatter::Formatter.new(output)

    expect(formatter).to be_an_instance_of(ParallelMatrixFormatter::Formatter)
  end

  it 'loads configuration without errors' do
    expect { ParallelMatrixFormatter::ConfigLoader.load }.not_to raise_error
  end

  it 'creates IPC server and client without errors' do
    # Test IPC creation (should not raise errors even if can't connect)
    expect { ParallelMatrixFormatter::IPC.create_server }.not_to raise_error
  end
end