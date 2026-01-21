# Composite Images Documentation

Composite images are pre-built Docker images that combine the base GitHub Actions runner with specific language packs. These are production-ready images designed for specific use cases, providing the right balance of size and functionality.

## Overview

### What are Composite Images?

Composite images are built by:
1. Starting with the **base image** (300MB)
2. Adding specific **language packs** (50-300MB each)
3. Creating optimized, production-ready images

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Optimized Size** | Only includes what you need |
| **Fast Deployment** | Pre-built, ready to use |
| **Easy Maintenance** | Simple, focused images |
| **Better Caching** | Layers can be reused |
| **Security** | Smaller attack surface |

## Available Composite Images

### 1. cpp-only
**Dockerfile**: `Dockerfile.cpp-only`
**Size**: ~550MB
**Use Case**: C/C++ development, systems programming, embedded systems

**Includes:**
- GCC 11.x (C/C++ compiler)
- Clang 14.x (alternative compiler)
- CMake 3.x (build system)
- Make, GDB, Valgrind
- Common libraries (OpenSSL, Boost, zlib)

**Best For:**
- Linux kernel development
- Embedded systems
- High-performance applications
- Systems programming
- Game development

**Environment Variables:**
- `BUILD_TOOLCHAIN=c++`
- `CPP_ENV=enabled`
- `CC=/usr/bin/gcc`
- `CXX=/usr/bin/g++`

**Labels:**
```bash
org.opencontainers.image.description="C++ only GitHub Actions runner"
org.opencontainers.image.tags="c++,cpp,gcc,clang,cmake,make"
```

### 2. python-only
**Dockerfile**: `Dockerfile.python-only`
**Size**: ~450MB
**Use Case**: Python development, ML/AI, data science

**Includes:**
- Python 3.x (system package)
- pip (latest)
- venv (virtual environments)
- setuptools, wheel

**Best For:**
- Django/Flask web development
- Machine learning (TensorFlow, PyTorch)
- Data science (pandas, NumPy)
- Automation scripts
- API development

**Environment Variables:**
- `BUILD_STACK=python`
- `PYTHONUNBUFFERED=1`
- `PYTHONDONTWRITEBYTECODE=1`

**Labels:**
```bash
org.opencontainers.image.description="Python only GitHub Actions runner"
org.opencontainers.image.tags="python,python3,django,flask,ml,ai,data-science"
```

### 3. web-stack
**Dockerfile**: `Dockerfile.web`
**Size**: ~580MB
**Use Case**: Full-stack web development (Node.js + Go)

**Includes:**
- Node.js 20 LTS
- npm, yarn, pnpm
- Go 1.22
- nginx (web server)

**Best For:**
- Node.js applications (Express, NestJS)
- React/Vue/Angular applications
- Go backend services
- Microservices
- Web APIs
- SSR applications

**Environment Variables:**
- `BUILD_STACK=nodego`
- `NODE_ENV=production`
- `GOROOT=/usr/local/go`
- `GOPATH=/go`

**Labels:**
```bash
org.opencontainers.image.description="Node.js + Go web development GitHub Actions runner"
org.opencontainers.image.tags="web,nodejs,go,frontend,backend,nginx"
```

### 4. full-stack
**Dockerfile**: `Dockerfile.full-stack`
**Size**: ~2.5GB
**Use Case**: Legacy support, migration from monolith

**Includes:**
- Python 3.x + pip
- C/C++ toolchain (GCC, Clang, CMake)
- Node.js 20 LTS + npm/yarn
- Go 1.22
- All common development tools

**Best For:**
- Migration from existing monolith
- When multiple languages needed
- Legacy project support
- Development environments
- Maximum compatibility

**Environment Variables:**
- `BUILD_STACK=full`
- All language-specific variables

**Labels:**
```bash
org.opencontainers.image.description="Full stack GitHub Actions runner (Python + C++ + Node.js + Go)"
org.opencontainers.image.tags="full,full-stack,monolith,legacy,python,cpp,nodejs,go"
```

## Build Commands

### Prerequisites

**First, build the base image:**
```bash
docker build -f docker/linux/base/Dockerfile.base \
    -t gh-runner:linux-base .
```

**Then, build language packs:**
```bash
docker build -f docker/linux/language-packs/cpp/Dockerfile.cpp \
    -t gh-runner:cpp-pack .

docker build -f docker/linux/language-packs/python/Dockerfile.python \
    -t gh-runner:python-pack .

docker build -f docker/linux/language-packs/nodejs/Dockerfile.nodejs \
    -t gh-runner:nodejs-pack .

docker build -f docker/linux/language-packs/go/Dockerfile.go \
    -t gh-runner:go-pack .
```

### Build Composite Images

**C++ Only:**
```bash
docker build -f docker/linux/composite/Dockerfile.cpp-only \
    -t gh-runner:cpp-only .
```

