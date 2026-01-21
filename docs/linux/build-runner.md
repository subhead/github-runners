# Build Runner Documentation

## Overview

The Build Runner is a comprehensive self-hosted GitHub Actions runner with full development toolchains and language runtimes. It's optimized for building applications across multiple platforms and languages.

## Key Features

- **Comprehensive Toolchains**: 10+ programming languages and build systems
- **Full Development Environment**: Build tools, compilers, package managers
- **Docker-in-Docker Ready**: Built-in Docker support for container builds
- **Multi-Language Support**: Node.js, Python, Java, .NET, Rust, Go, PHP, Ruby, Swift
- **Cloud CLI Tools**: AWS, Azure, GCP, Kubernetes support
- **Image Size**: ~2.5GB (comprehensive but manageable)

## Included Tools

### Programming Languages

| Language | Version | Tools |
|----------|---------|-------|
| **Python** | 3.x | pip, venv, wheel, dev headers |
| **Node.js** | 20.x LTS | npm, yarn |
| **Java** | 17 LTS | JDK, JRE |
| **.NET** | 8.0 | SDK, ASP.NET Core Runtime |
| **Rust** | Stable | rustc, cargo, rustfmt, clippy |
| **Go** | 1.22 | go toolchain |
| **PHP** | 8.2 | CLI, extensions |
| **Ruby** | 3.2 | Full stack, bundler |
| **Swift** | 5.10 | For Apple platforms |

### Build Tools

| Tool | Purpose |
|------|---------|
| **GCC/Clang** | C/C++ compilation |
| **CMake** | Cross-platform build system |
| **Ninja** | Fast build system |
| **Make** | Build automation |
| **Git LFS** | Large file support |
| **Docker** | Container builds |

### Cloud Tools

| Tool | Purpose |
|------|---------|
| **AWS CLI v2** | AWS management |
| **Azure CLI** | Azure management |
| **Google Cloud SDK** | GCP management |
| **Kubectl** | Kubernetes management |

## Installation

### Prerequisites

- Docker 20.10+ installed
- At least 4GB RAM available
- GitHub Personal Access Token with `repo` scope
- GitHub repository (format: `owner/repo`)

### Quick Start

#### Using Docker Directly

```bash
# Build the image
docker build \
  -f docker/linux/Dockerfile.build-runner \
  -t gh-runner:linux-build \
  .

# Run the runner (requires Docker socket)
docker run -d \
  --name github-build-runner \
  -e GITHUB_TOKEN=ghp_your_token_here \
  -e GITHUB_REPOSITORY=your-org/your-repo \
  -e RUNNER_NAME=linux-build-runner \
  -e RUNNER_LABELS=linux,build,docker \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

#### Using Docker Compose

```bash
# Using the provided docker-compose file
docker-compose -f docker-compose/linux-runners.yml up gh-build-runner -d
```

### Configuration Options

#### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub Personal Access Token | `ghp_xxxxxxxx` |
| `GITHUB_REPOSITORY` | Target repository or organization | `owner/repo` |

#### Optional Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RUNNER_NAME` | Unique identifier | Hostname | `linux-build-1` |
| `RUNNER_LABELS` | Comma-separated labels | `linux,build,docker,java,node,python,dotnet,rust,go` | `linux,build,production` |
| `RUNNER_GROUP` | Runner group | `default` | `build-group` |
| `CLEANUP_EXISTING` | Remove existing config | `false` | `true` |
| `FORCE_RECONFIGURE` | Force reconfiguration | `false` | `true` |

**Note**: Docker socket is required for Docker-in-Docker builds. It's enabled by default for build runners.

## Use Cases

### 1. Multi-Language Application Builds

Build applications with multiple languages and dependencies:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Build Backend (Java)
        run: |
          cd backend
          mvn clean package

      - name: Build Frontend (Node.js)
        run: |
          cd frontend
          npm ci
          npm run build

      - name: Build Mobile (Swift)
        run: |
          cd mobile
          swift build

      - name: Package Application
        run: |
          tar -czf app.tar.gz backend/target frontend/build
