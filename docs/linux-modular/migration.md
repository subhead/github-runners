# Migration Guide: From Monolithic to Modular Runners

This guide provides a step-by-step migration path from the traditional monolithic GitHub Actions runner to the new modular architecture.

## Overview

### Before: Monolithic Approach

**Characteristics:**
- Single Dockerfile: 2.5GB image
- Includes ALL languages: Python, C++, Node.js, Java, Go, Rust, .NET, PHP, Ruby
- Build time: 5-8 minutes
- Cache efficiency: ~20%
- Storage cost: High
- Update time: 10-15 minutes (full rebuild)

**Typical Dockerfile:**
```dockerfile
FROM ubuntu:22.04
# Install ALL the tools...
RUN apt-get install -y python3 python3-pip gcc g++ nodejs npm go...
# 2.5GB image
```

### After: Modular Approach

**Characteristics:**
- Base image: 300MB
- Language packs: 50-300MB each
- Build time: 1-3 minutes (per image)
- Cache efficiency: 90-95%
- Storage cost: Low (only what you use)
- Update time: 2-5 minutes (per component)

**Structure:**
```
Base (300MB) + Language Packs + Composite Images
```

## Migration Strategy

### Phase 1: Assessment (1-2 days)

#### Step 1: Audit Current Usage

Analyze which languages and tools are actually used:

```bash
# Find all workflow files
find .github/workflows -name "*.yml" -o -name "*.yaml"

# Check runner labels
grep -r "runs-on:" .github/workflows/ | sort | uniq

# Count language usage
grep -r "python" .github/workflows/ | wc -l
grep -r "cpp\|gcc\|clang" .github/workflows/ | wc -l
grep -r "node\|npm" .github/workflows/ | wc -l
grep -r "go" .github/workflows/ | wc -l
```

**Sample Analysis Output:**
```bash
# Example analysis results
Language    Workflows    Percentage
--------    ---------    -----------
Python      45           50%
C++         20           22%
Node.js     15           17%
Go          10           11%

# Recommendation: Start with Python and C++ packs
```

#### Step 2: Map Workflows to Language Requirements

Create a mapping table:

| Workflow | Current Runner | Languages Needed | Required Tools |
|----------|---------------|------------------|----------------|
| `ci.yml` | full-runner | Python, C++ | python3, pip, gcc, cmake |
| `build-web.yml` | full-runner | Node.js, Go | node, npm, go |
| `test.yml` | full-runner | Python, C++ | python3, pytest, g++ |
| `docs.yml` | base-runner | - | - |

#### Step 3: Identify Optimization Opportunities

**Check for unnecessary tools:**
```bash
# Example workflow
jobs:
  build:
    runs-on: [self-hosted, linux, full]  # Uses ALL languages
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: make  # Only uses C++
```

**Optimization:** Switch to `cpp-only` runner (550MB vs 2.5GB)

### Phase 2: Deployment (1-2 days)

#### Step 1: Deploy New Runners (Parallel)

Keep existing monolith running, deploy new modular runners:

```bash
# Deploy C++ runner for C++ workflows
docker-compose -f docker-compose/linux-cpp.yml up -d

# Deploy Python runner for Python workflows
docker-compose -f docker-compose/linux-python.yml up -d

# Deploy base runner for simple tasks
docker-compose -f docker-compose/linux-base.yml up -d

# Keep old monolith runner running
# docker-compose -f docker-compose/linux-full.yml up -d
```

**Verify in GitHub:**
1. Go to Settings → Actions → Runners
2. Check that new runners appear (with appropriate labels)
3. Verify all runners are online and ready

#### Step 2: Create Runner Labels

**Runner Label Matrix:**

| Runner Type | GitHub Labels | Notes |
|-------------|---------------|-------|
| Base | `linux`, `base` | Minimal tasks |
| C++ Only | `linux`, `cpp`, `build` | C++ development |
| Python Only | `linux`, `python`, `ml` | Python/ML tasks |
| Web Stack | `linux`, `node`, `go`, `web` | Web development |
| Full Stack | `linux`, `full`, `all` | Legacy support |

**Example: GitHub Actions Workflow**
```yaml
# C++ workflow - use cpp runner
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]  # Updated label
    steps:
      - uses: actions/checkout@v3
      - name: Build with CMake
        run: cmake . && cmake --build .

# Python workflow - use python runner
jobs:
  test:
    runs-on: [self-hosted, linux, python]  # Updated label
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: pytest tests/
```