**Python Only:**
```bash
docker build -f docker/linux/composite/Dockerfile.python-only \
    -t gh-runner:python-only .
```

**Web Stack (Node.js + Go):**
```bash
docker build -f docker/linux/composite/Dockerfile.web \
    -t gh-runner:web-stack .
```

**Full Stack (Legacy):**
```bash
docker build -f docker/linux/composite/Dockerfile.full-stack \
    -t gh-runner:full-stack .
```

### Build All at Once

**Using Docker Compose:**
```bash
# Build all images
docker-compose -f docker-compose/build-all.yml build
```

**Manual Script:**
```bash
#!/bin/bash
set -e

echo "Building base image..."
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .

echo "Building language packs..."
for lang in cpp python nodejs go; do
    echo "Building $lang pack..."
    docker build -f docker/linux/language-packs/$lang/Dockerfile.$lang \
        -t gh-runner:$lang-pack .
done

echo "Building composite images..."
for composite in cpp-only python-only web full-stack; do
    echo "Building $composite image..."
    docker build -f docker/linux/composite/Dockerfile.$composite \
        -t gh-runner:$composite .
done

echo "All images built successfully!"
```

## Usage Examples

### 1. C++ Development Runner

**Quick Start:**
```bash
# Pull or build
docker run --rm gh-runner:cpp-only gcc --version

# Start runner with Docker Compose
docker-compose -f docker-compose/linux-cpp.yml up -d
```

**Docker Run:**
```bash
docker run -d \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=owner/repo \
    -e RUNNER_NAME=cpp-runner \
    -e RUNNER_LABELS=linux,cpp,build \
    --name cpp-runner \
    gh-runner:cpp-only
```

### 2. Python Development Runner

**Quick Start:**
```bash
# Pull or build
docker run --rm gh-runner:python-only python3 --version

# Start runner
docker-compose -f docker-compose/linux-python.yml up -d
```

**Docker Run:**
```bash
docker run -d \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=owner/repo \
    -e RUNNER_NAME=python-runner \
    -e RUNNER_LABELS=linux,python,ml \
    --name python-runner \
    gh-runner:python-only
```

### 3. Web Development Runner

**Quick Start:**
```bash
# Pull or build
docker run --rm gh-runner:web-stack node --version
docker run --rm gh-runner:web-stack go version

# Start runner
docker-compose -f docker-compose/linux-web.yml up -d
```

**Docker Run:**
```bash
docker run -d \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=owner/repo \
    -e RUNNER_NAME=web-runner \
    -e RUNNER_LABELS=linux,node,go,web \
    --name web-runner \
    gh-runner:web-stack
```

### 4. Full Stack (Legacy) Runner

**Quick Start:**
```bash
# Pull or build
docker run --rm gh-runner:full-stack python3 --version
docker run --rm gh-runner:full-stack gcc --version
docker run --rm gh-runner:full-stack node --version
docker run --rm gh-runner:full-stack go version

# Start runner
docker-compose -f docker-compose/linux-full.yml up -d
```

**Docker Run:**
```bash
docker run -d \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=owner/repo \
    -e RUNNER_NAME=full-runner \
    -e RUNNER_LABELS=linux,full,all \
    --name full-runner \
    gh-runner:full-stack
```

## Docker Compose Integration

### C++ Runner Configuration

```yaml
# docker-compose/linux-cpp.yml
version: '3.8'
services:
  cpp-runner:
    build:
      context: .
      dockerfile: docker/linux/composite/Dockerfile.cpp-only
    image: gh-runner:cpp-only
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=cpp-runner
      - RUNNER_LABELS=linux,cpp,build
      - RUNNER_WORKDIR=_work
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/cpp-runner:/actions-runner
    networks:
      - github-runners
    mem_limit: 2g
    cpus: '1.0'
    restart: unless-stopped
```

### Python Runner Configuration

```yaml
# docker-compose/linux-python.yml
version: '3.8'
services:
  python-runner:
    build:
      context: .
      dockerfile: docker/linux/composite/Dockerfile.python-only
    image: gh-runner:python-only
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=python-runner
      - RUNNER_LABELS=linux,python,ml,ai
      - RUNNER_WORKDIR=_work
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/python-runner:/actions-runner
      - ./data/venv-cache:/home/runner/.local/lib/python3.10/site-packages
    networks:
      - github-runners
    mem_limit: 3g
    cpus: '2.0'
    restart: unless-stopped
```

### Web Runner Configuration

```yaml
# docker-compose/linux-web.yml
version: '3.8'
services:
  web-runner:
    build:
      context: .
      dockerfile: docker/linux/composite/Dockerfile.web
    image: gh-runner:web-stack
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=web-runner
      - RUNNER_LABELS=linux,node,go,web,frontend
      - RUNNER_WORKDIR=_work
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/web-runner:/actions-runner
      - ./data/node-cache:/home/runner/.npm-global
      - ./data/go-cache:/go/pkg/mod
    networks:
      - github-runners
    mem_limit: 2g
    cpus: '1.5'
    restart: unless-stopped
```

