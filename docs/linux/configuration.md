# Configuration Reference

This document provides comprehensive configuration options for Linux GitHub Actions runners.

## Overview

Runners can be configured through:
1. **Environment Variables**: Passed at container runtime
2. **Docker Compose**: YAML configuration for deployment
3. **Docker CLI Options**: Direct Docker commands
4. **Entrypoint Script Arguments**: Runtime behavior modifications

## Environment Variables

### Required Variables

#### GITHUB_TOKEN

**Purpose**: GitHub authentication token for runner registration

**Format**:
- Classic PAT: `ghp_xxxxxxxx`
- Fine-grained PAT: `ghs_xxxxxxxx`

**Permissions Required**:
- Repository: `repo` scope (classic) or `contents:read`, `actions:write` (fine-grained)
- Organization: `admin:org` for organization runners

**Example**:
```bash
export GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz123456
```

**Security Notes**:
- Use minimal required permissions
- Rotate tokens regularly (90 days recommended)
- Store in GitHub Secrets for CI/CD
- Never commit to version control

#### GITHUB_REPOSITORY

**Purpose**: Target repository or organization for runner registration

**Format**:
- Repository: `owner/repo`
- Organization: `organization-name`

**Examples**:
```bash
export GITHUB_REPOSITORY=my-org/my-repo
export GITHUB_REPOSITORY=my-org  # For organization runners
```

**Validation Rules**:
- Must be lowercase
- No special characters except hyphens
- Format: `owner/repo` (repository) or `owner` (organization)

### Optional Variables

#### RUNNER_NAME

**Purpose**: Unique identifier for the runner instance

**Default**: Container hostname (auto-generated)

**Format**: Any valid hostname format

**Examples**:
```bash
export RUNNER_NAME=linux-action-runner-1
export RUNNER_NAME=production-build-runner
```

**Use Cases**:
- Easy identification in GitHub UI
- Load balancing across multiple runners
- Environment-specific naming

#### RUNNER_LABELS

**Purpose**: Comma-separated labels for runner selection in workflows

**Default**: `linux,runner` (action), `linux,build,docker,node,python,java,dotnet,rust,go` (build)

**Format**: Comma-separated, no spaces (GitHub will parse)

**Examples**:
```bash
# Action runner labels
export RUNNER_LABELS=linux,action,fast

# Build runner labels
export RUNNER_LABELS=linux,build,docker,production

# Multi-environment labels
export RUNNER_LABELS=linux,build,staging,us-west
```

**Workflow Usage**:
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, build]  # Matches all these labels
    steps:
      - uses: actions/checkout@v3
```

**Best Practices**:
- Use descriptive labels
- Include environment (prod, staging, dev)
- Include region/cloud provider
- Include special capabilities (docker, gpu, etc.)

#### RUNNER_GROUP

**Purpose**: Assign runner to a specific runner group (Enterprise feature)

**Default**: `default`

**Requirements**:
- GitHub Enterprise Cloud or Enterprise Server
- Admin permissions

**Examples**:
```bash
export RUNNER_GROUP=production
export RUNNER_GROUP=build-farm
```

**Benefits**:
- Access control for sensitive repositories
- Dedicated resources for specific teams
- Better organization management

#### WORK_DIR

**Purpose**: Working directory for runner files

**Default**: `/actions-runner`

**Examples**:
```bash
export WORK_DIR=/home/runner/actions
export WORK_DIR=/data/runner
```

**Important**:
- Must be writable by runner user (UID 1001)
- Should have sufficient disk space
- Persistent storage recommended

#### CLEANUP_EXISTING

**Purpose**: Remove existing runner configuration before startup

**Default**: `false`

**Values**: `true` or `false`

**Examples**:
```bash
export CLEANUP_EXISTING=true
```

**Use Cases**:
- Fresh setup scenarios
- Runner reconfiguration
- Removing stale configurations

**Warning**: Will unregister existing runner from GitHub

#### FORCE_RECONFIGURE

**Purpose**: Force reconfiguration even if runner is already configured

**Default**: `false`

**Values**: `true` or `false`

**Examples**:
```bash
export FORCE_RECONFIGURE=true
```

**Use Cases**:
- Changing labels/runner group
- Re-registering with different token
- Debugging configuration issues

#### INSTALL_DOCKER

**Purpose**: Install Docker CLI inside container

**Default**: `false` (action), `true` (build)

**Values**: `true` or `false`

**Examples**:
```bash
export INSTALL_DOCKER=true
```

**Note**: For Docker-in-Docker functionality, you also need to mount `/var/run/docker.sock`

**Build Runner**: Enabled by default
**Action Runner**: Disabled by default

## Docker Compose Configuration

### Service Definitions

#### Action Runner Service

```yaml
services:
  gh-runner:
    build:
      context: .
      dockerfile: docker/linux/Dockerfile.action-runner
      args:
        - RUNNER_VERSION=2.331.0
        - UBUNTU_VERSION=22.04
    container_name: github-action-runner
    image: gh-runner:linux-action
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=${RUNNER_NAME:-linux-action-runner-1}
      - RUNNER_LABELS=${RUNNER_LABELS:-linux,action,runner}
      - RUNNER_GROUP=${RUNNER_GROUP:-default}
      - CLEANUP_EXISTING=${CLEANUP_EXISTING:-false}
      - FORCE_RECONFIGURE=${FORCE_RECONFIGURE:-false}
      - INSTALL_DOCKER=${INSTALL_DOCKER:-false}
    volumes:
      # Uncomment for Docker-in-Docker
      # - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - github-runners
    mem_limit: 2g
    cpus: '1.0'
    restart: unless-stopped
