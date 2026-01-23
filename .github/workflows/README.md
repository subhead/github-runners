# GitHub Actions Workflows Examples

This directory contains example GitHub Actions workflow files for using self-hosted GitHub Actions runners.

## Overview

These workflows demonstrate how to use the different Docker-based runners:
- **C++ Only** - For C/C++ development
- **Python Only** - For Python development
- **Web Stack** - For Node.js + Go development
- **Flutter Only** - For Flutter mobile development
- **Flet Only** - For Flet (Python to Flutter) development
- **Full Stack** - For multi-language projects

## Usage

### Prerequisites

1. **Set up runners**: Follow the [Quick Start Guide](../../docs/linux-modular/quick-start.md) to build and deploy your runners

2. **Configure runners with labels**: Each runner must have appropriate labels:
   - C++ Runner: `linux, cpp, build`
   - Python Runner: `linux, python, ml`
   - Web Runner: `linux, node, go, web`
   - Flutter Runner: `linux, flutter, mobile`
   - Flet Runner: `linux, flet, mobile, web`
   - Full Stack Runner: `linux, full, all`

3. **Update workflow files**: Replace `self-hosted, linux, cpp` with your actual runner labels

### Running Workflows

1. Copy the desired workflow file to your repository:
   ```bash
   cp .github/workflows/cpp-only.yml .github/workflows/
   ```

2. Trigger the workflow:
   - Manually via GitHub UI (Actions tab)
   - On push/PR to specific branches
   - Using `workflow_dispatch`

## Available Workflows

### 1. C++ Build and Test

**File**: `cpp-only.yml`

**Use Case**: Building C/C++ applications, systems programming, embedded development

**Runner**: `gh-runner:cpp-only` (~550MB)

**Capabilities**:
- GCC/Clang compilers
- CMake build system
- Make, GDB, Valgrind
- Common libraries

### 2. Python Development

**File**: `python-only.yml`

**Use Case**: Python development, ML/AI, data science

**Runner**: `gh-runner:python-only` (~450MB)

**Capabilities**:
- Python 3.x
- pip, venv
- ML libraries (TensorFlow, PyTorch)
- Data science tools (pandas, NumPy)

### 3. Web Development (Node.js + Go)

**File**: `web-stack.yml`

**Use Case**: Full-stack web development, microservices

**Runner**: `gh-runner:web-stack` (~580MB)

**Capabilities**:
- Node.js 20 LTS
- npm, yarn, pnpm
- Go 1.22
- nginx

### 4. Flutter Mobile Development

**File**: `flutter-only.yml`

**Use Case**: Flutter mobile app development (Android, iOS, Web)

**Runner**: `gh-runner:flutter-only` (~2GB)

**Capabilities**:
- Flutter SDK
- Dart SDK
- Android SDK (for Android builds)
- Chrome (for web testing)

### 5. Flet Development

**File**: `flet-only.yml`

**Use Case**: Flet (Python to Flutter) development

**Runner**: `gh-runner:flet-only` (~3.8GB)

**Capabilities**:
- Python 3.x
- Flet framework
- Flutter SDK
- Android SDK
- Chrome for web testing

### 6. Full Stack Development

**File**: `full-stack.yml`

**Use Case**: Multi-language projects, legacy support

**Runner**: `gh-runner:full-stack` (~2.5GB)

**Capabilities**:
- Python 3.x
- C/C++ toolchain
- Node.js 20 LTS
- Go 1.22
- All common tools

## Custom Workflows

### Using Multiple Runners

You can run different jobs on different runners:

```yaml
jobs:
  build-cpp:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make

  test-python:
    runs-on: [self-hosted, linux, python]
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: pytest

  deploy-web:
    runs-on: [self-hosted, linux, node, go]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ./deploy.sh
```

### Conditional Workflow Steps

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, full]
    steps:
      - uses: actions/checkout@v4

      - name: Build C++
        if: contains(github.event.labels.*.name, 'cpp') || contains(github.ref, 'cpp')
        run: |

      - name: Build Python
        if: contains(github.event.labels.*.name, 'python') || contains(github.ref, 'python')
        run: |
