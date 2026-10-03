# frozen_string_literal: true

RSpec.describe ParallelMatrixFormatter::Rendering::ProgressUpdatePolicy do
  subject(:policy) { described_class.new(config, 2) }

  let(:config) { { 'always' => false, 'interval_seconds' => 0, 'percent_threshold' => 0 } }
  let(:now) { Time.at(1_000) }

  before { allow(Time).to receive(:now) { now } }

  describe '#update?' do
    context 'when every rule is off' do
      it 'is never due' do
        expect(policy.update?(1 => 0.5)).to be(false)
      end
    end

    context 'when always is on' do
      let(:config) { super().merge('always' => true) }

      it 'is due after every example' do
        2.times { policy.update?(1 => 0.5) }
        expect(policy.update?(1 => 0.6)).to be(true)
      end
    end

    context 'with an interval' do
      let(:config) { super().merge('interval_seconds' => 60) }

      it 'is due for the first report' do
        expect(policy.update?(1 => 0.1)).to be(true)
      end

      it 'is not due again within the interval' do
        policy.update?(1 => 0.1)
        allow(Time).to receive(:now).and_return(now + 59)
        expect(policy.update?(1 => 0.2)).to be(false)
      end

      it 'is due again once the interval has passed' do
        policy.update?(1 => 0.1)
        allow(Time).to receive(:now).and_return(now + 60)
        expect(policy.update?(1 => 0.2)).to be(true)
      end

      it 'is due when every process has completed' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 1.0, 2 => 1.0)).to be(true)
      end

      it 'is not due when only some processes have completed' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 1.0)).to be(false)
      end

      it 'is not due when a reported process has not completed' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 1.0, 2 => 0.9)).to be(false)
      end
    end

    context 'with a percent threshold' do
      let(:config) { super().merge('percent_threshold' => 10) }

      it 'is due for the first report of a process' do
        expect(policy.update?(1 => 0.01)).to be(true)
      end

      it 'is not due below the threshold' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 0.19)).to be(false)
      end

      it 'is due at the threshold' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 0.25)).to be(true)
      end

      it 'is due when a process reaches 100%' do
        policy.update?(1 => 0.96)
        expect(policy.update?(1 => 1.0)).to be(true)
      end

      it 'measures the threshold from the last update of that process' do
        policy.update?(1 => 0.1)
        policy.update?(1 => 0.15)
        expect(policy.update?(1 => 0.2)).to be(true)
      end
    end

    context 'with both an interval and a threshold' do
      let(:config) { super().merge('interval_seconds' => 60, 'percent_threshold' => 1) }

      it 'lets the interval win' do
        policy.update?(1 => 0.1)
        expect(policy.update?(1 => 0.9)).to be(false)
      end
    end
  end
end
