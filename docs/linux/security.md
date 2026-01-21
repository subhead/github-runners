# Security Best Practices

This document provides comprehensive security guidelines for deploying and managing self-hosted GitHub Actions runners in production environments.

## Overview

Self-hosted GitHub Actions runners introduce security considerations that differ from GitHub-hosted runners. This guide covers:

1. **Token Management** - Secure authentication
2. **Container Security** - Runner isolation
3. **Docker Socket Security** - Docker-in-Docker risks
4. **Network Security** - Network isolation
5. **Host Security** - Infrastructure hardening
6. **Operational Security** - Ongoing maintenance

## Threat Model

### Common Attack Vectors

1. **Token Theft** - Unauthorized access to GitHub repositories
2. **Container Breakout** - Escaping container isolation
3. **Docker Socket Abuse** - Compromising host Docker daemon
4. **Supply Chain Attacks** - Malicious dependencies in build
5. **Network Interception** - Man-in-the-middle attacks
6. **Privilege Escalation** - Gaining elevated permissions

### Impact Assessment

| Risk | Likelihood | Impact | Mitigation Priority |
|------|------------|--------|---------------------|
| Token Compromise | Medium | Critical | **HIGH** |
| Container Breakout | Low | High | **HIGH** |
| Docker Socket Abuse | Medium | Critical | **CRITICAL** |
| Supply Chain Attack | Low | High | **MEDIUM** |
| Network Attack | Low | Medium | **MEDIUM** |
| Privilege Escalation | Low | High | **HIGH** |

## Token Security

### Token Creation

#### Classic Personal Access Tokens

**Recommended Permissions**:
- `repo` scope (full repository access)
- `admin:org` (for organization runners)
- Fine-grained tokens preferred

#### Fine-Grained Tokens (Recommended)

**Repository Access**:
- `Contents: Read and write`
- `Actions: Read and write`
- `Metadata: Read only`

**Organization Access**:
- `Members: Read only`
- `Organization: Read only`

**Example Setup**:
```bash
# GitHub UI: Settings > Developer Settings > Personal Access Tokens > Fine-grained tokens
# 1. Select repository access
# 2. Choose permissions
# 3. Set expiration (90 days recommended)
# 4. Generate token
```

### Token Storage

#### GitHub Secrets (Recommended)

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Runners
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_RUNNER_TOKEN }}
        run: |
          docker-compose up -d
```

#### Environment Variables (Avoid in CI)

```bash
# ❌ AVOID - Logged in shell history
export GITHUB_TOKEN=ghp_xxxxxxxx

# ✅ BETTER - Use .env file (not committed)
# .env file (add to .gitignore)
GITHUB_TOKEN=ghp_xxxxxxxx
```

#### Docker Secrets (Swarm)

```bash
# Create secret
echo "ghp_xxxxxxxx" | docker secret create github_runner_token -

# Use in compose
secrets:
  github_runner_token:
    external: true

services:
  gh-runner:
    secrets:
      - github_runner_token
    environment:
      - GITHUB_TOKEN_FILE=/run/secrets/github_runner_token
```

### Token Rotation

#### Rotation Schedule
- **Development**: 90 days
- **Production**: 30 days
- **High-security**: 7 days

#### Rotation Process

```bash
# 1. Generate new token
# GitHub UI: Create new token

# 2. Update secrets
echo "NEW_TOKEN" | docker secret create github_runner_token_new -

# 3. Redeploy with new token
docker-compose up -d --force-recreate

# 4. Verify new runner registration
# GitHub: Settings > Actions > Runners

# 5. Revoke old token
# GitHub UI: Revoke old token
```

### Token Monitoring

#### Audit Token Usage

```bash
# Check which tokens are in use
grep -r GITHUB_TOKEN /path/to/your/configs/

# Monitor GitHub API usage
# GitHub: Settings > Developer Settings > Personal Access Tokens
```

#### Detect Token Exposure

```bash
# Search for tokens in logs (example)
docker logs github-action-runner 2>&1 | grep -i "ghp_"

# Check environment variables inside container
docker exec github-action-runner env | grep GITHUB_
```

## Container Security

### Non-Root User

#### Verify Non-Root Execution

```bash
# Check running user
docker exec github-action-runner id

# Should output: uid=1001(runner) gid=1001(runner) groups=1001(runner)

# Check processes
docker exec github-action-runner ps aux
```

#### Dockerfile Configuration

```dockerfile
# ✅ CORRECT - Non-root user
RUN useradd -m -u 1001 -s /bin/bash runner
USER runner

