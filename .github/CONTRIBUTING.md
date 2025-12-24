# Contributing to OmniInventory

Thank you for your interest in contributing to OmniInventory!

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Create a new issue with:
   - Clear title describing the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - WoW client version (3.3.5a)
   - Any error messages from `/reload`

### Suggesting Features

1. Check existing issues/discussions
2. Create a feature request with:
   - Clear description of the feature
   - Use case / why it's valuable
   - Mockups or examples (if applicable)

### Code Contributions

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Follow MCAF workflow:
   - Write feature doc in `docs/Features/` FIRST
   - Implement with tests documented
   - Update AGENTS.md if new patterns emerge
4. Follow code style in AGENTS.md
5. Commit with conventional messages: `feat:`, `fix:`, `docs:`
6. Open a Pull Request

### Code Style

- 4-space indentation
- `local` for all variables
- CamelCase for modules, camelCase for functions
- No magic literals
- See AGENTS.md for full style guide

### Testing

WoW addons require manual in-game testing:
- Document test scenarios in feature docs
- Verify: functional, performance, edge cases
- Report results in PR

## Code of Conduct

Be respectful. We're all here to make a great addon.

## Questions?

Open an issue or reach out to @Zendevve.
