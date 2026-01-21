# Performance Optimization Guide

This guide covers best practices for optimizing the performance of your modular GitHub Actions runners.

## Overview

### Performance Metrics

| Metric | Monolithic | Modular | Improvement |
|--------|-----------|---------|-------------|
| **Build Time** | 5-8 minutes | 1-3 minutes | 60-80% faster |
| **Image Size** | 2.5GB | 300MB-2.5GB | 60-80% smaller |
| **Cache Efficiency** | ~20% | 90-95% | 4-5x better |
| **Storage Cost** | $0.25/month | $0.03-0.25/month | 60-80% savings |
| **Network Transfer** | 2.5GB | 300MB-2.5GB | 60-80% savings |

## Build Time Optimization

### 1. Use Docker Build Cache

**Enable BuildKit for better caching:**
```bash
export DOCKER_BUILDKIT=1

# Build with cache
docker build \
    --cache-from gh-runner:cpp-only \
    -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only .
```

**Build with cache in Docker Compose:**
```bash
# Build with cache
docker-compose -f docker-compose/build-all.yml build --no-cache

# Or use BuildKit
DOCKER_BUILDKIT=1 docker-compose -f docker-compose/build-all.yml build
```

### 2. Optimize Layer Order

**Good Layer Order** (Putting frequently changing layers last):
```dockerfile
# docker/linux/composite/Dockerfile.cpp-only
FROM gh-runner:linux-base

# Copy static files first (rarely change)
COPY --from=gh-runner:cpp-pack /usr/lib/ /usr/lib/
COPY --from=gh-runner:cpp-pack /usr/include/ /usr/include/

# Copy binaries last (may change more often)
COPY --from=gh-runner:cpp-pack /usr/bin/gcc /usr/bin/gcc
COPY --from=gh-runner:cpp-pack /usr/bin/g++ /usr/bin/g++
```

**Bad Layer Order** (Causes cache invalidation):
```dockerfile
# DON'T DO THIS - Changes frequently at top
COPY --from=gh-runner:cpp-pack /usr/bin/gcc /usr/bin/gcc
COPY --from=gh-runner:cpp-pack /usr/bin/g++ /usr/bin/g++

# Static files at bottom
COPY --from=gh-runner:cpp-pack /usr/lib/ /usr/lib/
COPY --from=gh-runner:cpp-pack /usr/include/ /usr/include/
```

### 3. Parallel Builds

**Build multiple images in parallel:**
```bash
# Using xargs for parallel builds
echo "cpp python nodejs go" | xargs -P 4 -I {} \
    docker build -f docker/linux/language-packs/{}/Dockerfile.{} \
        -t gh-runner:{}-pack .

# Or use make with parallel flag
make -j4 build-all
```

**Docker Compose parallel build:**
```bash
# Build all images in parallel
docker-compose -f docker-compose/build-all.yml build --parallel
```

### 4. Multi-Stage Build Optimization

**Optimized multi-stage approach:**
```dockerfile
# Build in stages, copy only what's needed
FROM gh-runner:linux-base AS builder
# ... build tools ...

FROM gh-runner:linux-base AS final
# Copy only binaries, not build artifacts
COPY --from=builder /usr/local/bin/ /usr/local/bin/
```

## Runtime Performance

### 1. Resource Allocation

**Analyze resource usage patterns:**
```bash
# Monitor container resources
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Sample output:
# Name            CPU %     Memory Usage
# cpp-runner      15.50%    1.2GiB / 4GiB
# python-runner   8.20%     0.8GiB / 4GiB
```

**Optimized resource limits:**
```yaml
# docker-compose/linux-cpp.yml
services:
  cpp-runner:
    deploy:
      resources:
        limits:
          cpus: '1.5'      # Based on actual usage
          memory: 2G       # 2-3x working set size
        reservations:
          cpus: '1.0'
          memory: 1G
```

**Resource Allocation Table:**

