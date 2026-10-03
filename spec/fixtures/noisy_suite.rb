# frozen_string_literal: true

# A tiny suite run by the integration spec in separate processes. It prints
# noise through every channel the formatter is expected to silence.
RSpec.describe 'noisy suite' do
  it 'passes loudly' do
    puts 'NOISE on stdout'
    STDOUT.puts 'NOISE on STDOUT'
    warn 'NOISE on stderr'
    expect(1).to eq(1)
  end

  it 'passes quietly' do
    expect(true).to be(true)
  end

  it 'fails' do
    expect(1 + 1).to eq(3)
  end

  it 'is pending' do
    pending 'not implemented'
    raise 'not yet'
  end
end
