# ParallelMatrixFormatter

A Ruby gem that provides a Matrix Digital Rain RSpec formatter for use with `parallel_split_tests`. This formatter displays real-time, orchestrated "Matrix digital rain" progress per process in the terminal using configurable visual output inspired by the Matrix movie.

## Features

- **Matrix Digital Rain Display**: Real-time progress visualization with falling katakana characters
- **Orchestrated Parallel Output**: Single orchestrator coordinates display from multiple test processes
- **Fully Configurable**: All symbols, colors, and update strategies loaded from YAML
- **IPC Communication**: Robust Unix socket communication with file-based fallback for CI
- **Output Suppression**: Strict suppression of non-formatter output
- **GitHub Actions Compatible**: Designed to work in CI environments

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parallel_matrix_formatter'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install parallel_matrix_formatter

## Configuration

Create a `parallel_matrix_formatter.yml` configuration file in your project root or `config/` directory:

```yaml
# Digits configuration for time display
digits:
  use_custom: true
  symbols: "０１２３４５６７８９"  # Full-width Japanese digits

# Katakana alphabet for digital rain effect
katakana_alphabet: "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポァィゥェォャュョッ"

# Symbols for test results
pass_symbols: "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
fail_symbols: "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ"
pending_symbol: "🥄"

# Color configuration
colors:
  time: "green"
  percent: "red"
  rain: "green"
  pass_dot: "green"
  fail_dot: "red"
  pending_dot: "white"

# Update strategies
update:
  interval_seconds: 1
  percent_thresholds: [5]  # Update when any process percentage increases by 5%

# Display configuration
display:
  column_width: 15
  show_time_digits: true
  rain_density: 0.7  # Probability of showing rain character vs space
```

## Usage

Use with RSpec and parallel_split_tests:

```bash
# Set the formatter
bundle exec rspec --format ParallelMatrixFormatter::Formatter

# Or configure in .rspec
--format ParallelMatrixFormatter::Formatter
```

### Environment Variables

- `PARALLEL_MATRIX_FORMATTER_CONFIG`: Path to custom config file
- `PARALLEL_MATRIX_FORMATTER_SUPPRESS`: Control output suppression level (none, ruby_warnings, app_warnings, app_output, gem_output, all)
- `PARALLEL_MATRIX_FORMATTER_NO_SUPPRESS`: Disable output suppression entirely
- `NO_COLOR`: Disable color output
- `FORCE_COLOR`: Force color output even if not detected

## Output Format

The formatter displays a single line per update:

```
ｲﾛ:ｸﾗ:ﾛﾒ ｳｰﾔﾖﾌ34%ｴﾍｿｱﾆ｢ﾙﾂﾅｸ39%ﾅﾔﾎｷｿ ﾜ｣ﾜﾘﾌｯﾍｬﾗ､ﾃｽｷﾁｴﾛﾅｶｩﾌｰﾕｾﾒｵｧ🥄ｯﾓｴﾈ｢ﾅﾘｬｱｩｺｹｶｯｽｬﾘﾗｴﾂｹﾃｷｧﾇｩｯｪﾅｾｨﾎﾕﾕﾌｪｺﾐｱﾖｳﾐｾｭｫﾐｳﾓﾆｷｩﾜｪﾈﾈﾅ
```

- **Time** (left): Current time with configurable digits (green)
- **Process columns**: Digital rain with overlaid progress percentage (rain: green, percent: red)
- **Test dots** (right): Individual test results (green: pass, red: fail, 🥄: pending)

## Architecture

### Components

- **Formatter**: Main RSpec formatter entry point
- **Orchestrator**: Coordinates output from multiple processes
- **ProcessFormatter**: Runs in each RSpec process
- **ConfigLoader**: Loads and validates YAML configuration
- **DigitalRainRenderer**: Handles Matrix-style output rendering
- **IPC**: Inter-process communication via Unix sockets
- **SuppressionLayer**: Controls output suppression
- **UpdateStrategies**: Pluggable update timing strategies

### Communication Flow

1. Orchestrator starts and creates IPC server
2. Each RSpec process connects via IPC client
3. Processes send progress updates to orchestrator
4. Orchestrator renders and displays unified output
5. Final summary aggregates results from all processes

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).
