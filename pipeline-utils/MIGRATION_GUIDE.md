# CI/CD Autonomy Migration Guide

**Version:** 1.0
**Last Updated:** 2026-02-08

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Migration Strategies](#migration-strategies)
4. [Step-by-Step Migration](#step-by-step-migration)
5. [Common Migration Scenarios](#common-migration-scenarios)
6. [Validation](#validation)
7. [Rollback Plan](#rollback-plan)
8. [Post-Migration Tasks](#post-migration-tasks)

---

## Overview

This guide helps you migrate existing Woodpecker CI pipelines to use autonomous features. The migration is designed to be incremental, allowing you to adopt features gradually.

### What Changes

- Pipeline configuration (`.woodpecker.yml`)
- Docker image (additional tools)
- Build scripts (retry, diagnosis, optimization)
- Database schema (optional, for metrics)

### What Stays the Same

- Your existing build commands
- Project structure
- Deployment process
- Woodpecker server configuration

### Migration Levels

1. **Level 1: Basic Autonomy** - Add retry and diagnosis
2. **Level 2: Smart Resources** - Add adaptive resource allocation
3. **Level 3: Full Autonomy** - Enable all autonomous features

---

## Pre-Migration Checklist

### Prerequisites

- [ ] Woodpecker CI server running (version 1.0+)
- [ ] Docker with BuildKit enabled
- [ ] Existing `.woodpecker.yml` file
- [ ] Project builds successfully in current setup
- [ ] Access to modify pipeline configuration
- [ ] Backup of current configuration

### Environment Setup

- [ ] PostgreSQL available (for metrics, optional)
- [ ] Sufficient disk space for enhanced Docker image
- [ ] Network access to dependency repositories
- [ ] Permissions to create Docker volumes

### Team Readiness

- [ ] Team briefed on new autonomous features
- [ ] Training completed for key developers
- [ ] Support channels established
- [ ] Rollback plan documented

### Risk Assessment

- [ ] Critical pipelines identified
- [ ] Rollback procedure tested
- [ ] Monitoring in place
- [ ] Notification channels configured

---

## Migration Strategies

### Strategy 1: Phased Rollout (Recommended)

**Best for:** Production pipelines with high traffic

**Approach:** Gradually enable features over time

**Advantages:**
- Low risk
- Easy to rollback
- Learn and adjust

**Timeline:** 2-4 weeks

### Strategy 2: Parallel Testing

**Best for:** Complex pipelines with many steps

**Approach:** Run old and new pipelines side-by-side

**Advantages:**
- Direct comparison
- No disruption
- Validate thoroughly

**Timeline:** 1-2 weeks

### Strategy 3: Feature Flag Toggle

**Best for:** Multiple projects or teams

**Approach:** Use feature flags to enable autonomy

**Advantages:**
- Instant rollback
- A/B testing
- Gradual adoption

**Timeline:** Ongoing

### Strategy 4: Big Bang

**Best for:** Small projects, low traffic

**Approach:** Migrate everything at once

**Advantages:**
- Quick migration
- No parallel maintenance

**Timeline:** 1-2 days

---

## Step-by-Step Migration

### Phase 1: Preparation (Day 1)

#### Step 1.1: Backup Current Configuration

```bash
# Create backup directory
mkdir -p ~/woodpecker-backup/$(date +%Y%m%d)

# Backup pipeline configuration
cp .woodpecker.yml ~/woodpecker-backup/$(date +%Y%m%d)/

# Backup any custom scripts
cp -r scripts/ ~/woodpecker-backup/$(date +%Y%m%d)/ 2>/dev/null || true

# Backup environment configuration
cp .env ~/woodpecker-backup/$(date +%Y%m%d)/ 2>/dev/null || true
```

#### Step 1.2: Build Enhanced Docker Image

```bash
# Clone or navigate to your repository
cd <your-repo>

# Build the enhanced image
docker build -f Dockerfile.android-ci-enhanced -t android-ci:latest .

# Verify image built successfully
docker images | grep android-ci

# Test the image
docker run --rm android-ci:latest bash -c "echo 'Image works!'"
```

#### Step 1.3: Verify Tools Are Installed

```bash
# Test that required tools are available
docker run --rm android-ci:latest bash -c '
  echo "Testing tools..."
  jq --version
  bash --version
  curl --version
  echo "✓ Basic tools OK"
'

# Test optional tools
docker run --rm android-ci:latest bash -c '
  echo "Testing optional tools..."
  command -v trufflehog && echo "✓ TruffleHog installed" || echo "⊘ TruffleHog not installed"
  command -v bc && echo "✓ bc installed" || echo "⊘ bc not installed"
  command -v gh && echo "✓ GitHub CLI installed" || echo "⊘ GitHub CLI not installed"
'
```

### Phase 2: Basic Autonomy (Day 2-3)

#### Step 2.1: Create Test Pipeline

Create `.woodpecker-autonomous.yml` for testing:

```yaml
when:
  event:
    - pull_request

steps:
  # Test: Analyze project
  test-analyze:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/analyze-project-size.sh

  # Test: Build with retry
  test-build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh --max-retries=2 ./gradlew assembleDebug
    environment:
      GRADLE_USER_HOME: /cache/gradle

  # Test: Cache check
  test-cache:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/check-cache-freshness.sh || echo "Cache check completed"
```

#### Step 2.2: Run Integration Tests

```bash
# Run the integration test suite
./pipeline-utils/scripts/test-integration.sh

# Review the test report
cat test-reports/test-summary-*.txt
```

#### Step 2.3: Test on Non-Critical Branch

```bash
# Create a test branch
git checkout -b test/autonomy-migration

# Add the new pipeline
git add .woodpecker-autonomous.yml
git commit -m "Test: Add autonomous pipeline"

# Push and monitor
git push origin test/autonomy-migration

# Monitor the build in Woodpecker UI
```

### Phase 3: Gradual Migration (Day 4-7)

#### Step 3.1: Migrate Build Steps

Update your existing `.woodpecker.yml`:

**Before:**
```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - ./gradlew assembleDebug
```

**After:**
```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh --max-retries=3 ./gradlew assembleDebug
    environment:
      GRADLE_USER_HOME: /cache/gradle
```

#### Step 3.2: Add Diagnosis to Failures

```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug 2>&1 | tee build.log
    failure:
      commands:
        - /opt/pipeline-utils/scripts/diagnose-failure.sh build.log
```

#### Step 3.3: Add Cache Optimization

```yaml
steps:
  check-cache:
    image: android-ci:latest
    commands:
      - |
        if ! /opt/pipeline-utils/scripts/check-cache-freshness.sh; then
          echo "Cache stale, clearing..."
          rm -rf /cache/gradle/*
        fi

  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - ./gradlew assembleDebug
    depends_on:
      - check-cache
```

### Phase 4: Resource Optimization (Day 8-10)

#### Step 4.1: Add Resource Analysis

```yaml
steps:
  analyze:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/analyze-project-size.sh --yaml > .resource-config.yaml

  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - source ../.resource-config.yaml
      - export GRADLE_OPTS="-Xmx${resources_memory} -XX:MaxMetaspaceSize=512m"
      - ./gradlew assembleDebug
    depends_on:
      - analyze
```

#### Step 4.2: Optimize Gradle Properties

Add to `gradle.properties`:

```properties
# Optimized for CI environment
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true

# Kotlin optimizations
kotlin.daemon.jvmargs=-Xmx2g
kotlin.incremental=true
kotlin.caching.enabled=true
```

### Phase 5: Security Features (Day 11-14)

#### Step 5.1: Add Secret Scanning

```yaml
steps:
  secret-scan:
    image: android-ci:latest
    commands:
      - trufflehog filesystem --directory . --json > secrets.json
    when:
      event:
        - pull_request

  secret-check:
    image: android-ci:latest
    commands:
      - |
        if [ -s secrets.json ] && [ "$(jq 'length' secrets.json)" -gt 0 ]; then
          echo "❌ Secrets detected!"
          jq '.' secrets.json
          exit 1
        fi
        echo "✓ No secrets found"
```

#### Step 5.2: Add License Checking

```yaml
steps:
  license-check:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - ./gradlew downloadLicenses checkLicenses
```

### Phase 6: Full Rollout (Day 15+)

#### Step 6.1: Replace Old Pipeline

```bash
# Backup old pipeline
cp .woodpecker.yml .woodpecker.yml.backup

# Replace with autonomous version
cp .woodpecker-autonomous.yml .woodpecker.yml

# Commit changes
git add .woodpecker.yml
git commit -m "Migrate to autonomous pipeline"

# Push to main branch
git push origin main
```

#### Step 6.2: Monitor and Validate

- Watch first 10 builds closely
- Check build success rate
- Monitor build times
- Review any failures

---

## Common Migration Scenarios

### Scenario 1: Simple Android Project

**Current state:** Basic Gradle build

**Migration steps:**
1. Add retry wrapper to build command
2. Add failure diagnosis step
3. Enable cache optimization

**Example:**
```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug
```

### Scenario 2: Multi-Module Project

**Current state:** Multiple Gradle modules

**Migration steps:**
1. Run project size analysis
2. Allocate resources based on module count
3. Enable parallel builds
4. Add module-level caching

**Example:**
```yaml
steps:
  analyze:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/analyze-project-size.sh --yaml > config.yaml

  build-parallel:
    image: android-ci:latest
    commands:
      - ./gradlew assembleDebug --parallel
```

### Scenario 3: Microservices Architecture

**Current state:** Multiple independent services

**Migration steps:**
1. Migrate one service at a time
2. Use feature flags
3. Compare performance
4. Gradual rollout

**Example:**
```yaml
steps:
  build-service-a:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew :service-a:build
    when:
      evaluate: AUTONOMY_ENABLED == "true"
```

### Scenario 4: Legacy Project with Flaky Tests

**Current state:** Tests often fail intermittently

**Migration steps:**
1. Identify flaky tests
2. Add retry logic
3. Increase test timeouts
4. Add failure diagnosis

**Example:**
```yaml
steps:
  test:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh --max-retries=3 ./gradlew test
```

### Scenario 5: Performance-Critical Application

**Current state:** Build time is critical

**Migration steps:**
1. Run benchmarks before migration
2. Add caching
3. Optimize resources
4. Monitor performance

**Example:**
```yaml
steps:
  benchmark:
    image: android-ci:latest
    commands:
      - time ./gradlew build
      - /opt/pipeline-utils/scripts/benchmark-autonomy.sh
```

---

## Validation

### Automated Validation

Run the integration test suite:

```bash
./pipeline-utils/scripts/test-integration.sh
```

Expected output:
```
✓ PASS: Script exists and executable: retry-command.sh
✓ PASS: Script exists and executable: diagnose-failure.sh
✓ PASS: Script execution: analyze-project-size.sh
...
Total Tests:  50
Passed:       48
Failed:       0
Skipped:      2
Pass Rate:    96%
✓ Integration tests PASSED
```

### Manual Validation Checklist

#### Build Success Rate
- [ ] Build success rate improved or maintained
- [ ] Flaky builds reduced
- [ ] Failed builds have diagnosis

#### Build Performance
- [ ] Build time acceptable
- [ ] Resource usage optimized
- [ ] Cache hit rate > 70%

#### Feature Validation
- [ ] Retry logic working
- [ ] Diagnosis provides useful info
- [ ] Cache invalidation correct
- [ ] Resource allocation appropriate

#### Security
- [ ] Secret scanning enabled
- [ ] License checking working
- [ ] No secrets in logs

#### Monitoring
- [ ] Metrics collected
- [ ] Alerts configured
- [ ] Dashboard updated

### Performance Validation

Run benchmarks:

```bash
# Before migration
./pipeline-utils/scripts/benchmark-autonomy.sh > baseline.txt

# After migration
./pipeline-utils/scripts/benchmark-autonomy.sh > after.txt

# Compare
diff baseline.txt after.txt
```

---

## Rollback Plan

### Instant Rollback

If critical issues arise:

```bash
# Restore old pipeline
git checkout HEAD~1 .woodpecker.yml
git push origin main

# Or revert commit
git revert HEAD
git push origin main
```

### Feature-Specific Rollback

Disable specific features:

```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      # Comment out retry wrapper
      # - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew build
      - ./gradlew build
```

### Gradual Rollback

Use feature flags:

```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - |
        if [ "$ENABLE_AUTONOMY" = "true" ]; then
          /opt/pipeline-utils/scripts/retry-command.sh ./gradlew build
        else
          ./gradlew build
        fi
```

### Rollback Decision Matrix

| Symptom | Action | Timeline |
|---------|--------|----------|
| Build failure rate > 50% | Instant rollback | Immediate |
| Build time doubled | Investigate, then rollback | 1 hour |
| Resource exhaustion | Rollback, adjust | 30 minutes |
| Security issue | Instant rollback | Immediate |
| Minor inconvenience | Monitor and fix | 1 day |

---

## Post-Migration Tasks

### Day 1 After Migration

- [ ] Monitor all builds
- [ ] Check error rates
- [ ] Review diagnosis reports
- [ ] Team feedback session

### Week 1 After Migration

- [ ] Analyze metrics
- [ ] Optimize configuration
- [ ] Update documentation
- [ ] Train team members

### Month 1 After Migration

- [ ] Performance review
- [ ] Cost analysis
- [ ] Feature evaluation
- [ ] Next phase planning

### Ongoing

- [ ] Monitor metrics dashboard
- [ ] Review failure patterns
- [ ] Update autonomy features
- [ ] Share best practices

---

## Support

### Getting Help

If you encounter issues during migration:

1. Check the [Autonomy Guide](AUTONOMY_GUIDE.md)
2. Review [Troubleshooting](AUTONOMY_GUIDE.md#troubleshooting)
3. Run integration tests
4. Check Woodpecker logs
5. Contact support team

### Useful Commands

```bash
# Test configuration
./pipeline-utils/scripts/test-integration.sh

# Run benchmarks
./pipeline-utils/scripts/benchmark-autonomy.sh

# Check Woodpecker logs
docker logs woodpecker-server

# View agent status
docker logs woodpecker-agent

# Inspect volumes
docker volume ls
docker volume inspect gradle-cache
```

---

## Checklist Summary

### Pre-Migration
- [ ] Backup created
- [ ] Image built successfully
- [ ] Tools verified
- [ ] Team briefed

### Migration
- [ ] Test pipeline created
- [ ] Integration tests passed
- [ ] Build steps migrated
- [ ] Features enabled gradually

### Post-Migration
- [ ] Builds monitored
- [ ] Performance validated
- [ ] Team trained
- [ ] Documentation updated

---

**Happy migrating!** 🚀

For questions or issues, refer to the [Autonomy Guide](AUTONOMY_GUIDE.md) or contact the support team.
