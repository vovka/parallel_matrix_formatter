# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::NullOrchestrator do
  describe '#close' do
    it 'does nothing' do
      expect(described_class.new.close).to be_nil
    end
  end
end
