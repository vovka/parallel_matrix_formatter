# Copilot Coding Agent Instructions

These instructions apply globally to all code and tests in this repository.  
They are intended for the Copilot coding agent to ensure code quality, maintainability, and architectural consistency.

## General Coding Style

- Follow established Ruby community code style conventions (e.g., Rubocop defaults, idiomatic Ruby).
- Use descriptive and meaningful names for classes, methods, variables, and files.
- Avoid code duplication and favor DRY principles.

## Class and File Structure

- Each class must be placed in its own file.
- No class should exceed 100 lines (including comments and blank lines).
- Organize files and folders logically according to Ruby community standards.

## Method Constraints

- No method should exceed 10 lines (including comments and blank lines).
- Prefer small, focused methods; extract logic rather than nesting or chaining.
- Avoid long parameter lists; use keyword arguments or objects as needed.

## Test Style & Structure

- Follow community RSpec style and best practices.
- Use descriptive test names and clear, focused examples.
- Organize specs to mirror the code structure (one spec file per class/file).
- Keep individual test examples short and focused.
- Use let/subject/context/describe appropriately for clarity and reusability.
- Use one expectation per test. 

## Architecture Constraints

- Enforce the above class, file, and method length limits throughout the codebase.
- Do not introduce God objects or large service classes.
- Prefer composition over inheritance.
- Separate business logic, presentation, and infrastructure layers where appropriate.
- Always provide simplest minimal solution.
- If you have architectural choices and they all sucessfully solve issue, always choose the simplest one with less code and less new abstractions. 

---

**These requirements are mandatory for all Copilot-generated code and pull requests.**

If a requested change would violate these constraints, please propose a compliant alternative and explain the reasoning.