| Runner Type | CPU Limit | Memory Limit | Notes |
|-------------|-----------|--------------|-------|
| Base | 0.5 | 512M | Lightweight tasks |
| C++ Only | 1.5-2.0 | 2-4G | Compile-intensive |
| Python Only | 1.0-1.5 | 2-3G | ML workloads need more |
| Web Stack | 1.5-2.5 | 3-5G | Node.js + Go |
| Full Stack | 2.0-4.0 | 4-8G | All languages |

### 2. Cache Optimization

**Python Package Cache:**
```yaml
# docker-compose/linux-python.yml
volumes:
  - ./data/python-pip-cache:/home/runner/.cache/pip
  - ./data/python-venv-cache:/home/runner/.venv
```

**C++ Build Cache:**
```yaml
# docker-compose/linux-cpp.yml
volumes:
  - ./data/cpp-build-cache:/home/runner/.cache
  - ./data/cpp-conan-cache:/home/runner/.conan
```

**Node.js Package Cache:**
```yaml
# docker-compose/linux-web.yml
volumes:
  - ./data/node-npm-cache:/home/runner/.npm-global
  - ./data/node-yarn-cache:/home/runner/.yarn-cache
```

**Go Package Cache:**
```yaml
# docker-compose/linux-web.yml
volumes:
  - ./data/go-pkg-cache:/go/pkg/mod
```

### 3. Volume Mounting Strategy

**Cache Volumes (Recommended):**
```yaml
volumes:
  # Persistent cache (survives container restart)
  - ./data/cpp-cache:/home/runner/.cache

  # Ephemeral workspace (cleared between builds)
  - ./data/runner-work:/actions-runner/_work
```

**Host Mounts (Use with caution):**
```yaml
volumes:
  # Mount source code read-only for testing
  - /path/to/project:/workspace:ro

  # Mount Docker socket (required for container builds)
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

### 4. Network Optimization

**DNS Configuration:**
```yaml
# docker-compose/linux-cpp.yml
services:
  cpp-runner:
    dns:
      - 8.8.8.8
      - 8.8.4.4
    dns_search:
      - example.com
```

**Network Mode:**
```yaml
# Use host network for better performance (security tradeoff)
# services:
#   cpp-runner:
#     network_mode: "host"
#     # Remove networks section
```

## Storage Optimization

### 1. Image Size Reduction

**Optimize Dockerfile:**
```dockerfile
# Good: Combine RUN commands
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        package1 \
        package2 \
        package3 && \
    rm -rf /var/lib/apt/lists/*

# Bad: Multiple RUN commands (creates unnecessary layers)
RUN apt-get update
RUN apt-get install -y package1
RUN apt-get install -y package2
RUN rm -rf /var/lib/apt/lists/*
```

**Remove unnecessary files:**
```dockerfile
# Clean up after installations
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /var/log/*
```

### 2. Layer Size Analysis

**Check image layers:**
```bash
# View layer sizes
docker history gh-runner:cpp-only

# Example output:
# IMAGE          CREATED         SIZE
# <layer>        2 hours ago     250MB
# <layer>        2 hours ago     150MB
# <layer>        2 hours ago     300MB  # Base
```

**Optimize largest layers:**
1. Identify biggest layers
2. Move to external cache if possible
3. Use multi-stage builds
4. Remove unnecessary files

### 3. Storage Cleanup

**Regular cleanup script:**
```bash
#!/bin/bash
# cleanup-runners.sh

# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -f

# Remove unused volumes
docker volume prune -f

# Clean build cache
docker builder prune -f

# Remove old runner data (older than 7 days)
find ./data -type d -mtime +7 -exec rm -rf {} +
```

**Automated cleanup (cron job):**
```bash
# Add to crontab (runs daily at 2 AM)
0 2 * * * /path/to/cleanup-runners.sh
```

## Workflow Optimization

### 1. Optimize GitHub Actions Workflows

**Use appropriate runner labels:**
```yaml
# Before: Using full-runner for everything
jobs:
  lint:
    runs-on: [self-hosted, linux, full]  # Too heavy
    steps:
      - run: eslint .

# After: Use appropriate runner
jobs:
  lint:
    runs-on: [self-hosted, linux, base]  # Lightweight
    steps:
      - run: eslint .
```

**Job-level resource allocation:**
```yaml
jobs:
  build-heavy:
    runs-on: [self-hosted, linux, cpp]
    # This job needs more resources
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: cmake --build build --parallel 4  # Use parallel builds

  test-light:
    runs-on: [self-hosted, linux, cpp]
    # This job needs fewer resources
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: ctest --output-on-failure
```

### 2. Parallel Job Execution

**Maximize parallelism:**
```yaml
jobs:
  lint:
    runs-on: [self-hosted, linux, base]
    steps:
      - run: eslint .
      - run: prettier --check .
      - run: stylelint .

  build:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - run: cmake --build build --parallel 4

  test:
    needs: [build]  # Run after build
    runs-on: [self-hosted, linux, cpp]
    steps:
      - run: ctest --parallel 4
```

### 3. Cache GitHub Actions

**Use actions/cache:**
```yaml
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: ~/.cache
    key: ${{ runner.os }}-cache-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-cache-
```

**Language-specific caches:**
```yaml
# Python
- name: Cache pip
  uses: actions/cache@v3
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}

# C++
- name: Cache ccache
  uses: actions/cache@v3
  with:
    path: ~/.cache/ccache
    key: ${{ runner.os }}-ccache-${{ hashFiles('**/CMakeLists.txt') }}