### Full Stack Configuration

```yaml
# docker-compose/linux-full.yml
version: '3.8'
services:
  full-runner:
    build:
      context: .
      dockerfile: docker/linux/composite/Dockerfile.full-stack
    image: gh-runner:full-stack
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=full-runner
      - RUNNER_LABELS=linux,full,all,legacy
      - RUNNER_WORKDIR=_work
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/full-runner:/actions-runner
      - ./data/venv-cache:/home/runner/.local/lib/python3.10/site-packages
      - ./data/node-cache:/home/runner/.npm-global
      - ./data/go-cache:/go/pkg/mod
    networks:
      - github-runners
    mem_limit: 4g
    cpus: '2.0'
    restart: unless-stopped
```

## Image Size Comparison

### Build Time Comparison

| Image | Size | Build Time | Layers | Cache Efficiency |
|-------|------|------------|--------|------------------|
| **Base Only** | 300MB | ~2 min | 3 | 90% |
| **cpp-only** | 550MB | ~3 min | 5 | 95% |
| **python-only** | 450MB | ~2.5 min | 5 | 95% |
| **web-stack** | 580MB | ~3.5 min | 7 | 95% |
| **full-stack** | 2.5GB | ~8 min | 15+ | 20% |

### Storage Comparison

| Scenario | Size | Cost Savings |
|----------|------|--------------|
| **cpp-only** vs full-stack | 550MB vs 2.5GB | 78% |
| **python-only** vs full-stack | 450MB vs 2.5GB | 82% |
| **web-stack** vs full-stack | 580MB vs 2.5GB | 77% |

### Network Transfer

| Image | Size | Download Cost |
|-------|------|---------------|
| cpp-only | 550MB | Low |
| python-only | 450MB | Low |
| web-stack | 580MB | Low |
| full-stack | 2.5GB | High |

## Testing Composite Images

### C++ Runner Tests
```bash
# Test compiler
docker run --rm gh-runner:cpp-only gcc --version

# Test compilation
docker run --rm gh-runner:cpp-only sh -c 'echo "int main() { return 0; }" > test.cpp && g++ test.cpp -o test && ./test'

# Test CMake
docker run --rm gh-runner:cpp-only cmake --version

# Test Node.js (should fail - not installed)
docker run --rm gh-runner:cpp-only node --version 2>&1 || echo "Node.js not installed (expected)"
```

### Python Runner Tests
```bash
# Test Python
docker run --rm gh-runner:python-only python3 --version

# Test pip
docker run --rm gh-runner:python-only pip --version

# Test virtual environment
docker run --rm gh-runner:python-only python3 -m venv /tmp/test-venv

# Test GCC (should fail - not installed)
docker run --rm gh-runner:python-only gcc --version 2>&1 || echo "GCC not installed (expected)"
```

### Web Runner Tests
```bash
# Test Node.js
docker run --rm gh-runner:web-stack node --version

# Test Go
docker run --rm gh-runner:web-stack go version

# Test npm
docker run --rm gh-runner:web-stack npm --version

# Test GCC (should fail - not installed)
docker run --rm gh-runner:web-stack gcc --version 2>&1 || echo "GCC not installed (expected)"
```

### Full Stack Tests
```bash
# Test all languages
docker run --rm gh-runner:full-stack python3 --version
docker run --rm gh-runner:full-stack gcc --version
docker run --rm gh-runner:full-stack node --version
docker run --rm gh-runner:full-stack go version

# Test cross-language build
docker run --rm gh-runner:full-stack sh -c 'python3 -c "print(\"Python works\")" && gcc --version | head -1 && node --version && go version'
```

## Version Tagging

### Recommended Tagging Strategy
```bash
# Semantic versioning
gh-runner:cpp-only:1.0.0
gh-runner:cpp-only:latest

# Date-based
gh-runner:cpp-only:2026.01.21
gh-runner:cpp-only:2026.01

# Feature-based
gh-runner:cpp-only:gcc11
gh-runner:cpp-only:gcc12

# Environment-based
gh-runner:cpp-only:prod
gh-runner:cpp-only:dev
```

## Custom Composite Images

### Create Your Own Composite

**Step 1: Choose Base**
```dockerfile
FROM gh-runner:linux-base
```

**Step 2: Add Language Packs**
```dockerfile
# Python + Go
COPY --from=gh-runner:python-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:go-pack /usr/local/go /usr/local/go
```

**Step 3: Add Custom Tools**
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*
```

**Step 4: Set Environment**
```dockerfile
ENV BUILD_STACK=custom \
    PYTHON_ENV=enabled \
    GO_ENV=enabled
