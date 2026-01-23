# GitHub Actions Workflows Summary

## Files Created

This directory contains **8 workflow files** for different self-hosted runner configurations.

## Workflow Files

### 1. **cpp-only.yml** (10.9 KB)
**Purpose**: C/C++ development workflow
**Runner**: `gh-runner:cpp-only` (~550MB)
**Labels**: `linux, cpp, build`

**Features**:
- Matrix testing (GCC + Clang)
- CMake build system
- Unit tests with CTest
- Code coverage analysis
- Static analysis (clang-format, clang-tidy)
- Sanitizer testing (Address, Undefined)
- Package creation
- Deployment workflow

**Triggers**: Push to main/develop, PRs, manual dispatch

---

### 2. **python-only.yml** (15.0 KB)
**Purpose**: Python development workflow
**Runner**: `gh-runner:python-only` (~450MB)
**Labels**: `linux, python, ml`

**Features**:
- Multi-version Python testing (3.9, 3.10, 3.11)
- Linting (flake8, black, isort, mypy)
- Unit tests with pytest + coverage
- Integration tests
- Security scanning (Bandit, Safety)
- Docker image build
- Codecov coverage upload
- PyPI package build

**Triggers**: Push to main/develop/staging, PRs, manual dispatch

---

### 3. **web-stack.yml** (18.4 KB)
**Purpose**: Full-stack web development workflow
**Runner**: `gh-runner:web-stack` (~580MB)
**Labels**: `linux, node, go, web`

**Features**:
- Node.js testing (versions 18, 20)
- Go testing (versions 1.21, 1.22)
- Full-stack integration tests
- Docker multi-service build
- E2E testing with Playwright
- Firebase deployment
- Multi-container deployment

**Triggers**: Push to main/develop/staging, PRs, manual dispatch

---

### 4. **flutter-only.yml** (20.9 KB)
**Purpose**: Flutter mobile development workflow
**Runner**: `gh-runner:flutter-only` (~2GB)
**Labels**: `linux, flutter, mobile`

**Features**:
- Flutter version management (3.19.0)
- Dart analysis and formatting
- Unit tests with coverage
- Web build (PWA ready)
- Android APK/AAB builds
- iOS build support (requires macOS)
- Integration tests
- Firebase deployment
- App Store/Google Play publishing