```

## Performance Monitoring

### 1. Track Build Times

**GitHub Actions API:**
```bash
# Get workflow run times
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs" \
  | jq '.workflow_runs[] | {name: .name, duration: .run_started_at, conclusion: .conclusion}'
```

**Python script to analyze:**
```python
import requests
import pandas as pd
from datetime import datetime

def analyze_workflow_times(owner, repo, token):
    url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs"
    headers = {"Authorization": f"token {token}"}

    response = requests.get(url, headers=headers)
    runs = response.json()['workflow_runs']

    data = []
    for run in runs[:50]:  # Last 50 runs
        started = datetime.fromisoformat(run['run_started_at'].replace('Z', '+00:00'))
        if run['updated_at']:
            updated = datetime.fromisoformat(run['updated_at'].replace('Z', '+00:00'))
            duration = (updated - started).total_seconds() / 60
        else:
            duration = None

        data.append({
            'workflow': run['name'],
            'duration_min': duration,
            'conclusion': run['conclusion']
        })

    df = pd.DataFrame(data)
    return df.groupby('workflow').agg({
        'duration_min': ['mean', 'std', 'min', 'max'],
        'conclusion': 'count'
    })
```

### 2. Monitor Resource Usage

**Docker stats logging:**
```bash
# Log resource usage to file
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
  --no-stream > resource-usage.log

# Monitor continuously
watch -n 30 'docker stats --no-stream'
```

**Prometheus + Grafana (Advanced):**
```yaml
# docker-compose.monitoring.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

### 3. Build Performance Dashboard

**Sample dashboard metrics:**
```python
# dashboard.py
import matplotlib.pyplot as plt
import pandas as pd

def create_performance_dashboard(data):
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))

    # Build time comparison
    axes[0, 0].bar(['Monolith', 'Modular'], [7.5, 2.5], color=['red', 'green'])
    axes[0, 0].set_title('Build Time (minutes)')
    axes[0, 0].set_ylabel('Minutes')

    # Image size comparison
    axes[0, 1].bar(['Monolith', 'Modular'], [2500, 600], color=['red', 'green'])
    axes[0, 1].set_title('Image Size (MB)')
    axes[0, 1].set_ylabel('MB')

    # Cache efficiency
    axes[1, 0].bar(['Monolith', 'Modular'], [20, 95], color=['red', 'green'])
    axes[1, 0].set_title('Cache Hit Rate (%)')
    axes[1, 0].set_ylabel('Percentage')

    # Storage cost
    axes[1, 1].bar(['Monolith', 'Modular'], [0.25, 0.06], color=['red', 'green'])
    axes[1, 1].set_title('Monthly Storage Cost ($)')
    axes[1, 1].set_ylabel('Dollars')

    plt.tight_layout()
    plt.savefig('performance-dashboard.png')
    print("Dashboard saved as performance-dashboard.png")
```

