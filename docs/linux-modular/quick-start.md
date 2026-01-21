# Quick Start Guide

This guide will help you get started with modular Linux GitHub Actions runners in 15 minutes or less.

## Prerequisites

### 1. Docker Installation
Ensure Docker is installed and running:

```bash
# Check Docker version
docker --version
# Docker version 20.10.0 or higher recommended

# Check Docker is running
docker ps
# Should show container list (even if empty)
```

### 2. GitHub Token
Create a GitHub personal access token:

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name (e.g., "GitHub Actions Runner")
4. Select scopes:
   - **For repository runners**: `repo` (Full control of private repositories)
   - **For organization runners**: `admin:org` (Full control of organizations)
5. Click **Generate token**
6. **Copy the token** (you won't see it again!)

### 3. Target Repository/Organization
Identify where you want to run workflows:
- **Repository**: `owner/repo` format
- **Organization**: Organization name

## Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/cicd/github-runner.git
cd github-runner
```

### Step 2: Set Environment Variables

Create a `.env` file in the project root:

```bash
# .env file
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPOSITORY=your-org/your-repo
RUNNER_NAME=my-first-runner
RUNNER_LABELS=linux,my-project

# Optional settings
# RUNNER_WORKDIR=_work
# RUNNER_GROUP=Default
```

**Important**: Replace the values with your actual credentials!

### Step 3: Choose Your Runner

Based on your project needs, pick one:

| Project Type | Recommended Runner | Command |
|--------------|-------------------|---------|
| **C/C++ Project** | `linux-cpp.yml` | `docker-compose -f docker-compose/linux-cpp.yml up -d` |
| **Python Project** | `linux-python.yml` | `docker-compose -f docker-compose/linux-python.yml up -d` |
| **Web Project (Node.js/Go)** | `linux-web.yml` | `docker-compose -f docker-compose/linux-web.yml up -d` |
| **Multiple Languages** | `linux-full.yml` | `docker-compose -f docker-compose/linux-full.yml up -d` |
| **Just Basics** | `linux-base.yml` | `docker-compose -f docker-compose/linux-base.yml up -d` |

### Step 4: Build and Deploy

**Using Docker Compose (Recommended)**:

```bash
# Build and start the runner
docker-compose -f docker-compose/linux-cpp.yml up -d
```

**Manual Build** (if you prefer):

```bash
# 1. Build base image
docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base .

# 2. Build language pack(s)
docker build -f docker/linux/language-packs/cpp/Dockerfile.cpp -t gh-runner:cpp-pack .

# 3. Build composite image
docker build -f docker/linux/composite/Dockerfile.cpp-only -t gh-runner:cpp-only .

# 4. Run the container
docker run -d \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=${GITHUB_REPOSITORY} \
    -e RUNNER_NAME=${RUNNER_NAME} \
    --name cpp-runner \
    gh-runner:cpp-only
```

## Verification

### Step 1: Check Runner Status

```bash
# View logs
docker-compose -f docker-compose/linux-cpp.yml logs -f

# Or for manual deployment
docker logs -f cpp-runner
```

Look for these messages:
```
✅ Configuration successful
✅ Runner registered successfully
✅ Runner is now online
```

### Step 2: Verify in GitHub

1. Go to your GitHub repository/organization
2. Navigate to **Settings** → **Actions** → **Runners**
3. You should see your new runner with the label(s) you specified
4. Status should show **Idle** or **Online**

### Step 3: Test with a Workflow

Create a test workflow to verify everything works:

```yaml
# .github/workflows/test-runner.yml
name: Test Modular Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, linux, cpp]  # Adjust based on your runner
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check environment
        run: |
          echo "Runner: ${{ runner.name }}"
          echo "OS: $(uname -a)"
          echo "User: $(whoami)"
          echo "Working directory: $(pwd)"

      - name: Test C++ compiler
        if: contains(github.event.pull_request.labels.*.name, 'cpp') || contains(github.ref, 'cpp')
        run: |
          gcc --version
          echo "int main() { return 0; }" > test.cpp
          g++ test.cpp -o test
          ./test
          echo "✅ C++ compilation successful!"

      - name: Test Python
        if: contains(github.event.pull_request.labels.*.name, 'python') || contains(github.ref, 'python')
        run: |
          python3 --version
          echo "print('Python test successful!')" > test.py
          python3 test.py

      - name: Test Node.js
        if: contains(github.event.pull_request.labels.*.name, 'node') || contains(github.ref, 'node')
        run: |
          node --version
          npm --version
          echo "console.log('Node.js test successful!');" > test.js
          node test.js

      - name: Test Go
        if: contains(github.event.pull_request.labels.*.name, 'go') || contains(github.ref, 'go')
        run: |
          go version
          echo 'package main\nimport "fmt"\nfunc main() { fmt.Println("Go test successful!") }' > test.go
          go run test.go

      - name: Docker test
        if: contains(github.event.pull_request.labels.*.name, 'docker') || contains(github.ref, 'docker')
        run: |
          docker --version
          echo "Docker test successful!"