```

### Matrix Strategy

```yaml
jobs:
  build:
    strategy:
      matrix:
        language: [cpp, python, node, go]
    runs-on: [self-hosted, linux, ${{ matrix.language }}]
    steps:
      - uses: actions/checkout@v4
      - name: Build ${{ matrix.language }}
        run: ./build-${{ matrix.language }}.sh
```

## Configuration Examples

### Environment Variables

Most workflows need these environment variables:

```yaml
env:
  DEBIAN_FRONTEND: noninteractive
  CPPFLAGS: "-I/usr/local/include"
  LDFLAGS: "-L/usr/local/lib"
```

### Caching Dependencies

```yaml
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: ~/.cache
    key: ${{ runner.os }}-cache-${{ hashFiles('**/requirements.txt', '**/package.json') }}
```

### Docker-in-Docker (if needed)

```yaml
- name: Setup Docker
  uses: docker/setup-buildx-action@v2
  with:
    driver: docker-container
```

## Troubleshooting

### Runner Not Found

**Symptom**: Job stays in "queued" state

**Solution**:
1. Check runner status in GitHub UI
2. Verify runner has correct labels
3. Check runner logs: `docker logs -f <runner-container>`

### Permission Denied

**Symptom**: `Permission denied` errors during build

**Solution**:
```yaml
- name: Fix permissions
  run: sudo chown -R runner:runner .
```

### Out of Memory

**Symptom**: Build fails with memory errors

**Solution**:
1. Increase runner memory limit in Docker Compose
2. Reduce parallel jobs
3. Add swap space in Dockerfile

## CI/CD Integration

### Deploy to Multiple Environments

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: cmake --build build

  deploy-staging:
    runs-on: [self-hosted, linux, web]
    needs: build
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Staging
        run: ./deploy-staging.sh
    environment: staging

  deploy-production:
    runs-on: [self-hosted, linux, web]
    needs: [build, deploy-staging]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Production
        run: ./deploy-production.sh
    environment: production
```

### Release Workflow

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, full]
    steps:
      - uses: actions/checkout@v4
      - name: Build all
        run: ./build-all.sh
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build-output/
```

## Security Considerations

### Secrets Management

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, web]
    steps:
      - name: Deploy with Secrets
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: ./deploy.sh
```

### Docker Security

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
    steps:
      - name: Run Docker securely
        run: |
          docker run --rm \
            --security-opt=no-new-privileges:true \
            --cap-drop=ALL \
            my-image:latest
```

## Performance Optimization

### Build Time

1. **Use Build Cache**: Enable Docker BuildKit
   ```bash
   export DOCKER_BUILDKIT=1
   ```

2. **Parallel Jobs**: Run independent jobs in parallel
   ```yaml
   jobs:
     test:
       strategy:
         matrix:
           os: [linux, macos, windows]
   ```

3. **Cache Dependencies**: Use GitHub Actions cache
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.cache
       key: ${{ runner.os }}-cache
   ```

### Resource Management

1. **Set Limits**: Configure Docker Compose with resource limits
   ```yaml
   services:
     runner:
       mem_limit: 4g
       cpus: '2.0'
   ```

2. **Monitor Usage**: Use `docker stats` to track resource usage

3. **Scale Runners**: Add more runners for parallel builds

## Next Steps

1. **Read Documentation**: See [Composite Images](../../docs/linux/composite/README.md)
2. **Build Images**: Follow [Quick Start](../../docs/linux-modular/quick-start.md)
3. **Deploy Runners**: Use [Docker Compose](../../docker-compose/)
4. **Create Workflows**: Copy and customize the examples here
5. **Monitor & Optimize**: Track build times and resource usage

## Support

- **Documentation**: `docs/` directory
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: [README.md](../../README.md)

## Contributing

If you have workflow examples to add:
1. Create a new workflow file
2. Add documentation in this README
3. Test the workflow
4. Submit a PR