**Triggers**: Push to main/develop/release/**, PRs, manual dispatch

---

### 5. **flet-only.yml** (24.2 KB)
**Purpose**: Flet (Python to Flutter) development workflow
**Runner**: `gh-runner:flet-only` (~3.8GB)
**Labels**: `linux, flet, mobile, web`

**Features**:
- Python testing (3.9, 3.10, 3.11)
- Flutter analysis
- Web build with Flet CLI
- Desktop builds (Linux)
- Android APK/AAB builds
- iOS build support
- E2E testing
- Multi-platform deployment

**Triggers**: Push to main/develop/release/**, PRs, manual dispatch

---

### 6. **full-stack.yml** (24.7 KB)
**Purpose**: Full-stack multi-language development workflow
**Runner**: `gh-runner:full-stack` (~2.5GB)
**Labels**: `linux, full, all`

**Features**:
- C/C++ testing (GCC + Clang)
- Python testing (3.9, 3.10, 3.11)
- Node.js testing (18, 20)
- Go testing (1.21, 1.22)
- Cross-language integration tests
- Docker multi-service build
- E2E testing
- Security scanning (all languages)
- Full deployment workflow

**Triggers**: Push to main/develop/staging, PRs, manual dispatch

---

### 7. **README.md** (8.5 KB)
**Purpose**: Comprehensive documentation for workflows
**Contents**:
- Overview and prerequisites
- Usage instructions
- Available workflows by runner
- Custom workflow examples
- Configuration examples
- CI/CD integration patterns
- Troubleshooting guide
- Security considerations
- Performance optimization
- Contribution guidelines

---

### 8. **QUICK_REFERENCE.md** (7.6 KB)
**Purpose**: Quick reference guide for workflows
**Contents**:
- Runner types and corresponding workflows
- Common workflow jobs
- Workflow patterns
- Integration examples
- Optimization tips
- Troubleshooting
- Use case examples
- Best practices

---

## Key Features Across All Workflows

### 1. **Testing**
- Unit tests
- Integration tests
- E2E tests (where applicable)
- Multi-version/multi-compiler testing

### 2. **Analysis & Linting**
- Language-specific linters
- Code formatting checks
- Static analysis
- Security scanning

### 3. **Building**
- Multi-platform builds
- Docker image builds
- Package creation
- Artifact generation

### 4. **Caching**
- Dependency caching (pip, npm, pub)
- Build artifact caching
- Docker layer caching

### 5. **Deployment**
- Environment-based deployment (staging/production)
- Multi-service deployment
- App store publishing
- Firebase/Cloud deployment

### 6. **Monitoring**
- Test result reporting
- Coverage reports
- Security reports
- Notification integration

## Workflow Structure

Each workflow follows a similar pattern:

```yaml
name: <Language> Workflow

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      # Manual trigger options

jobs:
  # 1. Analysis/Linting
  lint:
    runs-on: [self-hosted, linux, <label>]

  # 2. Unit Testing
  test:
    runs-on: [self-hosted, linux, <label>]

  # 3. Integration Testing
  integration-test:
    runs-on: [self-hosted, linux, <label>]

  # 4. Build
  build:
    runs-on: [self-hosted, linux, <label>]

  # 5. Deploy
  deploy:
    runs-on: [self-hosted, linux, <label>]
    environment: staging/production
```

## How to Use

### 1. Set Up Runners
Follow the [Quick Start Guide](../../docs/linux-modular/quick-start.md) to build and deploy your runners.

### 2. Choose Your Workflow
Select the workflow that matches your runner type:
- C/C++ → `cpp-only.yml`
- Python → `python-only.yml`
- Web (Node.js + Go) → `web-stack.yml`
- Flutter → `flutter-only.yml`
- Flet → `flet-only.yml`
- Multi-language → `full-stack.yml`

### 3. Copy to Your Repository
```bash
cp .github/workflows/<workflow-name>.yml .github/workflows/
```

### 4. Update Runner Labels
Modify the `runs-on` field to match your runner labels:
```yaml
runs-on: [self-hosted, linux, cpp]  # Change to your labels
```

### 5. Configure Secrets
Add GitHub Secrets for deployment and API access:
- `GITHUB_TOKEN`
- `DATABASE_URL`
- `API_KEY`
- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_KEY`

### 6. Trigger Workflow
- **Manual**: Go to Actions → Select workflow → Run workflow
- **Automatic**: Push to main/develop branch
- **On PR**: Create or update a pull request

## Customization Options

### Matrix Strategy
```yaml
strategy:
  matrix:
    version: ['3.9', '3.10', '3.11']
```

### Conditional Jobs
```yaml
if: github.ref == 'refs/heads/main'
```

### Environment Variables
```yaml
env:
  NODE_VERSION: '20'
  GO_VERSION: '1.22'
```

### Caching
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache
    key: ${{ runner.os }}-cache
```

### Artifacts
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: my-artifact
    path: build/
```

## Troubleshooting

### Common Issues

**1. Runner not found**
- Check runner labels match exactly
- Verify runner is online in GitHub UI

**2. Job stays queued**
- Check runner capacity
- Verify no other jobs are using the runner

**3. Permission denied**
- Fix permissions in workflow steps
- Use `sudo` if needed (rarely)

**4. Out of memory**
- Increase memory limit in Docker Compose
- Reduce parallel jobs

**5. Build timeout**
- Increase timeout in workflow
- Optimize build steps
- Use build caching

### Debugging

```bash
# View runner logs
docker logs -f <runner-container>

# Check workflow logs
# GitHub UI → Actions → Click on workflow run

# Test locally
act -P ubuntu-latest=gh-runner:full-stack
```

## Performance Tips

### 1. Use Caching
Always cache dependencies to avoid re-downloading.

### 2. Parallel Execution
Use matrix strategy for multi-version testing.

### 3. Artifact Optimization
Only upload necessary files.

### 4. Build Optimization
- Use build cache
- Minimize layer count
- Use multi-stage builds

## Integration Examples

### Single Workflow (All Jobs)
```yaml
jobs:
  test-cpp:
    runs-on: [self-hosted, linux, cpp]

  test-python:
    runs-on: [self-hosted, linux, python]

  test-node:
    runs-on: [self-hosted, linux, node]

  deploy:
    needs: [test-cpp, test-python, test-node]
    runs-on: [self-hosted, linux, web]
```

### Multiple Workflows
```bash
# .github/workflows/
# ├── cpp.yml
# ├── python.yml
# ├── web.yml
# └── deploy.yml
```

### Scheduled Workflows
```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
```

## Resources

### Documentation
- [Composite Images](../../docs/linux/composite/README.md)
- [Language Packs](../../docs/linux/language-packs/README.md)
- [Quick Start](../../docs/linux-modular/quick-start.md)
- [Configuration](../../docs/linux/configuration.md)

### GitHub Actions
- [Official Documentation](https://docs.github.com/en/actions)
- [Actions Reference](https://docs.github.com/en/actions/reference)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

### Docker
- [Docker Documentation](https://docs.docker.com/)
- [Docker BuildKit](https://docs.docker.com/build/buildkit/)

## Contributing

If you have improvements or new workflow examples:
1. Fork the repository
2. Add/modify workflow files
3. Test thoroughly
4. Create a pull request
5. Include documentation updates

## Support

For issues or questions:
1. Check this README
2. Review workflow logs
3. Check runner status
4. Review [Documentation](../../docs/)
5. Open a GitHub Issue

---

**Last Updated**: 2026-01-23
**Version**: 1.0.0
**Documentation**: [README.md](README.md) | [Quick Reference](QUICK_REFERENCE.md)