# ❌ INCORRECT - Running as root
# (No USER directive)
```

### Read-Only Root Filesystem

#### Enable Read-Only Mode

```yaml
services:
  gh-runner:
    read_only: true
    tmpfs:
      - /tmp
      - /var/tmp
      - /run
```

#### Test Read-Only

```bash
# Try to create file in root filesystem
docker exec github-action-runner touch /test 2>&1

# Should fail: "Read-only file system"
# Temporary files should work in /tmp
docker exec github-action-runner touch /tmp/test
```

### Resource Limits

#### Memory Limits

```yaml
services:
  gh-runner:
    mem_limit: 2g
    memswap_limit: 2g  # No swap
```

```bash
# Test memory limit
docker run -it --rm -m 512m ubuntu:22.04 /bin/bash
# Inside: stress --vm 2 --vm-bytes 1G
# Should be OOM killed
```

#### CPU Limits

```yaml
services:
  gh-runner:
    cpus: '1.0'
    cpu_shares: 512
```

#### PIDs Limit

```yaml
services:
  gh-runner:
    pids_limit: 200  # Prevent fork bombs
```

### Security Options

```yaml
services:
  gh-runner:
    security_opt:
      - no-new-privileges:true  # Prevent privilege escalation
    cap_drop:
      - ALL  # Drop all capabilities
    cap_add:
      - CHOWN   # Only add necessary capabilities
      - SETGID
      - SETUID
      - DAC_OVERRIDE
```

### AppArmor/SELinux

#### AppArmor Profile

```bash
# Check if AppArmor is active
aa-status

# Run container with custom profile
docker run --security-opt apparmor=docker-gh-runner ...
```

#### SELinux Context

```bash
# Run with SELinux context
docker run --security-opt label=type:gh_runner_t ...
```

## Docker Socket Security

### Risk Assessment

**Mounting `/var/run/docker.sock` grants**:
- Full access to host Docker daemon
- Ability to create privileged containers
- Access to all containers on host
- Potential host system compromise

**Attack Scenarios**:
1. **Container Escape**: Malicious process escapes to host
2. **Container Creation**: Attacker creates new containers
3. **Container Manipulation**: Stops/modifies existing containers
4. **Image Manipulation**: Modifies or pulls malicious images

### Mitigation Strategies

#### 1. Read-Only Mount (Minimum)

```yaml
# docker-compose.yml
services:
  gh-runner:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only
```

#### 2. Socket Proxy (Recommended)

Use Docker socket proxy to limit API access:

```yaml
# docker-compose.yml
services:
  # Docker socket proxy
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    environment:
      - CONTAINERS=1
      - IMAGES=1
      - BUILD=1
      - POST=1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - github-runners

  # Runner using proxy
  gh-runner:
    environment:
      - DOCKER_HOST=tcp://docker-socket-proxy:2375
    networks:
      - github-runners
```

#### 3. Rootless Docker (Best)

Run Docker rootless on host:

```bash
# On host: Install rootless Docker
dockerd-rootless-setuptool.sh install

# Configure systemd
systemctl --user enable docker
systemctl --user start docker

# Run container with rootless socket
docker run -v /run/user/1000/docker.sock:/var/run/docker.sock ...
```

#### 4. Podman Alternative

Use Podman for rootless containers:

```bash
# On host: Install Podman
# Run with Podman socket
docker run -v /run/user/1000/podman/podman.sock:/var/run/docker.sock ...
```

### Monitoring Docker Socket Usage

```bash
# Monitor which containers access docker socket
docker inspect $(docker ps -q) | jq -r '.[] | select(.Mounts[]?.Source == "/var/run/docker.sock") | .Name'

# Audit docker daemon logs
sudo journalctl -u docker.service -f
```

## Network Security

### Isolation Strategies

#### 1. Dedicated Docker Network

```yaml
services:
  gh-runner:
    networks:
      - github-runners-private

networks:
  github-runners-private:
    driver: bridge
    internal: true  # No external access
    # Note: May need external access for GitHub API
```

#### 2. Firewall Rules

```bash
# Example: iptables rules
# Allow only GitHub API access
iptables -A OUTPUT -p tcp --dport 443 -d api.github.com -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -d github.com -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j DROP
```

#### 3. Network Policies (Kubernetes)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: github-runner-policy
spec:
  podSelector:
    matchLabels:
      app: github-runner
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 140.82.112.0/20  # GitHub API IPs
    ports:
    - protocol: TCP
      port: 443
```

### DNS Security

#### Use Secure DNS

```yaml
services:
  gh-runner:
    dns:
      - 1.1.1.1
      - 8.8.8.8
    dns_search:
      - .
```