```

### 2. Docker Image Builds

Build and push Docker images with full tooling:

```yaml
jobs:
  build-images:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker Image
        run: |
          docker build -t myapp:${{ github.sha }} .
          docker tag myapp:${{ github.sha }} myapp:latest

      - name: Push to Registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push myapp:${{ github.sha }}
          docker push myapp:latest
```

### 3. Cross-Platform Compilation

Build for different architectures:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Cross-Compile C Application
        run: |
          # Build for x86_64
          make clean
          make CC=gcc ARCH=x86_64

          # Build for ARM64 (using cross-compiler)
          make clean
          make CC=aarch64-linux-gnu-gcc ARCH=arm64

      - name: Build Rust Application
        run: |
          # Build for Linux
          cargo build --release --target x86_64-unknown-linux-gnu

          # Build for macOS
          cargo build --release --target x86_64-apple-darwin
```

### 4. Cloud Deployment Builds

Build and deploy to multiple cloud platforms:

```yaml
jobs:
  build-and-deploy:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Build Application
        run: make build

      - name: Deploy to AWS
        run: |
          aws s3 sync build/ s3://my-bucket/
          aws cloudfront create-invalidation --distribution-id ${{ secrets.CF_ID }} --paths "/*"

      - name: Deploy to Azure
        run: |
          az storage blob upload-batch --account-name mystorage --source build/ --destination '$web'

      - name: Deploy to GCP
        run: |
          gsutil -m rsync -r build/ gs://my-bucket/
```

### 5. Monorepo Builds

Build multiple projects in a monorepo:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Build Backend (Java/Gradle)
        run: |
          cd backend
          ./gradlew build

      - name: Build Frontend (Node.js)
        run: |
          cd frontend
          npm ci
          npm run build

      - name: Build Mobile (React Native)
        run: |
          cd mobile
          npm ci
          npx react-native bundle --platform android --dev false --entry-file index.js --bundle-output android/app/build/intermediates/assets/debug/index.android.bundle

      - name: Run Integration Tests
        run: |
          cd tests
          npm ci
          npm run integration
```

## Performance

### Resource Requirements

**Minimum**:
- CPU: 2 cores
- Memory: 4GB
- Disk: 20GB free space

**Recommended**:
- CPU: 4 cores
- Memory: 8GB
- Disk: 50GB free space (for build caches)

### Optimization Tips

1. **Use Cache Volumes**: Mount persistent caches for faster builds

```bash
docker run -d \
  -v npm-cache:/home/runner/.npm \
  -v maven-cache:/home/runner/.m2 \
  -v cargo-cache:/home/runner/.cargo \
  gh-runner:linux-build
```

2. **Parallel Builds**: Use multiple runners for parallel jobs

```bash
docker-compose -f docker-compose/linux-runners.yml up --scale gh-build-runner=3 -d
```

3. **BuildKit**: Enable for faster Docker builds

```bash
export DOCKER_BUILDKIT=1
docker build ...
```

### Scaling Strategy

| Scenario | Runner Count | CPU per Runner | RAM per Runner |
|----------|--------------|----------------|----------------|
| Small Team | 1-2 | 2-4 cores | 4-8GB |
| Medium Team | 3-5 | 4-8 cores | 8-16GB |
| Large Team | 5-10 | 4-8 cores | 8-16GB |
| Enterprise | 10+ | 8+ cores | 16GB+ |

## Docker-in-Docker (DinD)

### Security Considerations

**⚠️ Critical Security Warning**: Mounting `/var/run/docker.sock` grants the container access to the host Docker daemon. This is a significant security risk.

**Risk Mitigation**:
- Use read-only mount: `/var/run/docker.sock:/var/run/docker.sock:ro`
- Run only trusted images
- Regular security audits
- Consider rootless Docker on host
- Use Docker Bench Security

### Alternative Approaches

#### 1. Docker-in-Docker (DinD) - Current Approach

```bash
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

