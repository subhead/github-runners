# Action Runner Documentation

## Overview

The Action Runner is a lightweight self-hosted GitHub Actions runner designed for executing CI/CD jobs, tests, and deployments. It's optimized for speed and minimal resource usage.

## Key Features

- **Lightweight**: ~600MB image size
- **Fast Startup**: ~30 seconds from container start to ready
- **Minimal Dependencies**: Only essential packages installed
- **Docker-in-Docker Optional**: Can be enabled for container builds
- **Security**: Runs as non-root user by default

## Use Cases

### 1. Running CI/CD Jobs
Execute tests, linting, and validation steps on your codebase.

### 2. Deployments
Deploy applications to various environments (staging, production).

### 3. Code Analysis
Run static analysis, security scanning, and code quality checks.

### 4. Artifact Generation
Build and package artifacts for distribution.

## Installation

### Prerequisites

- Docker 20.10+ installed
- GitHub Personal Access Token with `repo` scope
- GitHub repository (format: `owner/repo`)

### Quick Start

#### Using Docker Directly

```bash
# Build the image
docker build \
  -f docker/linux/Dockerfile.action-runner \
  -t gh-runner:linux-action \
  .

# Run the runner
docker run -d \
  --name github-action-runner \
  -e GITHUB_TOKEN=ghp_your_token_here \
  -e GITHUB_REPOSITORY=your-org/your-repo \
  -e RUNNER_NAME=my-action-runner \
  -e RUNNER_LABELS=linux,action \
  gh-runner:linux-action
```

#### Using Docker Compose

```bash
# Using the provided docker-compose file
docker-compose -f docker-compose/linux-runners.yml up gh-runner -d
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
| `RUNNER_NAME` | Unique identifier for the runner | Hostname | `linux-runner-1` |
| `RUNNER_LABELS` | Comma-separated labels for runner selection | `linux,runner` | `linux,prod,action` |
| `RUNNER_GROUP` | Runner group (Enterprise feature) | `default` | `production` |
| `CLEANUP_EXISTING` | Remove existing runner configuration | `false` | `true` |
| `FORCE_RECONFIGURE` | Force reconfiguration of runner | `false` | `true` |
| `INSTALL_DOCKER` | Install Docker CLI (for Docker-in-Docker) | `false` | `true` |

### Advanced Configuration

#### With Docker-in-Docker Support

If your workflow needs to build Docker images:

```bash
docker run -d \
  --name github-action-runner \
  -e GITHUB_TOKEN=ghp_your_token_here \
  -e GITHUB_REPOSITORY=your-org/your-repo \
  -e INSTALL_DOCKER=true \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-action
```

**⚠️ Security Warning**: Mounting `/var/run/docker.sock` gives the container access to the host Docker daemon. Only use this when necessary and with trusted images.

#### Custom Labels for Job Targeting

Labels help GitHub Actions route jobs to appropriate runners:

```bash
-e RUNNER_LABELS=linux,action,production,fast
```

In your workflow:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, production]  # Targets runners with all these labels
    steps:
      - uses: actions/checkout@v3
      - run: ./deploy.sh
```

#### Multiple Runners with Different Configurations

Create multiple runners with different capabilities:

```bash
# Runner 1: Basic action runner
docker run -d \
  --name github-action-runner-1 \
  -e GITHUB_TOKEN=... \
  -e GITHUB_REPOSITORY=... \
  -e RUNNER_NAME=linux-runner-1 \
  -e RUNNER_LABELS=linux,action,runner \
  gh-runner:linux-action

# Runner 2: With Docker support
docker run -d \
  --name github-action-runner-2 \
  -e GITHUB_TOKEN=... \
  -e GITHUB_REPOSITORY=... \
  -e RUNNER_NAME=linux-runner-docker \
  -e RUNNER_LABELS=linux,action,docker \
  -e INSTALL_DOCKER=true \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-action
```

## Workflow Integration

### Example Workflows

#### 1. Simple Test Job

