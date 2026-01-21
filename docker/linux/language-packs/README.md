# Language Packs Documentation

Language packs are modular Docker images that extend the base GitHub Actions runner with specific development toolchains. Each pack adds language-specific compilers, SDKs, and build tools while maintaining the modular architecture.

## Overview

### Benefits of Modular Language Packs

| Benefit | Monolith (All-in-One) | Modular (Language Packs) |
|---------|----------------------|-------------------------|
| **Image Size** | 2.5GB+ | 300MB base + 50-300MB per language |
| **Build Time** | 5-8 minutes | 1-3 minutes (per pack) |
| **Cache Efficiency** | Poor (~20%) | Excellent (~95%) |
| **Storage Cost** | High | Low (only needed languages) |
| **Update Time** | 10-15 minutes | 2-5 minutes (per pack) |
| **Security Surface** | Large (all tools) | Minimal (only used tools) |

## Available Language Packs

### Python Pack
- **Dockerfile**: `python/Dockerfile.python`
- **Size**: ~150MB (adds to base)
- **Total Size**: ~450MB
- **Tools Included**:
  - Python 3.x (system package)
  - pip (latest)
  - venv (virtual environments)
  - setuptools
  - wheel

**Best for**: Python/Django/Flask development, ML/AI workloads, data science

### C++ Pack
- **Dockerfile**: `cpp/Dockerfile.cpp`
- **Size**: ~250MB (adds to base)
- **Total Size**: ~550MB
- **Tools Included**:
  - GCC 11.x (C/C++ compiler)
  - Clang 14.x (alternative compiler)
  - Clang-format, Clang-tidy (code formatting)
  - CMake 3.x (build system)
  - Make, GNU Build Tools
  - GDB, Valgrind (debugging)
  - Common libraries (OpenSSL, Boost, etc.)

**Best for**: C/C++ development, systems programming, embedded systems

### Node.js Pack
- **Dockerfile**: `nodejs/Dockerfile.nodejs`
- **Size**: ~180MB (adds to base)
- **Total Size**: ~480MB
- **Tools Included**:
  - Node.js 20 LTS (via NodeSource)
  - npm (latest)
  - Yarn (classic & berry)
  - pnpm (fast package manager)
  - Node.js runtime & tooling

**Best for**: JavaScript/TypeScript development, Node.js applications, web frontends

### Additional Packs (Planned)

| Pack | Size | Tools | Use Case |
|------|------|-------|----------|
| **Java** | ~200MB | OpenJDK 17, Maven, Gradle | JVM development |
| **Go** | ~100MB | Go 1.22 toolchain | Go applications |
| **Rust** | ~150MB | Rust stable, Cargo | Rust development |
| **.NET** | ~300MB | .NET 8 SDK, runtime | C#/.NET applications |

## Architecture

### Layered Build Approach

```dockerfile
# Base Layer (300MB)
FROM ubuntu:22.04
└── GitHub Actions Runner
└── Core system tools

# Language Pack Layer (50-300MB)
FROM gh-runner:linux-base AS pack
└── Language-specific tools
└── Language-specific environment

# Final Image (Composite)
FROM gh-runner:linux-base
└── Base layer
└── Language pack layers (multiple)
```

### Build Process

**Individual Language Pack:**
```bash
docker build -f docker/linux/language-packs/python/Dockerfile.python \
    -t gh-runner:python-pack .
```

**Multiple Packs (for composite):**
```bash
# Build all packs
docker build -f docker/linux/language-packs/cpp/Dockerfile.cpp -t gh-runner:cpp-pack .
docker build -f docker/linux/language-packs/python/Dockerfile.python -t gh-runner:python-pack .
docker build -f docker/linux/language-packs/nodejs/Dockerfile.nodejs -t gh-runner:nodejs-pack .
```

## Usage Patterns

### Pattern 1: Single Language Runner

**Scenario**: Python-only development environment

```bash
# Build base image
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .

# Build Python pack
docker build -f docker/linux/language-packs/python/Dockerfile.python \
    -t gh-runner:python-pack .

# Build composite (extends base with Python)
# See: docker/linux/composite/Dockerfile.python-only
```

### Pattern 2: Multi-Language Runner

**Scenario**: Full-stack development (Node.js + Python)

```bash
# Build base image
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .

# Build required packs
docker build -f docker/linux/language-packs/nodejs/Dockerfile.nodejs \
    -t gh-runner:nodejs-pack .
docker build -f docker/linux/language-packs/python/Dockerfile.python \
    -t gh-runner:python-pack .

# Build composite (extends base with both)
# See: docker/linux/composite/Dockerfile.web
```

### Pattern 3: Custom Combination

**Scenario**: Custom set of tools

```dockerfile
# docker/linux/composite/Dockerfile.custom
FROM gh-runner:linux-base

# Copy from language packs
COPY --from=gh-runner:python-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:nodejs-pack /usr/local/bin/ /usr/local/bin/

# Add custom tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

ENV BUILD_STACK=custom
```