```

#### Build Runner Service

```yaml
services:
  gh-build-runner:
    build:
      context: .
      dockerfile: docker/linux/Dockerfile.build-runner
      args:
        - RUNNER_VERSION=2.331.0
        - UBUNTU_VERSION=22.04
    container_name: github-build-runner
    image: gh-runner:linux-build
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=${RUNNER_NAME:-linux-build-runner-1}
      - RUNNER_LABELS=${RUNNER_LABELS:-linux,build,docker,node,java,python,dotnet,rust,go}
      - RUNNER_GROUP=${RUNNER_GROUP:-default}
      - CLEANUP_EXISTING=${CLEANUP_EXISTING:-false}
      - FORCE_RECONFIGURE=${FORCE_RECONFIGURE:-false}
      - INSTALL_DOCKER=${INSTALL_DOCKER:-true}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # Optional: Cache volumes
      # - npm-cache:/home/runner/.npm
      # - maven-cache:/home/runner/.m2
      # - cargo-cache:/home/runner/.cargo
    networks:
      - github-runners
    mem_limit: 4g
    cpus: '2.0'
    restart: unless-stopped
```

### Network Configuration

```yaml
networks:
  github-runners:
    driver: bridge
    # Optional: Custom network name
    # driver_opts:
    #   com.docker.network.bridge.name: github-runners
    #   com.docker.network.bridge.enable_icc: "true"
    #   com.docker.network.bridge.enable_ip_masquerade: "true"
```

### Volume Configuration

```yaml
volumes:
  # Persistent cache for npm/yarn
  npm-cache:
    driver: local
    driver_opts:
      type: none
      device: /path/to/npm-cache
      o: bind

  # Maven cache
  maven-cache:
    driver: local
    driver_opts:
      type: none
      device: /path/to/maven-cache
      o: bind

  # Cargo/Rust cache
  cargo-cache:
    driver: local
    driver_opts:
      type: none
      device: /path/to/cargo-cache
      o: bind

  # General build cache
  build-cache:
    driver: local
    driver_opts:
      type: none
      device: /path/to/build-cache
      o: bind
```

## Docker CLI Options

### Basic Run

```bash
# Action runner
docker run -d \
  --name github-action-runner \
  -e GITHUB_TOKEN=ghp_xxxxxxxx \
  -e GITHUB_REPOSITORY=owner/repo \
  -e RUNNER_NAME=my-runner \
  gh-runner:linux-action

# Build runner (with Docker socket)
docker run -d \
  --name github-build-runner \
  -e GITHUB_TOKEN=ghp_xxxxxxxx \
  -e GITHUB_REPOSITORY=owner/repo \
  -e RUNNER_NAME=build-runner \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  gh-runner:linux-build
```

### Advanced Options

#### With Resource Limits

```bash
docker run -d \
  --name github-action-runner \
  --memory=2g \
  --memory-swap=2g \
  --cpus="1.0" \
  --cpu-shares=512 \
  -e GITHUB_TOKEN=... \
  gh-runner:linux-action
