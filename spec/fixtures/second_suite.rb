# frozen_string_literal: true

# A second tiny suite, so that a run of the integration spec has two files to
# split between processes.
RSpec.describe 'second suite' do
  it 'passes' do
    expect(2 * 2).to eq(4)
  end

  it 'also passes' do
    expect([]).to be_empty
  end
end
