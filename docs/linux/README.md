# Linux GitHub Actions Runners

This directory contains documentation for Linux-based self-hosted GitHub Actions runners and build environments.

## Overview

This project provides two types of Dockerized Linux runners for GitHub Actions:

1. **Action Runner** - Lightweight runner for executing CI/CD jobs
2. **Build Runner** - Comprehensive build environment with toolchains and language runtimes

## Quick Start

### Prerequisites

- Docker 20.10+ installed
- Docker Compose 2.10+ (optional, for deployment)
- GitHub Personal Access Token with `repo` scope
- Target GitHub repository (format: `owner/repo`)

### 1. Configure Environment

Create a `.env` file in the project root:

```bash
# GitHub Configuration
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPOSITORY=your-org/your-repo

# Optional: Custom runner names and labels
RUNNER_NAME=my-linux-runner
RUNNER_LABELS=linux,production,runner
```

Or set environment variables directly:

```bash
export GITHUB_TOKEN=ghp_your_token_here
export GITHUB_REPOSITORY=your-org/your-repo
```

### 2. Build and Deploy

#### Option A: Using Docker Compose (Recommended)

```bash
# Start all runners
docker-compose -f docker-compose/linux-runners.yml up -d

# View logs
docker-compose -f docker-compose/linux-runners.yml logs -f

# Stop all runners
docker-compose -f docker-compose/linux-runners.yml down
```

#### Option B: Using Docker Directly

```bash
# Build action runner
docker build \
  -f docker/linux/Dockerfile.action-runner \
  -t gh-runner:linux-action \
  .

# Run action runner
docker run -d \
  --name github-action-runner \
  -e GITHUB_TOKEN=$GITHUB_TOKEN \
  -e GITHUB_REPOSITORY=$GITHUB_REPOSITORY \
  -e RUNNER_NAME=linux-action-runner \
  -e RUNNER_LABELS=linux,action \
  gh-runner:linux-action
```

### 3. Verify Installation

Check if runners are connected to GitHub:

```bash
# View runner logs
docker-compose -f docker-compose/linux-runners.yml logs -f

# Check container status
docker-compose -f docker-compose/linux-runners.yml ps
```

The runners should appear in your GitHub repository's **Settings > Actions > Runners** page.

## Runner Types Comparison

| Feature | Action Runner | Build Runner |
|---------|---------------|--------------|
| **Image Size** | ~600MB | ~2.5GB |
| **Startup Time** | Fast (~30s) | Slower (~60s) |
| **Use Cases** | Running jobs, tests, deployments | Building applications, compiling code |
| **Build Tools** | Minimal (git, curl, Docker CLI) | Comprehensive (gcc, cmake, etc.) |
| **Languages** | Basic runtime | Multiple (Java, Node, Python, .NET, Rust, Go, PHP, Ruby) |
| **Docker Support** | Optional (Docker CLI only) | Required (Docker-in-Docker) |
| **Resource Usage** | Low (1 CPU, 2GB RAM) | High (2 CPUs, 4GB RAM) |

## Available Language Runtimes

### Build Runner Includes:

- **Python 3.x** - pip, venv, wheel
- **Node.js 20.x LTS** - npm, yarn
- **Java 17 LTS** - JDK, JRE
- **.NET 8.0** - SDK, ASP.NET Core
- **Rust** - rustc, cargo, rustfmt, clippy
- **Go 1.22** - go toolchain
- **PHP 8.2** - CLI, common extensions
- **Ruby 3.2** - Full stack, bundler
- **Swift 5.10** - For Apple platform development

### Build Tools:

- **GCC/Clang** - C/C++ toolchains
- **CMake** - Build system
- **Ninja** - Build system
- **Git LFS** - Large file support
- **AWS CLI v2** - AWS management
- **Azure CLI** - Azure management
- **Google Cloud SDK** - GCP management
- **Kubectl** - Kubernetes management

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub Personal Access Token | `ghp_xxxxxxxx` |
| `GITHUB_REPOSITORY` | Target repository or organization | `owner/repo` |

### Optional

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RUNNER_NAME` | Unique runner identifier | Hostname | `linux-runner-1` |
| `RUNNER_LABELS` | Comma-separated labels | `linux,runner` | `linux,prod,docker` |
| `RUNNER_GROUP` | Runner group (Enterprise) | `default` | `production` |
| `CLEANUP_EXISTING` | Remove existing configuration | `false` | `true` |
| `FORCE_RECONFIGURE` | Force reconfiguration | `false` | `true` |
| `INSTALL_DOCKER` | Install Docker CLI | `false` (action), `true` (build) | `true` |

## Advanced Configuration

### Using Docker Compose with Multiple Instances

Scale runners horizontally:

```bash
# Start 3 action runners
docker-compose -f docker-compose/linux-runners.yml up --scale gh-runner=3 -d

# Start specific services
docker-compose -f docker-compose/linux-runners.yml up gh-runner gh-build-runner -d
```

### Persistent Cache Volumes

Improve build performance with cache volumes:

```yaml
# Add to docker-compose/linux-runners.yml
volumes:
  npm-cache:
    driver: local
  maven-cache:
    driver: local