#### DNS over HTTPS

```yaml
# docker-compose.yml
services:
  gh-runner:
    dns: 127.0.0.1  # Local DNS resolver with DoH
    extra_hosts:
      - "api.github.com:140.82.112.6"
```

### VPN/Proxy Configuration

```yaml
services:
  gh-runner:
    environment:
      - HTTP_PROXY=http://proxy.company.com:3128
      - HTTPS_PROXY=http://proxy.company.com:3128
      - NO_PROXY=localhost,127.0.0.1,.internal
    # OR use network_mode for VPN
    # network_mode: "host"
```

## Host Security

### Host Requirements

#### 1. Minimal Host Installation

```bash
# Install minimal Ubuntu Server
# - No GUI
# - Only essential services
# - Regular security updates

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### 2. Firewall Configuration

```bash
# UFW example
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 2375/tcp  # Only if Docker API needed
sudo ufw enable
```

#### 3. SSH Hardening

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers your-user
```

### Docker Daemon Security

#### Secure Configuration

```bash
# /etc/docker/daemon.json
{
  "tls": true,
  "tlsverify": true,
  "tlscacert": "/etc/docker/ca.pem",
  "tlscert": "/etc/docker/server.pem",
  "tlskey": "/etc/docker/server-key.pem",
  "userland-proxy": false,
  "live-restore": true,
  "no-new-privileges": true
}
```

#### Enable User Namespaces

```bash
# /etc/docker/daemon.json
{
  "userns-remap": "default"
}

# Restart Docker
sudo systemctl restart docker
```

### Monitoring and Logging

#### Centralized Logging

```yaml
services:
  gh-runner:
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://logs.company.com:514"
        tag: "github-runner"
```

#### Audit Docker Events

```bash
# Monitor container starts
docker events --filter 'event=start'

# Monitor image pulls
docker events --filter 'event=pull'

# Log to file
docker events > /var/log/docker-events.log &
```

## Operational Security

### Secrets Management

#### 1. Use Docker Secrets (Swarm)

```bash
# Create secrets
echo "ghp_xxxxxxxx" | docker secret create github_token -
echo "owner/repo" | docker secret create github_repo -

# Use in compose
version: '3.8'
services:
  gh-runner:
    secrets:
      - github_token
      - github_repo
    environment:
      - GITHUB_TOKEN_FILE=/run/secrets/github_token
```

#### 2. Vault Integration

```yaml
services:
  vault-agent:
    image: hashicorp/vault
    environment:
      VAULT_ADDR: https://vault.company.com
    volumes:
      - ./vault-policy.hcl:/vault/config/vault-policy.hcl

  gh-runner:
    environment:
      - VAULT_ADDR=https://vault.company.com
    entrypoint: ["vault-agent", "run"]
```

### Secure Deployment

#### 1. Infrastructure as Code

```bash
# Use GitOps for configuration
git clone git@github.com:company/infrastructure.git
cd infrastructure/github-runners

# Deploy from version-controlled configs
docker-compose -f production.yml up -d

# Any changes must go through PR review
```

#### 2. Immutable Infrastructure

```bash
# Don't modify running containers
# Instead, rebuild and redeploy

# Update runner version
docker-compose build --no-cache
docker-compose up -d --force-recreate
```

### Security Updates

#### Regular Update Schedule

```bash
# Weekly: Update base images
docker pull ubuntu:22.04
docker-compose build --no-cache

# Monthly: Update runner version
# Check: https://github.com/actions/runner/releases

# Daily: Apply security patches
sudo apt update && sudo apt upgrade -y
sudo systemctl restart docker
```

#### Automated Updates

```yaml
# docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400  # Check daily
```

### Security Scanning

#### 1. Image Scanning

```bash
# Install Docker Scan (Snyk)
docker scan gh-runner:linux-build

# Or use Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image gh-runner:linux-build
```

#### 2. Container Runtime Security

```bash
# Install Falco for runtime monitoring
helm install falco falco/falco

# Monitor container behavior
kubectl logs -f falco-pod
```

#### 3. Vulnerability Database

```bash
# Check for known vulnerabilities
curl -s https://raw.githubusercontent.com/aquasecurity/trivy-db/main/trivy.db > trivy.db
trivy db --download-db-only
```

## Compliance and Auditing

### Audit Logging

#### Enable Docker Audit Log

```bash
# /etc/docker/daemon.json
{
  "log-driver": "syslog",
  "log-opts": {
    "syslog-address": "tcp://logs.company.com:514",
    "tag": "docker"
  }
}
```

#### Container Event Logging