```

#### With Health Check

```bash
docker run -d \
  --name github-action-runner \
  --health-cmd="curl -f http://localhost:8080/" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-start-period=40s \
  --health-retries=3 \
  -e GITHUB_TOKEN=... \
  gh-runner:linux-action
```

#### With Restart Policy

```bash
docker run -d \
  --name github-action-runner \
  --restart=unless-stopped \
  -e GITHUB_TOKEN=... \
  gh-runner:linux-action
```

#### With Custom Network

```bash
docker network create github-runners

docker run -d \
  --name github-action-runner \
  --network=github-runners \
  -e GITHUB_TOKEN=... \
  gh-runner:linux-action
```

## Entrypoint Script Behavior

### Startup Sequence

The entrypoint script follows this sequence:

1. **Validate Configuration**
   - Check required environment variables
   - Validate repository format
   - Set default values

2. **Generate Runner Token**
   - Call GitHub API with provided token
   - Validate token response

3. **Configure Runner**
   - Run `config.sh` with provided options
   - Create `.runner` configuration file
   - Register with GitHub

4. **Cleanup (if enabled)**
   - Remove existing configuration
   - Unregister previous runner

5. **Start Runner**
   - Execute `./run.sh`
   - Wait for GitHub connection

### Configuration Options

The entrypoint script accepts these configuration flags via environment variables:

| Flag | Env Var | Default | Description |
|------|---------|---------|-------------|
| `--url` | `GITHUB_REPOSITORY` | Required | GitHub repository URL |
| `--token` | `GITHUB_TOKEN` | Required | Runner token |
| `--name` | `RUNNER_NAME` | Hostname | Runner name |
| `--labels` | `RUNNER_LABELS` | `linux,runner` | Runner labels |
| `--runnergroup` | `RUNNER_GROUP` | `default` | Runner group |
| `--work` | `WORK_DIR` | `/actions-runner` | Working directory |
| `--ephemeral` | `RUNNER_EPHEMERAL` | `false` | Ephemeral runner |

### Error Handling

The entrypoint script includes comprehensive error handling:

```bash
# Check for errors
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate runner token"
    exit 1
fi

# Validate response
if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
    echo "Error: Invalid runner token response"
    exit 1
fi
```

## .env File Configuration

Create a `.env` file for easy configuration management:

```bash
# .env file
# GitHub Configuration
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_REPOSITORY=your-org/your-repo

# Runner Configuration
RUNNER_NAME=linux-production-runner
RUNNER_LABELS=linux,production,runner
RUNNER_GROUP=production

# Feature Flags
CLEANUP_EXISTING=false
FORCE_RECONFIGURE=false
INSTALL_DOCKER=false

# Resource Limits (Docker Compose)
MEM_LIMIT=2g
CPUS=1.0
```

**Usage**:
```bash
docker-compose -f docker-compose/linux-runners.yml --env-file .env up -d
```

## Scaling Configuration

### Multiple Runners with Different Configurations

#### Example 1: Different Environments

```yaml
services:
  runner-dev:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=dev-runner-1
      - RUNNER_LABELS=linux,action,dev
      - RUNNER_GROUP=development

  runner-staging:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=staging-runner-1
      - RUNNER_LABELS=linux,action,staging
      - RUNNER_GROUP=staging

  runner-prod:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=prod-runner-1
      - RUNNER_LABELS=linux,action,production
      - RUNNER_GROUP=production
```

#### Example 2: Different Capabilities

```yaml
services:
  runner-basic:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=basic-runner-1
      - RUNNER_LABELS=linux,action,basic

  runner-docker:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=docker-runner-1
      - RUNNER_LABELS=linux,action,docker
      - INSTALL_DOCKER=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  runner-build:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=build-runner-1
      - RUNNER_LABELS=linux,build,docker
      - INSTALL_DOCKER=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Horizontal Scaling

#### Using Docker Compose Scale

```bash
# Scale action runners
docker-compose -f docker-compose/linux-runners.yml up --scale gh-runner=5 -d

# Scale build runners
docker-compose -f docker-compose/linux-runners.yml up --scale gh-build-runner=3 -d
```

#### Using Multiple Services

```yaml
services:
  runner-1:
    environment:
      - RUNNER_NAME=runner-1
      - RUNNER_LABELS=linux,action

  runner-2:
    environment:
      - RUNNER_NAME=runner-2
      - RUNNER_LABELS=linux,action

  runner-3:
    environment:
      - RUNNER_NAME=runner-3
      - RUNNER_LABELS=linux,action
```