## Optimization Techniques by Language

### C++ Optimization

**Use ccache for faster rebuilds:**
```dockerfile
# Add to C++ Dockerfile
RUN apt-get install -y ccache
ENV CC="ccache gcc"
ENV CXX="ccache g++"
```

**Parallel builds in workflow:**
```yaml
- name: Build with CMake
  run: |
    cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
    cmake --build build --parallel $(nproc)
```

### Python Optimization

**Use pip cache:**
```yaml
# docker-compose/linux-python.yml
volumes:
  - ./data/python-pip-cache:/home/runner/.cache/pip

# Workflow
- name: Install dependencies
  run: pip install --cache-dir /home/runner/.cache/pip -r requirements.txt
```

**Use virtual environments:**
```yaml
- name: Create virtual environment
  run: python3 -m venv /home/runner/.venv
- name: Activate and install
  run: |
    source /home/runner/.venv/bin/activate
    pip install -r requirements.txt
```

### Node.js Optimization

**Use npm ci for reproducible builds:**
```yaml
- name: Install dependencies
  run: npm ci --prefer-offline --cache /home/runner/.npm-global
```

**Use pnpm for faster installs:**
```yaml
- name: Install pnpm
  run: npm install -g pnpm
- name: Install dependencies
  run: pnpm install --frozen-lockfile
```

### Go Optimization

**Use Go build cache:**
```yaml
- name: Build with cache
  run: |
    export GOCACHE=/go/pkg/mod/cache
    go build -mod=readonly -o app main.go
```

**Parallel tests:**
```yaml
- name: Run tests
  run: go test -parallel $(nproc) ./...
```

## Advanced Optimization

### 1. Docker BuildKit Features

**Enable BuildKit features:**
```bash
export DOCKER_BUILDKIT=1

# Use cache mounts (Dockerfile syntax 1.4+)
# In Dockerfile:
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y package
```

**Build with secrets (not in image):**
```bash
# Build with secret
docker build \
    --secret id=github_token,src=/path/to/token \
    -f docker/linux/base/Dockerfile.base \
    -t gh-runner:linux-base .
```

### 2. Multi-Architecture Builds

**Build for multiple architectures:**
```bash
# Create buildx builder
docker buildx create --use

# Build for x86_64 and ARM64
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f docker/linux/base/Dockerfile.base \
    -t gh-runner:linux-base \
    --push
```

### 3. Registry Caching

**Use registry as cache:**
```bash
# Push base image to registry
docker push ghcr.io/org/runner-base:latest

# Pull and use as cache
docker build \
    --cache-from ghcr.io/org/runner-base:latest \
    -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only .
```

## Performance Comparison Tool

**Create comparison script:**
```bash
#!/bin/bash
# compare-performance.sh

echo "=== Performance Comparison ==="
echo ""

# Measure build times
echo "1. Build Time Comparison"
echo "------------------------"
echo "Monolith (full-stack):"
time docker build -f docker/linux/composite/Dockerfile.full-stack \
    -t gh-runner:full-stack-test . 2>&1 | tail -1

echo ""
echo "Modular (cpp-only):"
time docker build -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only-test . 2>&1 | tail -1

echo ""
echo "2. Image Size Comparison"
echo "------------------------"
echo "Monolith:"
docker images gh-runner:full-stack-test --format "{{.Size}}"

echo ""
echo "Modular:"
docker images gh-runner:cpp-only-test --format "{{.Size}}"

echo ""
echo "3. Cache Hit Rate"
echo "----------------"
echo "Build twice and compare times..."
```

## Common Performance Issues & Solutions

### Issue 1: Slow First Build
**Problem**: No cache available
**Solution**:
- Build base image first
- Push to registry for team use
- Use BuildKit with cache mounts

### Issue 2: Cache Misses
**Problem**: Frequent cache invalidation
**Solution**:
- Review Dockerfile layer order
- Use `--no-cache` only when necessary
- Use `--cache-from` for registry caching