**Pros**: Fast, works with existing Docker setup
**Cons**: Security risk, shares host Docker daemon

#### 2. Docker-out-of-Docker (DooD) - Better Security

Use host Docker socket but with user namespaces:

```bash
# On host: Enable user namespaces
echo '{"userns-remap":"default"}' > /etc/docker/daemon.json
systemctl restart docker

# Then run container
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

#### 3. Podman as Alternative

Consider Podman for rootless container builds:

```bash
# On host: Install Podman
# In container: Use podman socket
docker run -d \
  -v /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

### Best Practices

1. **Use Read-Only Mount**: Always use `:ro` flag
2. **Regular Updates**: Keep Docker Engine updated
3. **Security Scanning**: Scan images regularly
4. **Network Isolation**: Use separate networks
5. **Resource Limits**: Prevent resource exhaustion

## Language-Specific Examples

### Python

```yaml
jobs:
  build-python:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install Dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Run Linter
        run: flake8 src/

      - name: Run Tests
        run: pytest --cov=src tests/

      - name: Build Package
        run: |
          python setup.py sdist bdist_wheel
          twine check dist/*
```

### Node.js

```yaml
jobs:
  build-node:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install Dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm test -- --coverage

      - name: Build
        run: npm run build

      - name: Package
        run: npm pack
```

### Java

```yaml
jobs:
  build-java:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build with Maven
        run: mvn clean package

      - name: Run Tests
        run: mvn test

      - name: Run Static Analysis
        run: mvn sonar:sonar
```

### .NET

```yaml
jobs:
  build-dotnet:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test
        run: dotnet test --no-build --verbosity normal

      - name: Publish
        run: dotnet publish --no-build --configuration Release --output ./publish
```

### Rust

```yaml
jobs:
  build-rust:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true
          components: rustfmt, clippy

      - name: Format Check
        run: cargo fmt -- --check

      - name: Clippy
        run: cargo clippy -- -D warnings

      - name: Test
        run: cargo test

      - name: Build Release
        run: cargo build --release
```

### Go

```yaml
jobs:
  build-go:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.22'

      - name: Test
        run: go test ./...

      - name: Lint
        run: |
          go install golang.org/x/lint/golint@latest
          golint ./...

      - name: Build
        run: go build -o app ./cmd/

      - name: Cross-Compile
        env:
          GOOS: linux
          GOARCH: amd64
        run: go build -o app-linux-amd64 ./cmd/
```

## Troubleshooting

### Build Failures

#### 1. Out of Memory

**Symptom**: Build fails with `SIGKILL` or `out of memory`

**Solutions**:
- Increase container memory limit
- Use swap space (temporary solution)
- Optimize build to use less memory
- Split build into multiple jobs

```bash
# Increase memory in docker-compose
mem_limit: 8g
```

#### 2. Docker-in-Docker Issues

**Error**: `Cannot connect to Docker daemon`

**Solutions**:
```bash
# Verify Docker socket is mounted
docker inspect github-build-runner | jq '.[].Mounts'

# Check container logs
docker logs github-build-runner

# Verify Docker is running on host
docker info
```

#### 3. Language Runtime Not Found

**Error**: `Command not found: node`, `python: command not found`

**Solutions**:
1. Check which runtime version is installed
2. Use explicit version in setup actions
3. Verify PATH environment variable

```bash
# Inside container
which node
which python3
which java
which dotnet
```

### Slow Builds

**Possible causes**:
1. No cache volumes mounted
2. Network issues downloading dependencies
3. Insufficient CPU resources
4. Disk I/O bottleneck

**Solutions**:
```bash
# Mount cache volumes
docker run -d \
  -v npm-cache:/home/runner/.npm \
  -v maven-cache:/home/runner/.m2 \
  gh-runner:linux-build

# Increase CPU limit
docker-compose up --scale gh-build-runner=2
```