```

**Step 5: Build**
```bash
docker build -f docker/linux/composite/Dockerfile.custom \
    -t gh-runner:custom-stack .
```

## Migration from Full Stack

### Analysis Phase
```bash
# Analyze which languages are actually used
# Check GitHub Actions workflows
grep -r "runs-on:" .github/workflows/ | sort | uniq
```

### Gradual Migration

**Phase 1: Deploy Modular**
```bash
# Deploy new composite images alongside full-stack
docker-compose -f docker-compose/linux-cpp.yml up -d
docker-compose -f docker-compose/linux-python.yml up -d
```

**Phase 2: Update Workflows**
```yaml
# Before (using full-stack)
jobs:
  build:
    runs-on: [self-hosted, linux, full]

# After (using cpp-only)
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]
```

**Phase 3: Monitor & Optimize**
- Track build times
- Monitor resource usage
- Adjust runner labels
- Optimize cache strategies

**Phase 4: Decommission**
- Remove full-stack deployments
- Update documentation
- Clean up old images

## Maintenance

### Updating Images

**Security Updates:**
```bash
# Rebuild base
docker build -f docker/linux/base/Dockerfile.base --no-cache -t gh-runner:linux-base .

# Rebuild composite
docker build -f docker/linux/composite/Dockerfile.cpp-only --no-cache -t gh-runner:cpp-only .
```

**Version Updates:**
```bash
# Update RUNNER_VERSION in base
# Update language versions in packs
# Rebuild affected composites
```

### Cleanup

**Remove Old Images:**
```bash
# Remove dangling images
docker image prune -f

# Remove unused tags
docker rmi gh-runner:cpp-only:1.0.0
```

**Clean Build Cache:**
```bash
docker builder prune -f
```

## Performance Optimization

### Build Time Optimization

1. **Use Build Cache**: Always tag base image first
2. **Parallel Builds**: Build language packs in parallel
3. **Layer Order**: Put frequently changing layers last
4. **Multi-stage**: Use multi-stage for final composites

### Runtime Optimization

1. **Resource Limits**: Set memory and CPU limits
2. **Volume Mounts**: Use volumes for caching
3. **Network**: Use appropriate network settings
4. **Restart Policy**: Use `unless-stopped` for production

### Cost Optimization

1. **Right-size images**: Use only needed language packs
2. **Auto-scaling**: Scale down when idle
3. **Spot instances**: Use spot for non-critical workloads
4. **Monitoring**: Track usage patterns

## Troubleshooting

### Common Issues

**1. "Copy failed: source not found"**
```bash
# Ensure language packs are built first
docker build -f docker/linux/language-packs/cpp/Dockerfile.cpp -t gh-runner:cpp-pack .
```

**2. "Command not found: node"**
```bash
# Verify image has the expected tools
docker run --rm gh-runner:web-stack which node
```

**3. "Out of memory"**
```bash
# Increase memory limit
docker run -m 4g ...
```

**4. "Build time too long"**
```bash
# Check layer cache
docker history gh-runner:cpp-only
```

### Performance Debugging

```bash
# Check image size
docker images | grep gh-runner

# Check build time
time docker build -f docker/linux/composite/Dockerfile.cpp-only -t gh-runner:cpp-only .

# Check container resource usage
docker stats <container>
```

## Best Practices

### 1. Tag Images Properly
```bash
# Use semantic versioning
docker tag gh-runner:cpp-only gh-runner:cpp-only:1.0.0
docker tag gh-runner:cpp-only gh-runner:cpp-only:latest
```

### 2. Use .dockerignore
Create `.dockerignore` in each directory:
```
*.md
*.txt
.git
.gitignore
README.md
node_modules/
__pycache__/
```

### 3. Document Dependencies
For each composite, document:
- Required base image version
- Language pack versions
- Build dependencies
- Runtime dependencies

### 4. Test Before Production
```bash
# Run comprehensive tests
./test-images.sh
```

### 5. Monitor & Alert
- Set up monitoring for runner health
- Alert on high resource usage
- Track build success rates

## Related Files

- **Base Image**: `docker/linux/base/Dockerfile.base`
- **Language Packs**: `docker/linux/language-packs/`
- **Docker Compose**: `docker-compose/linux-*.yml`
- **Documentation**: `docs/linux-modular/`

## Next Steps

1. **Review available composites** and choose what you need
2. **Build images** for your requirements
3. **Test thoroughly** before production
4. **Deploy with Docker Compose**
5. **Monitor performance** and optimize
6. **Migrate workflows** gradually from full-stack

## Support & Contributions

For issues or improvements:
- Check Dockerfile syntax
- Verify language pack versions
- Follow Docker best practices
- Test in development first
- Document changes