### Issue 3: High Memory Usage
**Problem**: Container crashes with OOM
**Solution**:
- Increase memory limits
- Use swap space (not recommended for production)
- Optimize build process (reduce parallelism)

### Issue 4: Slow Network
**Problem**: Slow package downloads
**Solution**:
- Use mirrors (e.g., npm mirror)
- Cache dependencies in volumes
- Use local registry

### Issue 5: Slow I/O
**Problem**: Disk-bound operations
**Solution**:
- Use SSD for Docker storage
- Reduce volume mounts
- Use tmpfs for temp files

## Monitoring & Alerts

### 1. Set Up Alerts

**Create alert rules:**
```yaml
# prometheus/alerts.yml
groups:
  - name: docker-alerts
    rules:
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{container="cpp-runner"} > 2e9  # 2GB
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
```

### 2. Log Analysis

**Analyze build logs:**
```bash
# Find slow steps
docker logs cpp-runner 2>&1 | grep -E "time:|duration:|took:"

# Count errors
docker logs cpp-runner 2>&1 | grep -c "ERROR"
```

### 3. Performance Report

**Generate weekly report:**
```bash
#!/bin/bash
# weekly-performance-report.sh

echo "=== Weekly Performance Report ==="
echo "Generated: $(date)"
echo ""

# Build times
echo "Average Build Times:"
echo "C++ Runner: $(docker logs cpp-runner 2>&1 | grep -E 'Build time:' | tail -1)"
echo "Python Runner: $(docker logs python-runner 2>&1 | grep -E 'Build time:' | tail -1)"

# Image sizes
echo ""
echo "Image Sizes:"
docker images | grep gh-runner | awk '{print $1":"$2"\t"$7}'

# Resource usage
echo ""
echo "Average Resource Usage (last 7 days):"
# Parse docker stats logs if available
```

## Cost Optimization

### 1. Right-Size Images

**Choose minimal runner:**
```bash
# Instead of full-runner for everything
# Use:
# - base-runner for linting
# - cpp-only for C++ builds
# - python-only for Python tests
```

### 2. Auto-Scaling

**Scale down when idle:**
```bash
# Check if runner is active
if ! docker logs cpp-runner 2>&1 | grep -q "Job started"; then
    # Scale down
    docker-compose -f docker-compose/linux-cpp.yml down
fi
```

### 3. Spot Instances (Cloud)

**Use spot instances for non-critical:**
```bash
# AWS EC2 Spot instance
# 70-90% cost savings for fault-tolerant workloads
```

### 4. Storage Optimization

**Clean up old images:**
```bash
# Keep only last 3 versions
docker images gh-runner:cpp-only --format "{{.Tag}}" | \
  sort -V | \
  head -n -3 | \
  xargs -I {} docker rmi gh-runner:cpp-only:{}
```

## Performance Checklist

### Build Performance
- [ ] Using BuildKit (DOCKER_BUILDKIT=1)
- [ ] Layer order optimized (frequently changing last)
- [ ] Parallel builds enabled
- [ ] Registry cache configured
- [ ] Multi-stage builds used
- [ ] Unnecessary files removed

### Runtime Performance
- [ ] Appropriate resource limits set
- [ ] Cache volumes configured
- [ ] Network optimized
- [ ] Monitoring enabled
- [ ] Auto-scaling configured (if needed)

### Workflow Performance
- [ ] Using appropriate runner labels
- [ ] Job parallelism maximized
- [ ] GitHub Actions cache configured
- [ ] Build tools use parallel options
- [ ] Dependencies cached

### Cost Optimization
- [ ] Right-sized images selected
- [ ] Storage cleanup automated
- [ ] Spot instances for non-critical
- [ ] Resource usage monitored
- [ ] Regular cost review

## Success Metrics

### Target Performance Goals

| Metric | Baseline | Target | Achieved |
|--------|----------|--------|----------|
| **Build Time** | 8 min | <3 min | |
| **Image Size** | 2.5GB | <600MB | |
| **Cache Hit Rate** | 20% | >90% | |
| **Storage Cost** | $0.25/mo | <$0.10/mo | |
| **Success Rate** | 95% | >99% | |

### Monthly Review