### Phase 3: Migration (1-2 weeks)

#### Step 1: Start with Low-Risk Workflows

**Tier 1: Simple, non-critical workflows**
- Documentation builds
- Linting/formatting
- Simple tests
- Background tasks

**Example Migration:**
```yaml
# Before (using full-runner)
jobs:
  lint:
    runs-on: [self-hosted, linux, full]
    steps:
      - name: Run linter
        run: eslint .

# After (using base-runner or web-runner)
jobs:
  lint:
    runs-on: [self-hosted, linux, base]  # or [self-hosted, linux, node]
    steps:
      - name: Run linter
        run: eslint .
```

#### Step 2: Migrate Core Workflows

**Tier 2: Critical build/test workflows**
- Main CI pipelines
- Build artifacts
- Unit tests
- Integration tests

**Example Migration:**
```yaml
# Before (using full-runner)
jobs:
  build:
    runs-on: [self-hosted, linux, full]
    steps:
      - uses: actions/checkout@v3
      - name: Configure
        run: ./configure
      - name: Build
        run: make
      - name: Test
        run: make test

# After (using cpp-only)
jobs:
  build:
    runs-on: [self-hosted, linux, cpp]  # Specific runner
    steps:
      - uses: actions/checkout@v3
      - name: Configure
        run: ./configure
      - name: Build
        run: make
      - name: Test
        run: make test
```

#### Step 3: Parallel Testing

Run both old and new runners simultaneously:

```yaml
# Test workflow for migration
jobs:
  test-old:
    runs-on: [self-hosted, linux, full]
    steps:
      - name: Run on old runner
        run: echo "Testing on old runner"

  test-new:
    runs-on: [self-hosted, linux, cpp]
    steps:
      - name: Run on new runner
        run: echo "Testing on new runner"

  # Compare results
  verify:
    runs-on: ubuntu-latest
    needs: [test-old, test-new]
    steps:
      - name: Verify both succeeded
        run: |
          echo "Old runner: ${{ needs.test-old.result }}"
          echo "New runner: ${{ needs.test-new.result }}"
```

#### Step 4: Monitor and Compare

**Track Metrics:**
```bash
# Monitor build times
# Old runner: ~8 minutes
# New runner: ~2 minutes

# Monitor resource usage
docker stats full-runner
docker stats cpp-runner

# Check success rates
# GitHub API: GET /repos/{owner}/{repo}/actions/runs
```

**Create Comparison Table:**

| Workflow | Old Runner | New Runner | Improvement |
|----------|-----------|------------|-------------|
| `ci-build` | 8m 30s | 2m 15s | 74% faster |
| `test-suite` | 12m 00s | 4m 30s | 63% faster |
| `lint` | 3m 00s | 1m 00s | 67% faster |
| **Average** | **7m 57s** | **2m 35s** | **68% faster** |

### Phase 4: Optimization (3-5 days)

#### Step 1: Fine-tune Resource Allocation

**Analyze resource usage patterns:**
```bash
# Check CPU usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}"

# Check memory usage
docker stats --format "table {{.Name}}\t{{.MemUsage}}"

# Check container logs for errors
docker logs cpp-runner | grep -i error
```

**Adjust Docker Compose:**
```yaml
# Based on actual usage, adjust resources
services:
  cpp-runner:
    deploy:
      resources:
        limits:
          cpus: '1.5'  # Adjust based on usage
          memory: 2G
```

#### Step 2: Optimize Build Caching

**Python Example:**
```yaml
# docker-compose/linux-python.yml
volumes:
  - ./data/python-pip-cache:/home/runner/.cache/pip  # Add cache volume
  - ./data/python-venv-cache:/home/runner/.venv      # Reuse venvs
```

**C++ Example:**
```yaml
# docker-compose/linux-cpp.yml
volumes:
  - ./data/cpp-build-cache:/home/runner/.cache       # Build cache
  - ./data/cpp-conan-cache:/home/runner/.conan       # Conan cache
```

#### Step 3: Create Custom Combinations

If standard composites don't fit, create custom ones:

**Example: Python + Node.js (for full-stack web apps)**
```dockerfile
# docker/linux/composite/Dockerfile.full-stack-web
FROM gh-runner:linux-base

# Copy Python and Node.js tools
COPY --from=gh-runner:python-pack /usr/local/bin/ /usr/local/bin/
COPY --from=gh-runner:nodejs-pack /usr/local/bin/ /usr/local/bin/

# Add web-specific tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

ENV BUILD_STACK=web-full
```