### Dependency Download Failures

**Error**: Network timeouts when downloading packages

**Solutions**:
1. Check network connectivity
2. Use internal package registries
3. Configure proxy settings if needed
4. Implement retry logic in workflows

```yaml
- name: Install Dependencies
  run: |
    npm config set fetch-retries 5
    npm config set fetch-retry-mintimeout 10000
    npm ci
```

## Advanced Configuration

### Custom Build Runner

Create a custom build runner with specific tools:

```dockerfile
# docker/linux/Dockerfile.custom-build
FROM gh-runner:linux-build

# Install additional development tools
RUN apt-get update && apt-get install -y \
    clang-tidy \
    cppcheck \
    valgrind \
    gdb \
    lldb \
    # Additional languages
    ocaml \
    opam \
    # Database clients
    mongodb-org-shell \
    redis-tools \
    # Other tools
    jq \
    yq \
    terraform \
    && rm -rf /var/lib/apt/lists/*

# Custom environment variables
ENV CUSTOM_BUILD_TOOL=/usr/local/bin/my-tool
```

### Multi-Stage Build Optimization

For specialized build scenarios:

```dockerfile
# Stage 1: Build environment
FROM ubuntu:22.04 AS builder

# Install build tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    ...

# Build application
WORKDIR /build
COPY . .
RUN cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build

# Stage 2: Runtime environment
FROM ubuntu:22.04 AS runtime

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/build/myapp /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/myapp"]
```

## Monitoring and Maintenance

### Health Checks

Build runners include health checks:

```bash
# Check container health
docker inspect github-build-runner | jq '.[].State.Health'

# Manually test health endpoint
docker exec github-build-runner curl -f http://localhost:8080/
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats github-build-runner

# Detailed resource usage
docker inspect github-build-runner | jq '.[].HostConfig'

# Check disk usage
docker exec github-build-runner df -h
```

### Log Analysis

```bash
# Follow logs
docker logs -f github-build-runner

# Search for specific errors
docker logs github-build-runner 2>&1 | grep -i error

# Check runner status
docker exec github-build-runner cat /actions-runner/.runner
```

### Cleanup

```bash
# Remove old Docker images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove stopped containers
docker container prune

# Remove build cache
docker builder prune -a
```

## Security Best Practices

### 1. Docker Socket Security

**Do**:
- Use read-only mount: `:ro`
- Run on isolated networks
- Regular security audits
- Use Docker Bench Security

**Don't**:
- Mount read-write without necessity
- Run untrusted images
- Expose to public internet

### 2. Token Security

- Use fine-grained personal access tokens
- Grant minimal permissions
- Rotate tokens regularly (90 days)
- Store in GitHub Secrets

### 3. Network Security

- Use private VPCs/subnets
- Implement VPN access
- Restrict outbound traffic
- Use security groups/firewalls

### 4. Image Security

```bash
# Scan images for vulnerabilities
docker scan gh-runner:linux-build

# Use trusted base images
# Official Ubuntu images only
```

## CI/CD Pipeline Integration

### GitHub Actions Workflow

```yaml
name: Full CI/CD Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  lint:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3
      - run: npm run lint

  test:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3
      - run: npm test

  build:
    needs: [lint, test]
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3
      - run: npm run build
      - uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: dist/

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: build-artifacts
      - run: ./deploy.sh staging

  deploy-production:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: [self-hosted, linux, build, production]
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: build-artifacts
      - run: ./deploy.sh production
```

## Performance Benchmarks

### Build Times Comparison

| Project Type | GitHub Hosted | Self-Hosted (Action) | Self-Hosted (Build) |
|--------------|---------------|----------------------|---------------------|
| **Node.js App** | 3-5 min | 2-3 min | 2-3 min |
| **Java App** | 5-8 min | 4-5 min | 4-5 min |
| **.NET App** | 6-10 min | 5-6 min | 5-6 min |
| **Docker Image** | 4-7 min | 3-4 min | 3-4 min |
| **Rust App** | 8-12 min | 6-8 min | 6-8 min |
| **Multi-Language** | 15-20 min | 12-15 min | 12-15 min |

