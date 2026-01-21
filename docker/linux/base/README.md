# Linux Base Image - GitHub Actions Runner

This is the minimal base image for the modular Linux GitHub Actions runners. It provides the core foundation for all runner types in the modular architecture.

## Overview

- **Base Image Size**: ~300MB (Ubuntu 22.04 minimal + GitHub Actions runner)
- **Dockerfile**: `Dockerfile.base`
- **Base OS**: Ubuntu 22.04 LTS (Jammy Jellyfish)

## What's Included

### Core Components
- **Ubuntu 22.04**: Minimal installation
- **GitHub Actions Runner**: Latest stable version (v2.331.0)
- **Essential System Tools**: curl, git, tar, zip, unzip, jq
- **User Management**: Runner user with appropriate permissions

### Security
- Non-root user (`runner`, UID 1001) for container execution
- Minimal attack surface (only essential packages)
- Automatic security updates via Ubuntu base image

## Building the Base Image

### Command
```bash
# Build the base image
docker build -f docker/linux/base/Dockerfile.base \
    -t gh-runner:linux-base \
    .

# Build with custom runner version
docker build -f docker/linux/base/Dockerfile.base \
    --build-arg RUNNER_VERSION=2.31.0 \
    -t gh-runner:linux-base:custom \
    .
```

### Customization Options
- `RUNNER_VERSION`: GitHub Actions runner version (default: 2.331.0)

## Size Comparison

| Image Type | Size (Approx) | Layers | Build Time |
|------------|---------------|--------|------------|
| Ubuntu 22.04 base | ~75MB | 1 | - |
| + Core tools | ~150MB | 2 | ~30s |
| + GitHub Runner | ~250MB | 3 | ~45s |
| **Total Base** | **~300MB** | **3** | **~2 min** |

## Usage

### Basic Runner Configuration
```bash
# Run the base image (will show help)
docker run --rm gh-runner:linux-base

# Start a configured runner
docker run -d \
    -e GITHUB_TOKEN=ghp_xxxxxxxx \
    -e GITHUB_REPOSITORY=owner/repo \
    -e RUNNER_NAME=my-linux-runner \
    --name linux-runner \
    gh-runner:linux-base
```

### Environment Variables

#### Required
- `GITHUB_TOKEN`: GitHub personal access token with `repo` scope (for repo runners) or `org:write` scope (for organization runners)
- `GITHUB_REPOSITORY`: Repository in `owner/repo` format (for repository runners)
- `GITHUB_OWNER`: Organization name (for organization runners, if `GITHUB_REPOSITORY` not set)
- `RUNNER_NAME`: Unique identifier for this runner instance

#### Optional
- `RUNNER_LABELS`: Comma-separated labels for runner selection (default: `linux`)
- `RUNNER_GROUP`: Runner group name (default: `Default`)
- `RUNNER_WORKDIR`: Working directory for runner (default: `_work`)
- `RUNNER_AS_ROOT`: Run runner as root (`true`/`false`, default: `false`)
- `RUNNER_REPLACE_EXISTING`: Replace existing runner with same name (`true`/`false`, default: `false`)

## Extending the Base Image

The base image is designed to be extended by language pack images. See the [Language Packs documentation](../language-packs/README.md) for details.

### Example Extension
```dockerfile
# FROM gh-runner:linux-base AS final
#
# # Add Python toolchain
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     python3 python3-pip python3-venv \
#     && rm -rf /var/lib/apt/lists/*
```

## Architecture

### Directory Structure
```
docker/linux/base/
├── Dockerfile.base     # Main Dockerfile
└── README.md          # This documentation
```

### Entrypoint Script
The base image uses a shared entrypoint located at `docker/linux/entrypoint/entrypoint.sh`. This script:
1. Validates environment variables
2. Configures the GitHub Actions runner
3. Handles graceful shutdown
4. Cleans up runner registration on exit

## Testing

### Verify Base Image
```bash
# Test basic functionality
docker run --rm gh-runner:linux-base --version

# Test git
docker run --rm gh-runner:linux-base git --version

# Test curl
docker run --rm gh-runner:linux-base curl --version
```

### Verify GitHub Actions Runner
```bash
# Start a test runner (requires valid GitHub token)
docker run --rm \
    -e GITHUB_TOKEN=${GITHUB_TOKEN} \
    -e GITHUB_REPOSITORY=${GITHUB_REPOSITORY} \
    -e RUNNER_NAME=test-runner \
    gh-runner:linux-base --help
```

## Performance

### Build Performance
- **First build**: ~2-3 minutes
- **Subsequent builds** (with cache): ~10-30 seconds

### Runtime Performance
- **Startup time**: ~5-10 seconds (configuration + registration)
- **Memory usage**: ~50-100MB (base) + language-specific overhead
- **CPU usage**: Minimal at idle, scales with job execution

## Security Considerations

### Best Practices
1. **Use personal access tokens** with minimal required scopes
2. **Rotate tokens** regularly (recommended: every 90 days)
3. **Use environment secrets** for sensitive data in production
4. **Limit network access** where possible
5. **Monitor runner activity** via GitHub audit logs

### Known Limitations
- Base image has no build tools (language-specific compilers, SDKs)
- Requires extension with language packs for actual CI/CD workloads
- Docker socket access requires explicit mount (security consideration)

## Troubleshooting

### Common Issues

**1. "Failed to generate registration token"**
- Check GITHUB_TOKEN permissions (repo or org scope)
- Verify token hasn't expired
- Ensure token has access to the repository/organization

**2. "Runner configuration failed"**
- Verify RUNNER_NAME is unique
- Check network connectivity to GitHub
- Ensure required environment variables are set

**3. "Runner disconnects immediately"**
- Check runner version compatibility
- Verify network stability
- Review GitHub Actions service status

**4. "Permission denied" errors**
- Ensure container runs as non-root user (default)
- Check volume mount permissions
- Verify file system permissions

## Integration

### With Language Packs
```dockerfile
# Example: Extend base with Python support
FROM gh-runner:linux-base AS final

COPY --from=gh-runner:python-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:python-pack /usr/include/ /usr/include/
COPY --from=gh-runner:python-pack /usr/lib/ /usr/lib/
```

### With Docker Compose
```yaml
# docker-compose/example.yml
version: '3.8'
services:
  runner:
    build:
      context: .
      dockerfile: docker/linux/base/Dockerfile.base
    image: gh-runner:linux-base
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - RUNNER_NAME=${RUNNER_NAME}
```

## Maintenance

### Updating
1. Update `RUNNER_VERSION` in Dockerfile for new runner versions
2. Update base Ubuntu image version when new LTS releases
3. Rebuild and test before deploying to production

### Monitoring
- Check runner status in GitHub Actions UI
- Monitor container logs: `docker logs <runner-name>`
- Set up alerts for runner disconnections

## Related Documentation

- [Language Packs](../language-packs/README.md) - Adding language-specific tools
- [Composite Images](../composite/README.md) - Pre-built runner combinations
- [Docker Compose Configurations](../../../docker-compose/linux-base.yml) - Deployment examples
- [Migration Guide](../../../docs/linux-modular/migration.md) - Moving from monolithic to modular

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-21 | Initial release |

## License

This project is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.
