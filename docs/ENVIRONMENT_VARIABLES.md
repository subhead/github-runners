# Environment Variables Documentation

This document provides detailed explanations of all environment variables used to configure GitHub Actions self-hosted runners.

## Quick Start

```bash
# 1. Copy the template
cp .env.template .env

# 2. Edit with your values
# (Use nano, vim, or any editor)

# 3. Deploy
docker-compose -f docker-compose/linux-python.yml up -d
```

## Template File

The `.env.template` file contains:
- All available environment variables
- Detailed explanations for each
- Example configurations
- Security best practices
- Troubleshooting tips

## Key Variables

### Required

| Variable | Purpose | Example |
|----------|---------|---------|
| `GITHUB_TOKEN` | GitHub authentication token | `ghp_aBc...` |
| `GITHUB_OWNER` | Organization name (org runners) | `my-org` |
| `GITHUB_REPOSITORY` | Repository name (repo runners) | `my-org/repo` |

### Optional (Python-Specific)

| Variable | Purpose | Recommended Value |
|----------|---------|-------------------|
| `RUNNER_NAME` | Unique runner identifier | `org-python-runner-01` |
| `RUNNER_LABELS` | Workflow targeting labels | `linux,python,ml` |
| `CPU_LIMIT` | CPU cores allocation | `3.0` |
| `MEMORY_LIMIT` | Memory limit | `6g` |
| `PYTHONUNBUFFERED` | Real-time logs | `1` |
| `PYTHONDONTWRITEBYTECODE` | No bytecode files | `1` |
| `PIP_NO_CACHE_DIR` | Pip caching | `off` |

## Examples

### Organization Runner (Recommended)
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_OWNER=my-org
RUNNER_NAME=org-python-runner
RUNNER_LABELS=linux,python,ml,production
RUNNER_GROUP=python-team
CPU_LIMIT=3.0
MEMORY_LIMIT=6g
```

### Repository-Specific Runner
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_REPOSITORY=my-org/my-repo
RUNNER_NAME=repo-runner
RUNNER_LABELS=linux,python,fastapi
```

### ML/Data Science Runner
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_OWNER=data-team-org
RUNNER_NAME=ml-runner
RUNNER_LABELS=linux,python,ml,ai,data-science
CPU_LIMIT=4.0
MEMORY_LIMIT=16g
VENV_PATH=/home/runner/.venv-ml
```

## Security Best Practices

1. **Use fine-grained tokens** with minimal permissions
2. **Never commit .env files** to version control
3. **Set file permissions**: `chmod 600 .env`
4. **Rotate tokens** every 90 days
5. **Use Docker secrets** for production

## Common Issues

| Issue | Solution |
|-------|----------|
| Token not working | Check scopes and expiration |
| Runner not appearing | Verify token permissions |
| Out of memory | Increase `MEMORY_LIMIT` |
| Slow builds | Enable pip cache (`PIP_NO_CACHE_DIR=off`) |

## For More Details

See README.md → "🔧 Environment Variables" section for:
- Complete variable reference
- Default values
- Usage examples
- Troubleshooting
- Deployment commands