*Note: Actual times vary based on project size, dependencies, and cache state.*

## Cost Analysis

### Cost Comparison (Monthly)

| Provider | Medium Tier | Large Tier | Notes |
|----------|-------------|------------|-------|
| **GitHub Hosted** | $15-25 | $40-60 | Per minute billing, no overhead |
| **AWS EC2 (t3.medium)** | ~$30 | ~$60 | + EBS storage, data transfer |
| **DigitalOcean** | $24 | $48 | Fixed monthly, easy setup |
| **Self-Hosted (On-prem)** | $50-100 | $100-200 | Hardware, maintenance, power |

*Self-hosted becomes cost-effective at scale or with existing infrastructure.*

## Advanced Use Cases

### 1. GPU Builds

For machine learning or GPU-accelerated builds:

```bash
# Requires NVIDIA Docker runtime
docker run -d \
  --gpus all \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

### 2. iOS/Mac Builds (Cross-Platform)

Build iOS apps on Linux (limited support):

```yaml
jobs:
  build-ios:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Install Swift (for Linux builds)
        run: |
          # Install Swift for Linux
          wget https://download.swift.org/swift-5.10-release/ubuntu2204/swift-5.10-RELEASE/swift-5.10-RELEASE-ubuntu22.04.tar.gz
          tar xzf swift-5.10-RELEASE-ubuntu22.04.tar.gz -C /usr/local --strip-components=1

      - name: Build for Linux (Testing)
        run: |
          swift build
          swift test
```

### 3. Kubernetes/Helm Builds

Build and deploy Kubernetes manifests:

```yaml
jobs:
  build-k8s:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Lint Helm Charts
        run: |
          helm lint ./charts/
          helm template ./charts/ --validate

      - name: Build Docker Images
        run: |
          docker build -t myapp:${{ github.sha }} .
          docker build -t nginx:${{ github.sha }} ./nginx/

      - name: Push to Registry
        run: |
          echo ${{ secrets.REGISTRY_PASSWORD }} | docker login -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
          docker push myapp:${{ github.sha }}
          docker push nginx:${{ github.sha }}

      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/
          kubectl rollout status deployment/myapp
```

### 4. Mobile App Builds (Android)

Build Android apps on Linux:

```yaml
jobs:
  build-android:
    runs-on: [self-hosted, linux, build]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Build APK
        run: |
          cd android
          ./gradlew assembleRelease

      - name: Sign APK
        run: |
          jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore ${{ secrets.KEYSTORE }} app/build/outputs/apk/release/app-release-unsigned.apk alias_name
```

## Reference

### Image Details

- **Base Image**: Ubuntu 22.04 LTS
- **Runner Version**: 2.331.0
- **Architecture**: x64
- **Size**: ~2.5GB
- **User**: runner (UID 1001)
- **Work Directory**: `/actions-runner`

### Environment Variables

```bash
# Available environment variables
$RUNNER_NAME
$RUNNER_LABELS
$RUNNER_GROUP
$WORK_DIR
$PATH (includes Rust, Go, etc.)
```

### Useful Commands

```bash
# Check installed tools
docker exec github-build-runner node --version
docker exec github-build-runner python3 --version
docker exec github-build-runner java -version
docker exec github-build-runner dotnet --version
docker exec github-build-runner rustc --version
docker exec github-build-runner go version
docker exec github-build-runner swift --version

# Check Docker availability
docker exec github-build-runner docker info

# View system info
docker exec github-build-runner free -h
docker exec github-build-runner df -h
```

## Next Steps

- Review [Configuration Reference](./configuration.md) for detailed configuration
- See [Security Best Practices](./security.md) for production deployments
- Check [Action Runner Documentation](./action-runner.md) for lighter-weight runners
- Review [Main README](./README.md) for deployment strategies