```bash
# Log all container events
docker events --filter 'container=github-action-runner' \
  --format '{{json .}}' > /var/log/docker-runner-events.log &
```

### Compliance Checks

```bash
# CIS Docker Benchmark
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  docker/docker-bench-security

# Kubernetes CIS benchmark
kube-bench --version cis-1.8
```

### Documentation

Maintain security documentation:

```bash
# security.md
- Token rotation schedule
- Incident response procedure
- Approved base images
- Network diagrams
- Access control lists
```

## Incident Response

### Token Compromise

**Immediate Actions**:
```bash
# 1. Revoke compromised token
# GitHub UI: Settings > Developer Settings > Personal Access Tokens

# 2. Stop all runners
docker-compose -f docker-compose/linux-runners.yml down

# 3. Rotate all tokens
# Update secrets and redeploy

# 4. Audit logs for unauthorized access
# Check GitHub: Settings > Security > Audit Log
```

### Container Breakout

**Detection**:
```bash
# Monitor for suspicious processes
docker exec github-action-runner ps aux

# Check for unauthorized network connections
docker exec github-action-runner netstat -tulpn
```

**Containment**:
```bash
# 1. Stop compromised container
docker stop github-action-runner

# 2. Remove container
docker rm github-action-runner

# 3. Remove image
docker rmi gh-runner:linux-action

# 4. Check host for indicators
# Review: /var/log/auth.log, /var/log/syslog
```

### Docker Socket Abuse

**Signs**:
- Unexpected containers running
- New images pulled
- Modified existing containers
- Network connections to unknown hosts

**Response**:
```bash
# 1. Stop Docker daemon
sudo systemctl stop docker

# 2. Identify malicious containers
sudo docker ps -a

# 3. Remove malicious containers/images
sudo docker rm $(docker ps -aq)
sudo docker rmi $(docker images -q)

# 4. Investigate and rebuild host
# Consider host reinstallation
```

## Best Practices Summary

### ✅ DO

1. **Use fine-grained personal access tokens**
2. **Mount Docker socket as read-only**
3. **Run containers as non-root user**
4. **Implement resource limits**
5. **Use dedicated networks**
6. **Enable security scanning**
7. **Rotate tokens regularly**
8. **Monitor logs and events**
9. **Keep base images updated**
10. **Use secrets management**

### ❌ DON'T

1. **Don't use root user in containers**
2. **Don't mount Docker socket read-write**
3. **Don't use privileged containers**
4. **Don't commit tokens to repositories**
5. **Don't run on shared hosts**
6. **Don't skip security updates**
7. **Don't disable security features**
8. **Don't use default network bridge**
9. **Don't run without resource limits**
10. **Don't ignore audit logs**

## Security Checklist

### Pre-Deployment

- [ ] Use fine-grained PAT with minimal permissions
- [ ] Set token expiration (90 days)
- [ ] Store token in GitHub Secrets
- [ ] Review Docker Compose for security issues
- [ ] Configure resource limits
- [ ] Enable read-only root filesystem
- [ ] Verify non-root user
- [ ] Set up dedicated network
- [ ] Configure firewall rules
- [ ] Plan update schedule

### Runtime

- [ ] Verify container runs as non-root
- [ ] Check resource limits are enforced
- [ ] Monitor container health
- [ ] Review logs daily
- [ ] Scan images weekly
- [ ] Check for security updates
- [ ] Rotate tokens on schedule
- [ ] Audit network connections
- [ ] Review GitHub audit logs
- [ ] Test backup/recovery

### Maintenance

- [ ] Update base images monthly
- [ ] Review and rotate tokens
- [ ] Update security patches
- [ ] Run CIS benchmarks
- [ ] Review access controls
- [ ] Update documentation
- [ ] Conduct security audit
- [ ] Test incident response
- [ ] Review backup integrity
- [ ] Assess cost vs security

## Security Resources

### Tools

- **Docker Bench Security**: CIS compliance checking
- **Trivy**: Vulnerability scanning
- **Falco**: Runtime security monitoring
- **Snyk**: Dependency and container scanning
- **Clair**: Container vulnerability analysis
- **Anchore**: Policy-based scanning

### References

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)

## Conclusion

Security is a continuous process, not a one-time setup. Regularly review and update your security configuration as new threats emerge and best practices evolve.

**Key Takeaways**:
1. **Assume compromise** - Implement defense in depth
2. **Minimal permissions** - Least privilege principle
3. **Continuous monitoring** - Detect anomalies quickly
4. **Regular updates** - Stay current with patches
5. **Incident readiness** - Have a response plan

For questions or security issues, contact your security team or raise an issue in the repository.