**Review these metrics monthly:**
1. Average build times per workflow
2. Cache hit rates
3. Storage usage and costs
4. Resource utilization
5. Success/failure rates

## Advanced Techniques

### 1. Build Profile Analysis

**Use Docker build profiling:**
```bash
# Enable build output
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

# Build with timing
time docker build \
    -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only \
    --progress=plain . 2>&1 | tee build.log
```

### 2. Layer Analysis

**Analyze layer sizes:**
```bash
# Install dive
brew install dive  # macOS
# or
apt-get install dive  # Ubuntu

# Analyze image
dive gh-runner:cpp-only
```

### 3. Build Time Optimization

**Use buildkit secrets and mounts:**
```dockerfile
# Dockerfile with secrets
FROM gh-runner:linux-base

# Mount cache for apt
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y package

# Use secret for token
RUN --mount=type=secret,id=github_token \
    curl -H "Authorization: token $(cat /run/secrets/github_token)" ...
```

### 4. Registry Optimization

**Use registry for cache:**
```bash
# Push base images
docker push ghcr.io/org/runner-base:latest
docker push ghcr.io/org/runner-cpp-pack:latest

# Use in builds
docker build \
    --cache-from ghcr.io/org/runner-base:latest \
    --cache-from ghcr.io/org/runner-cpp-pack:latest \
    -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only .
```

## Performance Tools

### 1. Docker Analysis Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| `dive` | Layer analysis | `dive gh-runner:cpp-only` |
| `docker-slim` | Minimize images | `docker-slim build gh-runner:cpp-only` |
| `ctop` | Container metrics | `ctop` |
| `lazydocker` | Docker UI | `lazydocker` |

### 2. Monitoring Tools

| Tool | Purpose | Setup |
|------|---------|-------|
| **Prometheus** | Metrics collection | `docker-compose -f monitoring.yml up` |
| **Grafana** | Visualization | Web UI at `localhost:3000` |
| **cAdvisor** | Container metrics | Auto-deploy with Prometheus |
| **Node Exporter** | Host metrics | Monitor host resources |

### 3. Build Tools

| Tool | Purpose | Use Case |
|------|---------|----------|
| **BuildKit** | Advanced builds | Cache mounts, secrets |
| **Buildx** | Multi-arch builds | ARM64 support |
| **Skopeo** | Image inspection | Check layers, tags |
| **Oras** | Artifact push/pull | Registry management |

## Best Practices Summary

### 1. Always Use Cache
```bash
# Enable buildkit
export DOCKER_BUILDKIT=1

# Use cache mounts in Dockerfile
RUN --mount=type=cache,target=/var/cache/apt ...
```

### 2. Optimize Layer Order
```dockerfile
# Static files first, dynamic files last
COPY --from=builder /usr/lib/ /usr/lib/
COPY --from=builder /usr/bin/gcc /usr/bin/gcc
```

### 3. Choose Right Runner
```bash
# Don't use full-runner for simple tasks
# Use base-runner for linting
# Use cpp-only for C++ builds
```

### 4. Monitor Resources
```bash
# Regular monitoring
docker stats --no-stream

# Set alerts for high usage
```

### 5. Clean Up Regularly
```bash
# Weekly cleanup
docker image prune -f
docker volume prune -f
```

## Conclusion

### Key Takeaways

1. **Modular approach saves 60-80%** on build time and storage
2. **Cache optimization** is critical for performance
3. **Right-size runners** for each task
4. **Monitor and adjust** based on actual usage
5. **Regular maintenance** prevents performance degradation

### Expected Improvements

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| **C++ Build** | 8 min | 2 min | 75% faster |
| **Python Test** | 5 min | 1.5 min | 70% faster |
| **Web Build** | 10 min | 3 min | 70% faster |
| **Storage** | 2.5GB | 600MB | 76% smaller |

### Next Steps

1. **Implement optimizations** from this guide
2. **Monitor performance** over time
3. **Iterate and improve** based on data
4. **Share learnings** with team
5. **Document changes** for future reference

---

**Optimized runners = Faster CI/CD = Happier developers!** 🚀
