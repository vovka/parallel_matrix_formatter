# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::Digits do
  describe '.replace' do
    let(:symbols) { 'abcdefghij' }

    it 'replaces every digit with the symbol at its index' do
      expect(described_class.replace('17:04:13', symbols)).to eq('bh:ae:bd')
    end

    it 'leaves other characters alone' do
      expect(described_class.replace('89%', symbols)).to eq('ij%')
    end

    it 'keeps a digit that has no symbol' do
      expect(described_class.replace('09', 'xy')).to eq('x9')
    end

    it 'returns the text unchanged when symbols is empty' do
      expect(described_class.replace('12', '')).to eq('12')
    end

    it 'returns the text unchanged when symbols is nil' do
      expect(described_class.replace('12', nil)).to eq('12')
    end
  end
end
