# Workflow Quick Reference Guide

## Overview

This guide provides a quick reference for using the example GitHub Actions workflows with self-hosted runners.

## Runner Types & Corresponding Workflows

| Runner Image | Size | Labels | Workflow File | Use Case |
|--------------|------|--------|---------------|----------|
| `gh-runner:cpp-only` | ~550MB | `linux, cpp, build` | `cpp-only.yml` | C/C++ development, systems programming |
| `gh-runner:python-only` | ~450MB | `linux, python, ml` | `python-only.yml` | Python development, ML/AI |
| `gh-runner:web-stack` | ~580MB | `linux, node, go, web` | `web-stack.yml` | Node.js + Go web development |
| `gh-runner:flutter-only` | ~2GB | `linux, flutter, mobile` | `flutter-only.yml` | Flutter mobile development |
| `gh-runner:flet-only` | ~3.8GB | `linux, flet, mobile, web` | `flet-only.yml` | Flet (Python to Flutter) development |
| `gh-runner:full-stack` | ~2.5GB | `linux, full, all` | `full-stack.yml` | Multi-language projects |

## Workflow Triggers

### Manual Trigger (workflow_dispatch)
```bash
# Via GitHub UI:
# 1. Go to Actions tab
# 2. Select workflow
# 3. Click "Run workflow"
# 4. Select options
```

### Automated Triggers
```yaml
# Push to main/develop
push:
  branches: [main, develop]

# Pull requests
pull_request:
  branches: [main, develop]
```

## Common Workflow Jobs

### 1. Analysis & Linting
- **C++**: `clang-format`, `clang-tidy`, `cppcheck`
- **Python**: `flake8`, `black`, `isort`, `mypy`
- **Node.js**: `eslint`, `prettier`
- **Go**: `go vet`, `gofmt`
- **Flutter**: `flutter analyze`

### 2. Unit Testing
- **C++**: `ctest`, `googletest`
- **Python**: `pytest`, `pytest-cov`
- **Node.js**: `jest`, `mocha`
- **Go**: `go test`
- **Flutter**: `flutter test`

### 3. Build/Compile
- **C++**: `cmake --build`, `make`
- **Python**: `pip build`, `setuptools`
- **Node.js**: `npm run build`
- **Go**: `go build`
- **Flutter**: `flutter build`

### 4. Integration Testing
- API integration tests
- Database integration
- Third-party service tests

### 5. Docker Build
- Build multi-arch images
- Security scanning (Trivy)
- Push to registry

### 6. Deployment
- Deploy to staging/production
- Smoke tests
- Rollback on failure

## Common Patterns

### 1. Matrix Strategy (Multiple Versions)
```yaml
strategy:
  matrix:
    python-version: ['3.9', '3.10', '3.11']
    node-version: [18, 20]
    go-version: ['1.21', '1.22']
```

### 2. Conditional Execution
```yaml
- name: Deploy
  if: github.ref == 'refs/heads/main'
  run: ./deploy.sh
```

### 3. Artifacts
```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: my-artifact
    path: build/
    retention-days: 7
```

### 4. Caching
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
```

### 5. Secrets
```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  API_KEY: ${{ secrets.API_KEY }}
```

## Workflow File Structure

Each workflow file follows this pattern:

```yaml
name: <Workflow Name>

on:
  # Triggers
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      # Manual trigger options

env:
  # Environment variables

jobs:
  <job-name>:
    runs-on: [self-hosted, linux, <label>]
    strategy:
      matrix:
        # Matrix configuration
    steps:
      - name: Step name
        run: |
          # Commands