### Auto-Scaling Considerations

For production environments, consider:

1. **Load Balancing**: Use multiple runners for parallel jobs
2. **Queue Management**: Monitor job queue and scale accordingly
3. **Resource Monitoring**: Track CPU/memory usage
4. **Cost Optimization**: Scale down during off-hours

## Production Configuration

### Environment-Specific Configurations

#### Development

```bash
# .env.dev
GITHUB_TOKEN=dev_token
GITHUB_REPOSITORY=dev-org/dev-repo
RUNNER_NAME=dev-runner-1
RUNNER_LABELS=linux,action,dev
CLEANUP_EXISTING=true
FORCE_RECONFIGURE=true
```

#### Staging

```bash
# .env.staging
GITHUB_TOKEN=staging_token
GITHUB_REPOSITORY=staging-org/staging-repo
RUNNER_NAME=staging-runner-1
RUNNER_LABELS=linux,action,staging
CLEANUP_EXISTING=false
FORCE_RECONFIGURE=false
```

#### Production

```bash
# .env.production
GITHUB_TOKEN=prod_token
GITHUB_REPOSITORY=prod-org/prod-repo
RUNNER_NAME=prod-runner-1
RUNNER_LABELS=linux,action,production
CLEANUP_EXISTING=false
FORCE_RECONFIGURE=false
RUNNER_GROUP=production
```

### Resource Allocation Strategy

```yaml
# docker-compose/production.yml
services:
  gh-runner:
    deploy:
      resources:
        reservations:
          cpus: '1.0'
          memory: 2G
        limits:
          cpus: '2.0'
          memory: 4G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
```

## Security Configuration

### Restricted Network Access

```yaml
services:
  gh-runner:
    networks:
      - github-runners
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - DAC_OVERRIDE
    read_only: true
    tmpfs:
      - /tmp
```

### Secret Management

```bash
# Using Docker Secrets (swarm)
echo "ghp_xxxxxxxxxxxx" | docker secret create github_token -

# Using Docker Compose with secrets
docker-compose -f docker-compose/linux-runners.yml --env-file .env up -d
```

### File Permissions

```yaml
services:
  gh-runner:
    volumes:
      # Mount with specific permissions
      - type: volume
        source: runner-data
        target: /actions-runner
        volume:
          nocopy: true
```

## Troubleshooting Configuration

### Common Configuration Issues

#### Issue: Token Permissions

**Symptom**: `403 Forbidden` when generating runner token

**Solution**:
```bash
# Check token permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# Verify repository access
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/owner/repo
```

#### Issue: Invalid Repository Format

**Symptom**: `Invalid repository format` error

**Solution**:
```bash
# Correct format
export GITHUB_REPOSITORY=owner/repo

# Incorrect (will fail)
export GITHUB_REPOSITORY=https://github.com/owner/repo
export GITHUB_REPOSITORY=owner
```

#### Issue: Runner Already Exists

**Symptom**: `A runner with name X already exists`

**Solution**:
```bash
# Option 1: Remove existing runner from GitHub UI
# Option 2: Use different runner name
export RUNNER_NAME=unique-name-$(date +%s)

# Option 3: Enable cleanup
export CLEANUP_EXISTING=true
```

### Debug Mode

Enable verbose logging:

```bash
docker run -d \
  --name github-action-runner \
  -e GITHUB_TOKEN=... \
  -e GITHUB_REPOSITORY=... \
  -e RUNNER_NAME=debug-runner \
  -e CLEANUP_EXISTING=true \
  -e FORCE_RECONFIGURE=true \
  gh-runner:linux-action
```

Check logs:
```bash
docker logs -f github-action-runner
```

## Advanced Customization

### Custom Entrypoint Script

Create custom entrypoint for specific needs:

```bash
# custom-entrypoint.sh
#!/bin/bash
set -e

# Pre-start hook
echo "Running pre-start hook..."
# Add custom initialization here

# Call original entrypoint
exec /entrypoint.sh "$@"
```

Use in Dockerfile:
```dockerfile
COPY custom-entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh
ENTRYPOINT ["/custom-entrypoint.sh"]
```

### Environment Variable Precedence

Variables are resolved in this order:
1. Docker Compose `environment` section
2. `.env` file (if using `--env-file`)
3. Shell environment variables
4. Default values in Dockerfile