## Building Composite Images

### Using Dockerfile Multi-Stage

**Example: C++ Only Runner**
```dockerfile
# docker/linux/composite/Dockerfile.cpp-only
FROM gh-runner:linux-base

# Copy C++ tools from the C++ pack
COPY --from=gh-runner:cpp-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:cpp-pack /usr/include/ /usr/include/
COPY --from=gh-runner:cpp-pack /usr/lib/ /usr/lib/

# Set environment
ENV BUILD_TOOLCHAIN=c++ \
    CPP_ENV=enabled

LABEL org.opencontainers.image.description="C++ only GitHub Actions runner"
```

**Example: Web Stack Runner**
```dockerfile
# docker/linux/composite/Dockerfile.web
FROM gh-runner:linux-base

# Copy Node.js tools
COPY --from=gh-runner:nodejs-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:nodejs-pack /usr/local/lib/ /usr/local/lib/

# Copy Go tools (if available)
COPY --from=gh-runner:go-pack /usr/local/bin/ /usr/local/bin/ 2>/dev/null || true

# Add web-specific tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

ENV BUILD_STACK=nodego \
    WEB_ENV=enabled

LABEL org.opencontainers.image.description="Node.js + Go web development runner"
```

### Using Docker Compose Multi-Service

**Example: Parallel Builds**
```yaml
# docker-compose/build-all.yml
version: '3.8'
services:
  build-base:
    build:
      context: .
      dockerfile: docker/linux/base/Dockerfile.base
    image: gh-runner:linux-base

  build-python:
    build:
      context: .
      dockerfile: docker/linux/language-packs/python/Dockerfile.python
    image: gh-runner:python-pack
    depends_on:
      - build-base

  build-nodejs:
    build:
      context: .
      dockerfile: docker/linux/language-packs/nodejs/Dockerfile.nodejs
    image: gh-runner:nodejs-pack
    depends_on:
      - build-base
```

## Deployment Examples

### Python Development Runner

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
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/runner:/actions-runner
    networks:
      - github-runners
    mem_limit: 2g
    cpus: '1.0'
    restart: unless-stopped
```

### Web Development Runner

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
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/runner:/actions-runner
    networks:
      - github-runners
    mem_limit: 2g
    cpus: '1.0'
    restart: unless-stopped
```

## Testing Language Packs

### Python Pack Tests
```bash
# Test Python installation
docker run --rm gh-runner:python-pack python3 --version

# Test pip
docker run --rm gh-runner:python-pack pip --version

# Test virtual environment creation
docker run --rm gh-runner:python-pack python3 -m venv /tmp/test-venv
```

### C++ Pack Tests
```bash
# Test GCC
docker run --rm gh-runner:cpp-pack gcc --version

# Test C++ compilation
docker run --rm gh-runner:cpp-pack sh -c 'echo "int main() { return 0; }" > test.cpp && g++ test.cpp -o test && ./test && echo "Success"'

# Test CMake
docker run --rm gh-runner:cpp-pack cmake --version
```

### Node.js Pack Tests
```bash
# Test Node.js
docker run --rm gh-runner:nodejs-pack node --version

# Test npm
docker run --rm gh-runner:nodejs-pack npm --version

# Test package installation
docker run --rm gh-runner:nodejs-pack npm install -g typescript
```

### Composite Image Tests
```bash
# C++ only runner - verify Node.js is NOT installed
docker run --rm gh-runner:cpp-only node --version 2>&1 || echo "Node.js not installed (expected)"

# Web runner - verify both Node.js and Go are installed
docker run --rm gh-runner:web-stack node --version
docker run --rm gh-runner:web-stack go version
```

## Performance Comparison

### Build Time Comparison

| Image | Layers | Size | Build Time | Cache Hit |
|-------|--------|------|------------|-----------|
| Base only | 3 | 300MB | ~2 min | 90% |
| Base + Python | 4 | 450MB | ~2.5 min | 95% |
| Base + C++ | 4 | 550MB | ~3 min | 95% |
| Base + Node.js | 4 | 480MB | ~2.5 min | 95% |
| Base + 3 languages | 6 | 700MB | ~4 min | 90% |
| Full monolith | 15+ | 2.5GB | ~6-8 min | 20% |

### Storage Comparison

| Scenario | Monolith | Modular | Savings |
|----------|----------|---------|---------|
| Python only | 2.5GB | 450MB | 82% |
| C++ only | 2.5GB | 550MB | 78% |
| Node.js only | 2.5GB | 480MB | 81% |
| Python + Node.js | 2.5GB | 630MB | 75% |
| All languages | 2.5GB | 2.5GB | 0% |

### Network Transfer (Data Out)

| Image | Size | Download Cost |
|-------|------|---------------|
| Monolith | 2.5GB | High |
| Base only | 300MB | 88% savings |
| Base + Python | 450MB | 82% savings |
| Base + 2 langs | 600MB | 76% savings |