```yaml
name: Test Application
on: [push]

jobs:
  test:
    runs-on: [self-hosted, linux, action]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install Dependencies
        run: npm ci

      - name: Run Tests
        run: npm test
```

#### 2. Build and Deploy

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, linux, action]
    steps:
      - uses: actions/checkout@v3

      - name: Build Application
        run: |
          make build
          make test

      - name: Create Artifact
        run: |
          tar -czf app.tar.gz dist/
          echo "ARTIFACT=app.tar.gz" >> $GITHUB_ENV

      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: application
          path: ${{ env.ARTIFACT }}

  deploy:
    needs: build
    runs-on: [self-hosted, linux, action, production]
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: application

      - name: Deploy to Production
        run: ./deploy.sh app.tar.gz
```

#### 3. Custom Labels for Job Routing

```yaml
name: Multi-Environment
on: [push]

jobs:
  test:
    runs-on: [self-hosted, linux, action]
    steps:
      - uses: actions/checkout@v3
      - run: npm test

  build:
    needs: test
    runs-on: [self-hosted, linux, action, docker]
    steps:
      - uses: actions/checkout@v3
      - run: docker build -t myapp:latest .
      - run: docker push myrepo/myapp:latest
```

## Monitoring

### View Logs

```bash
# Docker CLI
docker logs -f github-action-runner

# Docker Compose
docker-compose -f docker-compose/linux-runners.yml logs -f gh-runner
```

### Check Runner Status

```bash
# Check if container is running
docker ps | grep github-action-runner

# Check container health
docker inspect github-action-runner | jq '.[].State.Health'

# View runner status in GitHub
# Go to: Settings > Actions > Runners
```

### Resource Usage

```bash
# View resource usage
docker stats github-action-runner

# View detailed resource usage
docker inspect github-action-runner | jq '.[].HostConfig'
```

## Security

### Token Management

**Best Practices:**
- Use fine-grained personal access tokens
- Grant minimal required permissions (usually `repo` scope)
- Rotate tokens regularly (90 days recommended)
- Store in GitHub Secrets for CI/CD workflows
- Never commit tokens to version control

### Container Security

1. **Non-root User**: Runner runs as non-root user by default
2. **Read-only Filesystem**: Can be enabled for additional security
3. **Resource Limits**: Prevents runaway processes
4. **Docker Socket**: Only mount when necessary, use read-only mode

### Network Security

- Consider using private networks for runners
- Restrict runner access with GitHub runner groups
- Use VPN or private VPC for sensitive deployments

## Troubleshooting

### Runner Not Connecting to GitHub

**Symptoms**: Runner doesn't appear in GitHub repository settings

**Solutions**:
1. Verify `GITHUB_TOKEN` is correct and has `repo` scope
2. Check token is not expired
3. Verify repository format: `owner/repo`
4. Check container logs for errors

```bash
docker logs github-action-runner
```

### Authentication Errors

**Error**: `Failed to generate runner token`

**Solution**:
```bash
# Test token manually
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# Check token permissions
# Go to: GitHub Settings > Developer Settings > Personal Access Tokens
```

### Container Fails to Start

**Check logs**:
```bash
docker logs github-action-runner
```

**Common issues**:
- Missing required environment variables
- Token permissions insufficient
- Network connectivity issues

### Job Execution Failures

**Debug steps**:
1. Check runner logs: `docker logs -f github-action-runner`
2. View job logs in GitHub Actions UI
3. Check if runner has necessary tools installed
4. Verify resource limits aren't exhausted

## Performance

### Resource Allocation

**Minimum**:
- CPU: 0.5 cores
- Memory: 1GB
- Disk: 5GB free space

**Recommended**:
- CPU: 1-2 cores
- Memory: 2GB
- Disk: 10GB free space

### Optimizing Runner Performance

1. **Use Host Resources**: Runners inherit host performance
2. **Cache Dependencies**: Use GitHub Actions cache
3. **Parallel Jobs**: Run multiple runners for parallel execution
4. **Label-based Routing**: Use appropriate labels for job targeting

### Scaling

Add more runners for parallel job execution:

```bash
# Using docker-compose scale
docker-compose -f docker-compose/linux-runners.yml up --scale gh-runner=5 -d
```

## Maintenance

### Updating the Runner

1. **Update Docker Image**:
```bash
docker pull ubuntu:22.04
docker build -f docker/linux/Dockerfile.action-runner -t gh-runner:linux-action .
```

2. **Recreate Container**:
```bash
docker-compose -f docker-compose/linux-runners.yml up -d --force-recreate gh-runner
```

### Cleaning Up

```bash
# Remove container
docker rm -f github-action-runner

