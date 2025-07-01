# Gemini Agent Instructions

This file contains instructions and configurations for the Gemini coding agent.

## Test Execution

To run tests in this project, use the following command:

```bash
docker compose run --rm -it dev bundle exec rspec
```

You also can run script `./bin/rspec-docker` as a wrapper with some extra actions.

## Testing Conventions

- **Single Expect per Example**: Each test example (i.e., `it` block) should ideally contain only one `expect` assertion. This promotes clarity and ensures that each test focuses on a single behavior or outcome.

## Task Management

- **Task Template**: The template for creating new tasks is located at `.gemini/TASK_TEMPLATE.md`.
- **Task File Naming Convention**: New task files should be created in the `docs/` directory following the format `{yyyy-mm-dd}_feature_name.md`.

## Linting and Formatting Commands

- **Linting**: `bundle exec rubocop` (Note: Linting is temporarily not actively enforced/used yet.)
- **Formatting**: [Specify formatting command if applicable, e.g., `bundle exec rubocop -A`]

## Project Conventions and Architecture

- **General Structure**: Make only minimal changes required for a minimum viable product.
- **Code Style**: All files should be required from `lib/parallel_matrix_formatter.rb`. Classes should be less than 100 lines. Methods should be less than 10 lines, ideally 3-5 lines. Lines should be less that 80 characters long, though up to 120 is allowed.
- **Design Patterns**: [Mention any prevalent design patterns, e.g., "Favors modular design and clear separation of concerns."]
- **Architectural Decisions**: [Highlight any key architectural choices, e.g., "IPC communication is handled via custom `IPCClient` and `IPCServer` classes."]

## Key Technologies and Frameworks

- **Languages**: Ruby
- **Frameworks/Libraries**: [List significant gems or libraries, e.g., "RSpec for testing, Thor for CLI commands (if applicable)."]

## Commonly Ignored Files/Directories

- `node_modules/`
- `vendor/bundle/`
- `tmp/`
- `log/`
- all files starting with dot usually should be ignored
- [Add any other project-specific ignored paths]

## Version Control

- The project uses Git for version control.
- IMPORTANT! Do not commit changes without explicit instruction for it.
- The `.gitignore` file is present and should be respected for ignored files and directories.

## Deployment/Build Instructions

- **Build**: [Specify build commands if applicable, e.g., `gem build parallel_matrix_formatter.gemspec`]
- **Deployment**: [Provide high-level deployment steps or commands if applicable.]