Example:
```bash
# Shell: highest priority
export GITHUB_TOKEN=shell_token

# .env file: medium priority
GITHUB_TOKEN=env_file_token

# Dockerfile default: lowest priority
ENV GITHUB_TOKEN=default_token
```

## CI/CD Pipeline Configuration

### GitHub Actions Workflow

```yaml
name: Deploy Self-Hosted Runners
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy Runners
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_REPOSITORY: ${{ github.repository }}
        run: |
          if [ "${{ github.event.inputs.environment }}" = "production" ]; then
            export GITHUB_TOKEN=${{ secrets.PRODUCTION_GITHUB_TOKEN }}
            export GITHUB_REPOSITORY=${{ secrets.PRODUCTION_REPOSITORY }}
            export RUNNER_LABELS=linux,action,production
            export RUNNER_GROUP=production
          fi

          docker-compose -f docker-compose/linux-runners.yml up -d
```

### Secrets Management

```bash
# Create .env file from secrets
cat > .env << EOF
GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
GITHUB_REPOSITORY=${{ github.repository }}
RUNNER_NAME=${{ runner.name }}
RUNNER_LABELS=linux,action
EOF

# Deploy
docker-compose -f docker-compose/linux-runners.yml --env-file .env up -d
```

## Monitoring Configuration

### Health Check Configuration

```yaml
services:
  gh-runner:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Logging Configuration

```yaml
services:
  gh-runner:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "{{.Name}}"
```

### Metrics Collection

```yaml
services:
  gh-runner:
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=8080"
      - "prometheus.io/path=/metrics"
```

## Reference

### Configuration Matrix

| Parameter | Action Runner | Build Runner | Required | Default |
|-----------|---------------|--------------|----------|---------|
| GITHUB_TOKEN | ✓ | ✓ | Yes | - |
| GITHUB_REPOSITORY | ✓ | ✓ | Yes | - |
| RUNNER_NAME | ✓ | ✓ | No | Hostname |
| RUNNER_LABELS | ✓ | ✓ | No | Runner-specific |
| RUNNER_GROUP | ✓ | ✓ | No | default |
| WORK_DIR | ✓ | ✓ | No | /actions-runner |
| CLEANUP_EXISTING | ✓ | ✓ | No | false |
| FORCE_RECONFIGURE | ✓ | ✓ | No | false |
| INSTALL_DOCKER | ✓ | ✓ | No | false/true |

### Common Patterns

#### Pattern 1: Single Instance

```bash
export GITHUB_TOKEN=token
export GITHUB_REPOSITORY=owner/repo
docker-compose -f docker-compose/linux-runners.yml up gh-runner -d
```

#### Pattern 2: Multi-Environment

```bash
# Development
export GITHUB_TOKEN=dev_token
export GITHUB_REPOSITORY=dev/repo
export RUNNER_LABELS=linux,action,dev
docker-compose -f docker-compose/linux-runners.yml up gh-runner -d

# Production
export GITHUB_TOKEN=prod_token
export GITHUB_REPOSITORY=prod/repo
export RUNNER_LABELS=linux,action,production
export RUNNER_GROUP=production
docker-compose -f docker-compose/linux-runners.yml up gh-runner -d
```

#### Pattern 3: Mixed Runner Types

```bash
export GITHUB_TOKEN=token
export GITHUB_REPOSITORY=owner/repo

# Start both types
docker-compose -f docker-compose/linux-runners.yml up gh-runner gh-build-runner -d
```

#### Pattern 4: Horizontal Scaling

```bash
export GITHUB_TOKEN=token
export GITHUB_REPOSITORY=owner/repo

# Scale to 5 action runners
docker-compose -f docker-compose/linux-runners.yml up --scale gh-runner=5 -d
```

### Validation Commands

```bash
# Check configuration
docker exec github-action-runner cat /actions-runner/.runner

# Test GitHub connectivity
docker exec github-action-runner curl -s https://api.github.com

# Verify environment variables
docker exec github-action-runner env | grep GITHUB_

# Check runner status
docker inspect github-action-runner --format='{{.State.Health.Status}}'
```

## Next Steps

- Review [Security Best Practices](./security.md)
- See [Action Runner Documentation](./action-runner.md)
- Check [Build Runner Documentation](./build-runner.md)
- Review [Main README](./README.md)