```

## Integration with Existing Workflows

### Adding to Your Repository

1. **Copy workflow file**:
   ```bash
   cp .github/workflows/cpp-only.yml .github/workflows/
   ```

2. **Update runner labels**:
   ```yaml
   runs-on: [self-hosted, linux, cpp]
   # Change to your actual runner labels
   ```

3. **Configure secrets**:
   - Go to Settings → Secrets and variables → Actions
   - Add secrets:
     - `GITHUB_TOKEN`
     - `DATABASE_URL`
     - `API_KEY`
     - `DEPLOY_HOST`
     - `DEPLOY_USER`
     - `DEPLOY_KEY`

### Multi-Workflow Example

```yaml
# .github/workflows/main.yml
jobs:
  test-cpp:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      - name: Test C++
        run: make test

  test-python:
    runs-on: [self-hosted, linux, python]
    steps:
      - uses: actions/checkout@v4
      - name: Test Python
        run: pytest

  deploy-web:
    runs-on: [self-hosted, linux, web]
    needs: [test-cpp, test-python]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ./deploy.sh
```

## Optimization Tips

### 1. Parallel Execution
```yaml
jobs:
  test:
    strategy:
      matrix:
        test-suite: [unit, integration, e2e]
    runs-on: [self-hosted, linux, full]
```

### 2. Caching Strategies
- **Python**: Cache pip packages
- **Node.js**: Cache npm packages
- **Go**: Enable Go module cache
- **Flutter**: Cache pub cache

### 3. Build Caching
```yaml
- name: Cache build
  uses: actions/cache@v4
  with:
    path: build/
    key: ${{ runner.os }}-build-${{ github.sha }}
```

### 4. Artifact Management
- Upload only necessary artifacts
- Set appropriate retention days
- Use artifact names that include run ID

## Troubleshooting

### Runner Not Found
```yaml
# Check if runner is online
# In GitHub UI: Settings → Actions → Runners
# Check labels match exactly
runs-on: [self-hosted, linux, cpp]
```

### Job Stays Queued
1. Verify runner labels
2. Check runner is online
3. Check runner capacity

### Permission Denied
```yaml
# Fix permissions in workflow
- name: Fix permissions
  run: sudo chown -R runner:runner .
```

### Out of Memory
```yaml
# Increase memory limit in Docker Compose
# docker-compose/production.yml
services:
  runner:
    mem_limit: 4g
```

## Examples by Use Case

### 1. C/C++ Library
```yaml
# cpp-only.yml
# - Build with CMake
# - Unit tests with gtest
# - Code coverage with gcov
# - Package as .so/.a/.deb
```

### 2. Python Web App
```yaml
# python-only.yml
# - Lint with flake8/black
# - Test with pytest
# - Build Docker image
# - Deploy to AWS
```

### 3. Full-Stack Web App
```yaml
# web-stack.yml
# - Build Node.js frontend
# - Build Go backend
# - Run integration tests
# - Deploy to Kubernetes
```

### 4. Flutter Mobile App
```yaml
# flutter-only.yml
# - Analyze Flutter code
# - Build Android APK/AAB
# - Run unit tests
# - Deploy to Google Play
```

### 5. Flet Desktop App
```yaml
# flet-only.yml
# - Python tests
# - Build desktop app
# - Build web version
# - Deploy to app stores
```

## Best Practices

### 1. Use Caching
Always cache dependencies to speed up builds.

### 2. Set Resource Limits
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, full]
    steps:
      - name: Build
        run: make -j$(nproc)
```

### 3. Use Artifacts
Upload build artifacts for reuse in later jobs.

### 4. Monitor Performance
```bash
# Check build times
# Review workflow runs in GitHub UI
# Optimize slow steps
```

### 5. Security
- Never commit secrets
- Use GitHub Secrets
- Scan for vulnerabilities
- Update dependencies regularly

## Next Steps

1. **Set up runners** - Follow the Quick Start Guide
2. **Copy workflow files** - Copy the examples to your repo
3. **Update labels** - Match your runner labels
4. **Configure secrets** - Add required secrets
5. **Test workflows** - Run manually to verify
6. **Monitor & optimize** - Review run times and optimize

## Support

For issues:
1. Check workflow logs in GitHub UI
2. Verify runner status
3. Check runner logs: `docker logs -f <runner-container>`
4. Review [Documentation](../../docs/)