```

Then mount in service:

```yaml
volumes:
  - npm-cache:/home/runner/.npm
  - maven-cache:/home/runner/.m2
```

### Docker-in-Docker Support

**Warning**: Mounting `/var/run/docker.sock` grants the container access to the host Docker daemon, which is a security risk.

Only enable when necessary:

```bash
# In docker-compose/linux-runners.yml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

Or set environment variable:

```bash
export INSTALL_DOCKER=true
```

### Custom Runner Configuration

Create custom runner configuration by extending Dockerfiles:

```dockerfile
# Custom build runner with additional tools
FROM gh-runner:linux-build

# Install additional tools
RUN apt-get update && apt-get install -y \
    mysql-client \
    postgresql-client \
    redis-tools
```

## Security Best Practices

### 1. Token Management

- Use fine-grained personal access tokens with minimal permissions
- Store tokens in GitHub Secrets for CI/CD pipelines
- Rotate tokens regularly
- Never commit tokens to version control

### 2. Network Security

- Use private networks for runners
- Restrict runner access with GitHub runner groups
- Consider VPN or private VPC for sensitive deployments

### 3. Container Security

- Run containers with non-root user (already configured)
- Use read-only root filesystem where possible
- Limit container capabilities
- Regularly update base images and dependencies

### 4. Host Security

- Keep Docker Engine updated
- Use Docker Bench Security for audits
- Monitor container logs for suspicious activity
- Implement resource limits

## Troubleshooting

### Common Issues

#### 1. Authentication Failed

**Error**: `Failed to generate runner token`

**Solution**:
- Verify `GITHUB_TOKEN` has `repo` scope
- Check token is not expired
- Ensure repository format is correct: `owner/repo`

#### 2. Runner Not Appearing in GitHub

**Solution**:
- Check container logs: `docker-compose logs -f gh-runner`
- Verify runner configuration: `docker exec github-action-runner cat /actions-runner/.runner`
- Check GitHub repository settings for pending runners

#### 3. Build Failures in Build Runner

**Solution**:
- Verify Docker-in-Docker is enabled: `export INSTALL_DOCKER=true`
- Check resource limits: Increase CPU/memory in docker-compose
- Review build logs for specific errors

#### 4. Docker-in-Docker Issues

**Error**: `Cannot connect to Docker daemon`

**Solution**:
- Ensure `/var/run/docker.sock` is mounted
- Check user permissions (runner user in container)
- Verify Docker daemon is running on host

### Debug Mode

To debug runner issues, enable verbose logging:

```bash
docker run -e GITHUB_TOKEN=... -e GITHUB_REPOSITORY=... \
  -e RUNNER_NAME=debug-runner \
  -e CLEANUP_EXISTING=true \
  -e FORCE_RECONFIGURE=true \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-action
```

### Health Check

Runners include health checks. View status:

```bash
docker-compose -f docker-compose/linux-runners.yml ps
```

## Maintenance

### Updating Runners

```bash
# Pull latest changes
git pull origin main

# Rebuild images
docker-compose -f docker-compose/linux-runners.yml build --no-cache

# Recreate containers
docker-compose -f docker-compose/linux-runners.yml up -d --force-recreate
```

### Removing Old Runners

To clean up unused runners:

1. Stop and remove containers
2. Remove runner from GitHub (Settings > Actions > Runners)
3. Remove Docker images: `docker image rm gh-runner:linux-action`

### Regular Updates

```bash
# Update base image
docker pull ubuntu:22.04

# Rebuild with fresh packages
docker-compose -f docker-compose/linux-runners.yml build --no-cache
```

## Performance Optimization

### 1. Image Size Reduction

- Use multi-stage builds (already optimized)
- Clean apt cache (already in Dockerfiles)
- Remove unnecessary packages

### 2. Build Speed

- Use build cache for dependencies
- Consider pre-building custom images
- Use buildkit: `export DOCKER_BUILDKIT=1`

### 3. Runtime Performance

- Adjust resource limits based on workload
- Use faster storage (SSD) for cache volumes
- Monitor with `docker stats`

## Examples

### GitHub Actions Workflow

```yaml
# .github/workflows/build.yml
name: Build on Self-Hosted Runner

on: [push]

jobs:
  build:
    runs-on: self-hosted  # Targets your self-hosted runners
    steps:
      - uses: actions/checkout@v3

      - name: Build Application
        run: make build

      - name: Run Tests
        run: make test
```

### Using Build Labels

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, build]  # Targets build runners
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker Image
        run: docker build -t myapp:latest .

      - name: Push to Registry
        run: |
          echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
          docker push myapp:latest
```

## Reference

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Ubuntu LTS Release Notes](https://releases.ubuntu.com/22.04/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review container logs: `docker-compose logs -f`
3. Check GitHub Actions runner logs on the runner itself

## Contributing

To contribute improvements:
1. Fork the repository
2. Make your changes
3. Test with `docker-compose up`
4. Submit a pull request

---

**Next Steps**: See [Action Runner Documentation](./action-runner.md) or [Build Runner Documentation](./build-runner.md) for detailed usage guides.
