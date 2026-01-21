# Contributing to GitHub Actions Runners

Thank you for your interest in contributing to the GitHub Actions Runners project! We welcome contributions from the community to help improve and expand this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Guidelines](#coding-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Guidelines](#documentation-guidelines)
- [Security](#security)
- [Communication](#communication)
- [License](#license)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [project maintainers].

## How to Contribute

There are many ways to contribute to this project:

### 1. Reporting Bugs
If you find a bug, please open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected behavior vs actual behavior
- Environment details (OS, Docker version, etc.)
- Relevant logs or error messages

### 2. Requesting Features
We welcome feature requests! Please open an issue describing:
- The problem you're trying to solve
- The proposed solution
- Why this would be valuable to the project

### 3. Contributing Code
We accept code contributions via pull requests. Please follow the guidelines below.

### 4. Improving Documentation
Documentation improvements are always welcome! This includes:
- Fixing typos or clarifying explanations
- Adding examples or tutorials
- Updating outdated information

### 5. Reporting Security Issues
**DO NOT** open public issues for security vulnerabilities. Instead, email the maintainers directly or use GitHub's security advisory feature.

## Getting Started

### Prerequisites
- Git installed
- Docker installed and running
- GitHub account
- Basic knowledge of Docker and GitHub Actions

### Fork and Clone
1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/github-runner.git
   cd github-runner
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/cicd/github-runner.git
   ```

### Create a Branch
```bash
git checkout -b feature/your-feature-name
```

## Development Setup

### 1. Local Development
```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/github-runner.git
cd github-runner

# Create a feature branch
git checkout -b feature/my-new-feature

# Make your changes
# ... edit files ...

# Run tests (if any)
# ... test your changes ...

# Commit your changes
git add .
git commit -m "Add feature: description of changes"

# Push to your fork
git push origin feature/my-new-feature

# Create a Pull Request on GitHub
```

### 2. Testing Your Changes
Before submitting a PR, test your changes:

```bash
# Build the base image
docker build -f docker/linux/base/Dockerfile.base -t test-runner:linux-base .

# Build language packs
docker build -f docker/linux/language-packs/cpp/Dockerfile.cpp -t test-runner:cpp-pack .

# Build composite images
docker build -f docker/linux/composite/Dockerfile.cpp-only -t test-runner:cpp-only .

# Test with Docker Compose
docker-compose -f docker-compose/linux-cpp.yml up -d
docker-compose -f docker-compose/linux-cpp.yml logs -f
```

## Pull Request Process

### 1. Create a Pull Request
1. Push your branch to your fork: `git push origin feature/your-feature`
2. Go to the GitHub repository
3. Click "New pull request"
4. Select your branch and the `main` branch
5. Fill out the PR template

### 2. PR Requirements
- **Title**: Clear, descriptive title (e.g., "Add Flet support for Python→Flutter")
- **Description**: Detailed description of changes
- **Linked Issue**: Reference any related issues using `Closes #123`
- **Tests**: All tests pass (if applicable)
- **Documentation**: Updated documentation as needed
- **Breaking Changes**: Mark as breaking if applicable

### 3. PR Template
Please use this template:

```markdown
## Description

Brief description of the changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Performance improvement

## Related Issues

Closes #123

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist

- [ ] Code follows project style guidelines
- [ ] Documentation has been updated
- [ ] Added tests for new functionality
- [ ] All commits follow conventional commits format
```

### 4. Review Process
1. A maintainer will review your PR
2. You may be asked to make changes
3. Once approved, your PR will be merged
4. Thank you for your contribution!

## Coding Guidelines

### 1. Dockerfile Guidelines
- Use multi-stage builds for optimization
- Always clean apt cache after installations
- Use official images as base when possible
- Add appropriate labels for metadata
- Follow security best practices

**Example:**
```dockerfile
# Good
RUN apt-get update && apt-get install -y --no-install-recommends \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*

# Bad
RUN apt-get update
RUN apt-get install -y package1 package2
```

### 2. Docker Compose Guidelines
- Use environment variables for configuration
- Add health checks for services
- Set appropriate resource limits
- Use version control for secrets

### 3. Python Guidelines
- Follow PEP 8 style guide
- Use meaningful variable names
- Add docstrings for functions
- Handle errors appropriately

### 4. Shell Script Guidelines
- Use `#!/bin/bash` or `#!/bin/sh`
- Quote all variables
- Use `set -e` for error handling
- Add comments for complex logic

### 5. Commit Message Guidelines
Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for Flutter language pack

feat: add Python→Flet integration

fix: correct memory leak in entrypoint script

docs: update README with new runners

refactor: improve build performance

test: add integration tests for Flutter

chore: update dependencies
```

## Testing Guidelines

### 1. Manual Testing
Always test your changes manually:

```bash
# Test base image
docker run --rm test-runner:linux-base --version

# Test composite images
docker run --rm test-runner:cpp-only gcc --version
docker run --rm test-runner:python-only python3 --version

# Test with GitHub Actions
# Create a test workflow and verify it works
```

### 2. Integration Testing
For complex changes, create integration tests:

```bash
# Create a test workflow file
cat > .github/workflows/test-runner.yml << EOF
name: Test Runner
on: [push]

jobs:
  test:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      - name: Test compiler
        run: gcc --version
EOF
```

### 3. Performance Testing
For performance improvements:

```bash
# Build with and without changes
time docker build -f docker/linux/base/Dockerfile.base -t test-base .

# Compare image sizes
docker images | grep test-base

# Test runtime performance
docker stats
```

## Documentation Guidelines

### 1. README Updates
- Update README.md when adding new features
- Keep the table of contents up to date
- Add examples for new functionality
- Update version numbers and links

### 2. Code Comments
- Add comments for complex logic
- Document function parameters
- Explain non-obvious decisions
- Keep comments up to date

### 3. Documentation Files
- Follow existing markdown structure
- Use consistent formatting
- Add examples and use cases
- Keep language clear and concise

### 4. Commit Messages
- Reference issue numbers when relevant
- Write clear, concise messages
- Explain "why" not just "what"

## Security

### 1. Reporting Vulnerabilities
**DO NOT** open public issues for security vulnerabilities.

Instead:
- Email maintainers directly
- Use GitHub Security Advisories
- Provide detailed but responsible disclosure

### 2. Security Best Practices
- Never hardcode secrets in Dockerfiles
- Use environment variables for sensitive data
- Run containers as non-root when possible
- Regularly update dependencies
- Use minimal base images

### 3. Dependency Management
- Pin versions in Dockerfiles
- Update dependencies regularly
- Review dependency licenses
- Avoid unused dependencies

## Communication

### 1. GitHub Issues
- Use issues for bug reports and feature requests
- Be respectful and constructive
- Provide complete information
- Use appropriate labels

### 2. Pull Requests
- Be responsive to review comments
- Keep PRs focused and small
- Ask questions if unclear
- Be patient with review process

### 3. Community
- Help other contributors
- Be welcoming to newcomers
- Share knowledge and best practices
- Celebrate contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have any questions, please open an issue or contact the maintainers.

---

**Thank you for contributing to GitHub Actions Runners!** 🎉
