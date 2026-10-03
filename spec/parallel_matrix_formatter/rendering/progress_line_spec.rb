# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::ProgressLine do
  subject(:line) { described_class.new(config, digits) }

  before do
    stub_const('ENV', ENV.to_h.merge('NO_COLOR' => '1'))
    allow(Time).to receive(:now).and_return(Time.new(2026, 1, 2, 17, 4, 13))
  end

  let(:config) do
    { 'format' => "\n{time} {columns} ",
      'column' => { 'width' => 5, 'align' => 'left', 'pad_symbols' => '.' } }
  end
  let(:digits) { '' }

  describe '#render' do
    it 'fills in the time and the columns' do
      expect(line.render(1 => 0.5)).to eq("\n17:04:13 50%.. ")
    end

    it 'renders the columns in process order' do
      expect(line.render(2 => 1.0, 1 => 0.25)).to eq("\n17:04:13 25%..100%. ")
    end

    context 'when digits are replaced' do
      let(:digits) { 'abcdefghij' }

      it 'replaces them in the time' do
        expect(line.render(1 => 0.5)).to start_with("\nbh:ae:bd ")
      end
    end
  end
end
