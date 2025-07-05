# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ParallelMatrixFormatter::Rendering::UpdateRenderer::ProgressUpdatePolicy do
  subject(:policy) { described_class.new(config) }

  describe '#should_update?' do
    context 'when update_always is true' do
      let(:config) { { 'update_always' => true } }

      it 'returns true' do
        expect(policy.should_update?({})).to eq(true)
      end
    end

    context 'when update_interval_seconds is set' do
      let(:config) { { 'update_interval_seconds' => 1 } }
      let(:progress) { { 1 => 0.5 } }

      it 'returns true on first call' do
        expect(policy.should_update?(progress)).to eq(true)
      end

      it 'returns false if called again immediately' do
        policy.should_update?(progress)
        expect(policy.should_update?(progress)).to eq(false)
      end

      it 'returns true if all progress is complete' do
        policy.should_update?(progress)
        expect(policy.should_update?({ 1 => 1.0 })).to eq(true)
      end
    end

    context 'when update_percentage_threshold is set' do
      let(:config) { { 'update_percentage_threshold' => 10 } }
      let(:progress) { { 1 => 0.0 } }

      it 'returns true on first call' do
        expect(policy.should_update?(progress)).to eq(true)
      end

      it 'returns true when progress increases by threshold' do
        policy.should_update?(progress)
        expect(policy.should_update?({ 1 => 0.11 })).to eq(true)
      end

      it 'returns false when progress increases less than threshold' do
        policy.should_update?(progress)
        expect(policy.should_update?({ 1 => 0.05 })).to eq(false)
      end

      it 'returns true when progress reaches 1.0' do
        policy.should_update?(progress)
        expect(policy.should_update?({ 1 => 1.0 })).to eq(true)
      end
    end

    context 'when no config triggers are set' do
      let(:config) { {} }

      it 'returns nil' do
        expect(policy.should_update?({})).to be_nil
      end
    end
  end
end