## Customization

### Adding New Tools to Language Packs

**Python Pack - Add ML Libraries:**
```dockerfile
# Extend python pack
FROM gh-runner:python-pack AS ml-pack

RUN pip install --no-cache-dir \
    numpy \
    pandas \
    scikit-learn \
    tensorflow \
    torch
```

**C++ Pack - Add Specific Libraries:**
```dockerfile
# Extend C++ pack
FROM gh-runner:cpp-pack AS embedded-pack

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*
```

### Version Pinning

**Python with Specific Version:**
```dockerfile
FROM ubuntu:22.04

# Install specific Python version
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y python3.11 python3.11-dev python3.11-venv \
    && rm -rf /var/lib/apt/lists/*

# Update alternatives
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
```

## Maintenance

### Updating Language Packs

**Step 1: Update Base Image (if needed)**
```bash
# Rebuild base
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .
```

**Step 2: Update Language Pack**
```bash
# Update specific pack (only rebuilds affected layers)
docker build -f docker/linux/language-packs/python/Dockerfile.python \
    --no-cache \
    -t gh-runner:python-pack .
```

**Step 3: Update Composite Images**
```bash
# Recompile composite with new packs
docker build -f docker/linux/composite/Dockerfile.python-only \
    -t gh-runner:python-only .
```

### Security Updates

**Security Patch (e.g., OpenSSL vulnerability):**
```bash
# Rebuild base (all packs inherit)
docker build -f docker/linux/base/Dockerfile.base \
    --no-cache \
    -t gh-runner:linux-base .

# Rebuild all packs
for pack in python cpp nodejs; do
    docker build -f docker/linux/language-packs/$pack/Dockerfile.$pack \
        -t gh-runner:$pack-pack .
done
```

## Troubleshooting

### Common Issues

**1. Build Failure: "gh-runner:linux-base not found"**
```bash
# Build base first
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .
```

**2. Build Failure: "Package not found"**
```bash
# Update apt cache in Dockerfile
# Add: RUN apt-get update
```

**3. Large Image Size**
```bash
# Check layers
docker history gh-runner:python-pack

# Optimize: combine RUN commands, clean apt cache
```

**4. Slow Build Times**
```bash
# Use build cache
# Tag base image first
# Build language packs in parallel
```

### Size Optimization Tips

1. **Combine apt-get commands**: Use single RUN for apt operations
2. **Clean apt cache**: Always remove `/var/lib/apt/lists/*`
3. **Use `--no-install-recommends`**: Reduces unnecessary packages
4. **Multi-stage builds**: Copy only needed binaries
5. **Remove documentation**: Add `rm -rf /usr/share/doc/*`

## Migration from Monolith

### Step 1: Identify Workflow Requirements
```bash
# Analyze existing monolith usage
# What languages/tools are actually used?
```

### Step 2: Build Minimal Set
```bash
# Build base + most used language packs
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .
docker build -f docker/linux/language-packs/python/Dockerfile.python -t gh-runner:python-pack .
```

### Step 3: Create Composite Images
```bash
# Create custom composite for your needs
# See: docker/linux/composite/Dockerfile.custom
```

### Step 4: Deploy in Parallel
```yaml
# Deploy new modular runners alongside monolith
# Update workflow labels gradually
```

### Step 5: Monitor and Optimize
- Track build times
- Monitor storage usage
- Adjust language pack combinations
- Remove unused packs

## Best Practices

### 1. Start Small
Begin with base + 1-2 language packs for most-used languages. Add more only when needed.

### 2. Tag Images Properly
```bash
# Use semantic versioning
docker tag gh-runner:python-pack gh-runner:python-pack:1.0.0
docker tag gh-runner:python-pack gh-runner:python-pack:latest
```

### 3. Use .dockerignore
Create `.dockerignore` files in each directory to exclude unnecessary files:
```
*.md
*.txt
.git
.gitignore
README.md
```

### 4. Document Dependencies
For each language pack, document:
- Required tools
- Version constraints
- Build dependencies
- Runtime dependencies

### 5. Monitor Resource Usage
```bash
# Check image size
docker images | grep gh-runner

# Check container resource usage
docker stats <container>
```

## Related Files

- **Base Image**: `docker/linux/base/Dockerfile.base`
- **Entrypoint**: `docker/linux/entrypoint/entrypoint.sh`
- **Composite Images**: `docker/linux/composite/`
- **Docker Compose**: `docker-compose/linux-*.yml`
- **Documentation**: `docs/linux-modular/`

## Next Steps

1. **Review available language packs** and identify which you need
2. **Build base image** as foundation
3. **Build language packs** for your requirements
4. **Create composite images** for specific use cases
5. **Deploy with Docker Compose** configurations
6. **Migrate workflows** gradually from monolith to modular

## Support & Contributions

For issues or improvements:
- Check existing Dockerfiles for patterns
- Follow Docker best practices
- Test thoroughly before production use
- Document changes and rationale
