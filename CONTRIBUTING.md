# Contributing to PRVT Demo

Thank you for considering contributing to this project!

## Development Setup

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone and setup:
```bash
git clone https://github.com/yourusername/prvt-demo
cd prvt-demo
forge install
```

3. Run tests:
```bash
forge test
```

## Coding Standards

### Solidity Style Guide

Follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html):

- 4 spaces indentation (no tabs)
- Max 120 characters per line
- PascalCase for contracts/interfaces
- camelCase for functions/variables
- UPPER_SNAKE_CASE for constants
- Use explicit visibility modifiers
- Order: external > public > internal > private

### Documentation

- Write NatSpec comments for all public/external functions
- Include `@param` and `@return` descriptions
- Document security considerations with `@dev`
- Update README for significant changes

### Testing

- Write tests for all new features
- Aim for >90% coverage
- Test edge cases and error conditions
- Use descriptive test names: `test_FunctionName_Scenario`
- Organize tests by contract

### Security

- Follow CEI pattern (Checks-Effects-Interactions)
- Use reentrancy guards
- Validate all inputs
- Document security assumptions
- Report vulnerabilities privately

## Pull Request Process

1. Create feature branch from `develop`
2. Make your changes
3. Run tests: `forge test`
4. Update documentation
5. Commit with clear messages
6. Push and create PR
7. Address review feedback

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] All tests pass
- [ ] New tests added
- [ ] Coverage maintained/improved

## Checklist
- [ ] Code follows style guide
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
```

## Reporting Bugs

Use GitHub Issues with:
- Clear title
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Code snippets if applicable

## Questions?

Feel free to open a discussion or issue!