**Docker Compose:**
```yaml
# docker-compose/linux-web-full.yml
services:
  web-full-runner:
    build:
      context: .
      dockerfile: docker/linux/composite/Dockerfile.full-stack-web
    image: gh-runner:web-full
    # ... other config
```

### Phase 5: Cleanup (1 day)

#### Step 1: Decommission Monolith

**Verify all workflows migrated:**
```bash
# Check for remaining full-runner usage
grep -r "runs-on.*full" .github/workflows/

# Check for unused runners in GitHub
# Go to Settings → Actions → Runners
# Look for idle runners
```

**Stop and remove old containers:**
```bash
# Stop monolith containers
docker-compose -f docker-compose/linux-full.yml down

# Remove containers
docker rm github-full-runner

# Remove old images (optional, keep for rollback)
# docker rmi gh-runner:full-stack
```

#### Step 2: Update Documentation

**Update README:**
- Remove references to monolithic approach
- Document new runner labels
- Add migration notes
- Update deployment instructions

**Update CI/CD Documentation:**
```markdown
## Current Runner Configuration

| Environment | Runner Type | Labels |
|-------------|-------------|--------|
| Python/ML | `gh-runner:python-only` | `linux,python,ml,ai` |
| C++/Build | `gh-runner:cpp-only` | `linux,cpp,build` |
| Web Dev | `gh-runner:web-stack` | `linux,node,go,web` |
```

#### Step 3: Clean Up Old Images

**Optional: Keep for rollback:**
```bash
# Tag old images before removal
docker tag gh-runner:full-stack gh-runner:full-stack:rollback
docker tag gh-runner:full-stack gh-runner:full-stack:2026.01.21
```

**Remove old images (if not needed):**
```bash
# Remove unused images
docker image prune -f

# Remove old tags
docker rmi gh-runner:full-stack:1.0.0

# Clean build cache
docker builder prune -f
```

## Timeline & Milestones

### Week 1: Assessment & Deployment
- **Days 1-2**: Audit workflows, identify needs
- **Days 3-4**: Deploy new runners (parallel)
- **Day 5**: Test new runners, verify functionality

### Week 2: Migration
- **Days 1-3**: Migrate low-risk workflows
- **Days 4-5**: Migrate core workflows

### Week 3: Optimization
- **Days 1-2**: Monitor and adjust resources
- **Days 3-4**: Optimize caching, create custom combos
- **Day 5**: Performance testing

### Week 4: Cleanup
- **Day 1**: Decommission monolith
- **Day 2**: Update documentation
- **Day 3**: Clean up old images
- **Days 4-5**: Final verification

## Risk Mitigation

### Risk 1: Workflow Failures
**Mitigation:**
- Run parallel deployments
- Keep old runners as fallback
- Test thoroughly before full migration
- Have rollback plan ready

**Rollback Plan:**
```bash
# If issues occur, revert to old runners
# 1. Update workflow labels back to 'full'
# 2. Deploy monolith runners
# 3. Monitor for stability
```

### Risk 2: Performance Degradation
**Mitigation:**
- Monitor build times
- Adjust resource allocation
- Optimize build cache
- Profile slow workflows

**Performance Check:**
```bash
# Track build times over time
# If degradation detected, investigate:
# - Resource limits
# - Cache hit rate
# - Network issues
```

### Risk 3: Resource Constraints
**Mitigation:**
- Start with smaller runners
- Scale up as needed
- Use resource quotas
- Monitor usage patterns

**Resource Monitoring:**
```bash
# Set up alerts for resource usage
# If >80% memory or CPU, scale up
```

### Risk 4: Dependency Issues
**Mitigation:**
- Test all dependencies
- Use pinned versions
- Maintain dependency matrix
- Regular security updates

**Dependency Matrix:**
```markdown
| Language | Version | Lock File |
|----------|---------|-----------|
| Python | 3.10 | requirements.txt |
| Node.js | 20.x | package-lock.json |
| Go | 1.22 | go.mod |
| CMake | 3.x | CMakeLists.txt |
```

## Success Metrics

### Build Performance
- **Target**: 60-80% reduction in build time
- **Measurement**: Track workflow duration
- **Tool**: GitHub Actions API

### Storage Cost
- **Target**: 60-80% storage savings
- **Measurement**: Docker image sizes
- **Tool**: `docker images` and cost calculator

### Cache Efficiency
- **Target**: 90%+ cache hit rate
- **Measurement**: Docker build cache hits
- **Tool**: `docker build --cache-from`