# Remove image
docker image rm gh-runner:linux-action

# Remove from GitHub
# Go to: Settings > Actions > Runners > Click runner > Remove
```

### Regular Maintenance Tasks

- **Daily**: Check runner status, review logs
- **Weekly**: Update security patches, clean old images
- **Monthly**: Review and update GitHub token, update base images

## Common Use Cases

### 1. React Application CI

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, action]
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install Dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Test
        run: npm test

      - name: Upload Build
        uses: actions/upload-artifact@v3
        with:
          name: build-output
          path: build/
```

### 2. Python Application CI

```yaml
jobs:
  test:
    runs-on: [self-hosted, linux, action]
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
        run: flake8 .

      - name: Run Tests
        run: pytest --cov=src tests/
```

### 3. Multi-Stage Deployment

```yaml
name: Multi-Stage Deployment
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, linux, action]
    steps:
      - uses: actions/checkout@v3

      - name: Build
        run: make build

      - name: Store Artifact
        run: |
          cp build/app dist/
          echo "BUILD_HASH=$(git rev-parse HEAD)" >> $GITHUB_ENV

  deploy-staging:
    needs: build
    runs-on: [self-hosted, linux, action, staging]
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Staging
        run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: [self-hosted, linux, action, production]
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Production
        run: ./deploy.sh production
```

## Advanced Features

### Docker-in-Docker (DinD)

For workflows that need to build Docker images:

```bash
# Enable Docker support
docker run -d \
  --name github-action-runner \
  -e INSTALL_DOCKER=true \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-action
```

Workflow example:

```yaml
jobs:
  build-image:
    runs-on: [self-hosted, linux, action, docker]
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

### Custom Runner Configuration

Create custom runners by extending the base image:

```dockerfile
# docker/linux/Dockerfile.custom-action-runner
FROM gh-runner:linux-action

# Install additional tools
RUN apt-get update && apt-get install -y \
    sqlite3 \
    postgresql-client \
    mysql-client

# Copy custom scripts
COPY custom-scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*
```

Build and use:

```bash
docker build -f docker/linux/Dockerfile.custom-action-runner -t gh-runner:custom .
docker run -d gh-runner:custom
```

## Reference

### Image Details

- **Base Image**: Ubuntu 22.04 LTS
- **Runner Version**: 2.331.0
- **Architecture**: x64
- **Size**: ~600MB
- **User**: runner (UID 1001)
- **Work Directory**: `/actions-runner`

### Files in Container

```
/actions-runner/
├── config.sh          # Runner configuration script
├── run.sh             # Runner execution script
├── .runner            # Runner configuration file
├── .credentials       # Runner credentials
└── _work/             # Working directory for jobs
```

### Useful Commands

```bash
# View runner configuration
docker exec github-action-runner cat /actions-runner/.runner

# Test GitHub connectivity
docker exec github-action-runner curl -s https://api.github.com

# Run commands inside runner
docker exec -it github-action-runner bash

# Check runner version
docker exec github-action-runner ./run.sh --version
```

## Next Steps

- Review [Configuration Reference](./configuration.md) for detailed configuration options
- See [Security Best Practices](./security.md) for production deployments
- Check [Build Runner Documentation](./build-runner.md) if you need comprehensive build tools