```

**To run the workflow**:
1. Go to **Actions** tab
2. Select "Test Modular Runner" workflow
3. Click **Run workflow**
4. Select the branch
5. Click **Run workflow**

**Expected result**: ✅ All tests should pass!

## Common Scenarios

### Scenario 1: C++ Development

**Setup**:
```bash
docker-compose -f docker-compose/linux-cpp.yml up -d
```

**Test workflow**:
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      - name: Build with CMake
        run: |
          cmake -B build -S .
          cmake --build build
```

### Scenario 2: Python/ML Development

**Setup**:
```bash
docker-compose -f docker-compose/linux-python.yml up -d
```

**Test workflow**:
```yaml
jobs:
  test:
    runs-on: [self-hosted, linux, python]
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run tests
        run: pytest tests/
```

### Scenario 3: Web Development (Node.js + Go)

**Setup**:
```bash
docker-compose -f docker-compose/linux-web.yml up -d
```

**Test workflow**:
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, node, go]
    steps:
      - uses: actions/checkout@v4
      - name: Build Node.js app
        run: |
          npm install
          npm run build
      - name: Build Go app
        run: |
          go mod download
          go build -o app main.go
```

## Troubleshooting

### Problem: "Failed to generate registration token"

**Solution**:
1. Check token permissions:
   - Repository: `repo` scope
   - Organization: `admin:org` scope
2. Verify token hasn't expired
3. Check GitHub API status: https://www.githubstatus.com/

### Problem: "Permission denied" errors

**Solution**:
```bash
# Check container user
docker exec -it cpp-runner whoami
# Should show: runner

# Check file permissions
docker exec -it cpp-runner ls -la /actions-runner
```

### Problem: "Out of memory" or container crashes

**Solution**:
```yaml
# Increase memory limit in docker-compose
services:
  cpp-runner:
    mem_limit: 4g  # Increase from default
```

### Problem: Runner not appearing in GitHub

**Solution**:
1. Check logs: `docker-compose -f docker-compose/linux-cpp.yml logs`
2. Verify environment variables are set
3. Check network connectivity
4. Ensure GitHub Actions service is available

## Performance Tips

### 1. Use Build Cache
```bash
# Enable BuildKit for better caching
export DOCKER_BUILDKIT=1
docker-compose -f docker-compose/linux-cpp.yml build --no-cache
```

### 2. Optimize Resource Allocation
```bash
# Monitor resource usage
docker stats

# Adjust in docker-compose if needed
# services:
#   cpp-runner:
#     mem_limit: 2g
#     cpus: '1.5'
```

### 3. Reuse Cached Dependencies
```bash
# Python: Use pip cache
# C++: Use build cache
# Node.js: Use npm cache
# (Already configured in docker-compose files)
```

## Next Steps

### 1. Explore Advanced Features
- Read the [Language Packs documentation](language-packs.md)
- Learn about [Custom Combinations](custom-combinations.md)
- Understand [Performance optimization](performance.md)

### 2. Scale Your Runners
```bash
# Add more runners for parallel builds
docker-compose -f docker-compose/linux-cpp.yml up -d cpp-runner-01
docker-compose -f docker-compose/linux-cpp.yml up -d cpp-runner-02
```

### 3. Integrate with Your CI/CD
```yaml
# Add to your existing workflows
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - uses: actions/checkout@v4
      # Your existing steps
```

### 4. Monitor and Optimize
- Check build times in GitHub Actions
- Monitor resource usage with `docker stats`
- Adjust configurations based on actual usage

## Quick Reference

### Common Commands

```bash
# Start runner
docker-compose -f docker-compose/linux-cpp.yml up -d

# View logs
docker-compose -f docker-compose/linux-cpp.yml logs -f

# Stop runner
docker-compose -f docker-compose/linux-cpp.yml down

# Check status
docker-compose -f docker-compose/linux-cpp.yml ps

# View resource usage
docker stats cpp-runner

# Update runner
docker-compose -f docker-compose/linux-cpp.yml build --no-cache
docker-compose -f docker-compose/linux-cpp.yml up -d
```

### Docker Compose Files

| File | Size | Use Case |
|------|------|----------|
| `linux-base.yml` | 300MB | Minimal runner, no tools |
| `linux-cpp.yml` | 550MB | C/C++ development |
| `linux-python.yml` | 450MB | Python/ML development |
| `linux-web.yml` | 580MB | Node.js + Go web dev |
| `linux-full.yml` | 2.5GB | All languages (legacy) |

### Environment Variables

**Required**:
- `GITHUB_TOKEN`: GitHub personal access token
- `GITHUB_REPOSITORY`: Target repository (owner/repo)

**Optional**:
- `RUNNER_NAME`: Runner name (auto-generated if not set)
- `RUNNER_LABELS`: Comma-separated labels (default: linux)
- `RUNNER_WORKDIR`: Working directory (default: _work)
- `RUNNER_GROUP`: Runner group (default: Default)

## Need Help?

### Documentation
- [Main Documentation](README.md)
- [Migration Guide](migration.md)
- [Language Packs](language-packs.md)

### Support
- Check [GitHub Issues](https://github.com/cicd/github-runner/issues)
- Review [GitHub Discussions](https://github.com/cicd/github-runner/discussions)
- Contact your DevOps team

### Common Issues
- [Troubleshooting Guide](README.md#troubleshooting)
- [Error Messages Reference](README.md#error-messages)

---

**Ready to go?** Your runner should now be online and ready to process workflows! 🚀