### Security
- **Target**: Reduced attack surface
- **Measurement**: Number of installed packages
- **Tool**: Docker image scanning

### Maintenance
- **Target**: 50-70% reduction in update time
- **Measurement**: Time to deploy updates
- **Tool**: CI/CD pipeline timing

## Success Checklist

### Pre-Migration
- [ ] Audit all workflows
- [ ] Identify language requirements
- [ ] Choose starting languages (2-3 most used)
- [ ] Set up staging environment
- [ ] Create backup of current setup

### During Migration
- [ ] Deploy new runners in parallel
- [ ] Test each runner type
- [ ] Update workflows one by one
- [ ] Monitor build performance
- [ ] Document any issues

### Post-Migration
- [ ] All workflows migrated
- [ ] Performance metrics reviewed
- [ ] Old runners decommissioned
- [ ] Documentation updated
- [ ] Team trained on new system
- [ ] Monitoring set up
- [ ] Rollback plan documented

## Common Pitfalls & Solutions

### Pitfall 1: Assuming All Runners Need All Tools
**Problem**: Using full-runner for all workflows
**Solution**: Analyze actual needs, use specific runners

### Pitfall 2: Not Testing Dependencies
**Problem**: Missing packages in new images
**Solution**: Test thoroughly in staging, create dependency matrix

### Pitfall 3: Ignoring Build Cache
**Problem**: Long build times without cache
**Solution**: Set up proper caching volumes and strategies

### Pitfall 4: Forgetting to Update Labels
**Problem**: Workflows fail because labels don't match
**Solution**: Update all workflow files before deployment

### Pitfall 5: Over-provisioning Resources
**Problem**: Wasting resources on oversized runners
**Solution**: Start small, scale based on actual usage

## Rollback Procedure

If migration fails or causes issues:

### Immediate Rollback (5 minutes)
```bash
# 1. Update workflow labels back to 'full'
# Edit .github/workflows/*.yml and change:
# runs-on: [self-hosted, linux, cpp]
# to:
# runs-on: [self-hosted, linux, full]

# 2. Deploy monolith runners
docker-compose -f docker-compose/linux-full.yml up -d

# 3. Verify old runners are online
# Check GitHub Actions → Runners
```

### Full Rollback (30 minutes)
```bash
# 1. Stop all new runners
docker-compose -f docker-compose/linux-cpp.yml down
docker-compose -f docker-compose/linux-python.yml down
docker-compose -f docker-compose/linux-web.yml down
docker-compose -f docker-compose/linux-base.yml down

# 2. Deploy full-stack runners
docker-compose -f docker-compose/linux-full.yml up -d

# 3. Update all workflows to use 'full' label
# Use find/replace in all workflow files

# 4. Test workflows
# Run sample workflow to verify

# 5. Document rollback
# Add to post-mortem if needed
```

## Post-Migration Review

### Review Meeting (1 week after completion)
**Attendees**: DevOps, Engineers, Team Leads

**Agenda:**
1. Review performance metrics
2. Discuss any issues encountered
3. Identify improvements for next cycle
4. Document lessons learned
5. Update runbooks and documentation

### Metrics to Review
1. **Build Times**: Before vs after comparison
2. **Cost Savings**: Storage and compute costs
3. **Success Rate**: Workflow success/failure rates
4. **Resource Usage**: CPU, memory, network
5. **User Feedback**: Team satisfaction

### Action Items
- [ ] Document any remaining issues
- [ ] Create improvement backlog
- [ ] Schedule follow-up review
- [ ] Share success story with team

## Conclusion

Migrating from monolithic to modular runners is a significant improvement that:
- Reduces build times by 60-80%
- Lowers storage costs by 60-80%
- Improves cache efficiency from 20% to 90%+
- Reduces security surface
- Makes maintenance easier

**Key Success Factors:**
1. **Thorough assessment** before migration
2. **Parallel deployment** for safety
3. **Gradual migration** of workflows
4. **Continuous monitoring** during transition
5. **Clear documentation** for team

**Expected Outcomes:**
- Faster CI/CD pipelines
- Lower infrastructure costs
- Better resource utilization
- Improved developer experience
- More secure deployments

**Next Steps:**
1. Start with assessment phase
2. Deploy first language pack (most used)
3. Migrate 1-2 test workflows
4. Measure results
5. Continue with remaining workflows
6. Optimize based on data

---

**Ready to start?** Begin with Phase 1: Assessment and create your migration plan!
