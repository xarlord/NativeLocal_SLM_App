# CI/CD Autonomy Features Guide

**Version:** 1.0
**Last Updated:** 2026-02-08
**Project:** Woodpecker CI Autonomous Features

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Feature Details](#feature-details)
4. [Usage Examples](#usage-examples)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)
8. [API Reference](#api-reference)

---

## Overview

The CI/CD Autonomy Features enhance Woodpecker CI with intelligent, self-healing capabilities that automatically detect, diagnose, and recover from common build failures.

### Key Features

- **Self-Healing Capabilities**
  - Automatic retry with exponential backoff
  - Failure auto-diagnosis with pattern matching
  - Automatic remediation for common issues

- **Intelligent Decision Making**
  - Adaptive resource allocation based on project size
  - Smart cache management and invalidation
  - Dynamic timeout adjustment

- **Automated Quality Gates**
  - Code coverage enforcement
  - Performance regression detection
  - Lint and static analysis integration

- **Security Automation**
  - Secret scanning with TruffleHog
  - License compliance checking
  - Dependency vulnerability triaging

### Benefits

- **Reduced Manual Intervention**: Automatically handle common failures
- **Faster Build Recovery**: Quick diagnosis and remediation
- **Better Resource Utilization**: Optimal memory and CPU allocation
- **Improved Build Success Rates**: Intelligent retry and recovery
- **Enhanced Security**: Automated secret detection and vulnerability scanning

---

## Quick Start

### Prerequisites

- Woodpecker CI server running
- Docker with BuildKit enabled
- PostgreSQL database (for metrics storage)
- Bash shell environment

### Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repo>
   cd <your-repo>
   ```

2. **Build the enhanced Docker image:**
   ```bash
   docker build -f Dockerfile.android-ci-enhanced -t android-ci:latest .
   ```

3. **Set up the environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Initialize the database:**
   ```bash
   docker-compose up -d postgres
   psql -h localhost -U woodpecker -d woodpecker < pipeline-utils/schema/metrics.sql
   ```

5. **Run integration tests:**
   ```bash
   ./pipeline-utils/scripts/test-integration.sh
   ```

### First Pipeline Run

Create `.woodpecker-autonomous.yml` in your project root:

```yaml
when:
  event:
    - push
    - pull_request

steps:
  # Resource analysis
  analyze:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/analyze-project-size.sh --yaml > .resource-config.yaml

  # Build with retry
  build:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug
```

Push to your repository and Woodpecker will automatically use the autonomous features!

---

## Feature Details

### 1. Self-Healing Capabilities

#### 1.1 Automatic Retry

**Purpose**: Automatically retry failed commands with intelligent backoff

**Script**: `retry-command.sh`

**Usage**:
```bash
./pipeline-utils/scripts/retry-command.sh [options] <command>

Options:
  --max-retries=N    Maximum number of retries (default: 3)
  --backoff=TYPE     Backoff strategy: linear, exponential (default: exponential)
  --initial-delay=N  Initial delay in seconds (default: 1)
  --timeout=N        Maximum time to wait in seconds (default: 300)
```

**Examples**:
```bash
# Retry flaky test up to 5 times
./pipeline-utils/scripts/retry-command.sh --max-retries=5 ./gradlew test

# Retry with linear backoff
./pipeline-utils/scripts/retry-command.sh --backoff=linear ./gradlew build

# Retry network operation with custom timeout
./pipeline-utils/scripts/retry-command.sh --timeout=600 curl -O https://example.com/file.zip
```

**How It Works**:
1. Executes the command
2. If it fails, waits using configured backoff strategy
3. Retries the command up to max-retries times
4. Returns the final exit code

**Best For**:
- Flaky tests
- Network operations
- Dependency downloads

#### 1.2 Failure Auto-Diagnosis

**Purpose**: Analyze build failures and provide remediation suggestions

**Script**: `diagnose-failure.sh`

**Usage**:
```bash
./pipeline-utils/scripts/diagnose-failure.sh <log-file>
```

**Examples**:
```bash
# Diagnose last build failure
./pipeline-utils/scripts/diagnose-failure.sh .last-build-log

# Save diagnosis to file
./pipeline-utils/scripts/diagnose-failure.sh build.log > diagnosis.txt

# Use in pipeline
steps:
  build:
    image: android-ci:latest
    commands:
      - ./gradlew build 2>&1 | tee build.log
    failure:
      commands:
        - ./pipeline-utils/scripts/diagnose-failure.sh build.log
```

**Detectable Patterns**:
- OutOfMemoryError
- Network timeouts
- Dependency resolution failures
- Compilation errors
- Test failures
- Permission issues
- Disk space problems

**Output Includes**:
- Pattern classification
- Severity assessment
- Category (infrastructure, code, tests, dependencies)
- Auto-fix capability
- Detailed remediation steps

#### 1.3 Automatic Remediation

**Purpose**: Automatically fix common build issues

**Scripts**:
- `fix-oom.sh` - Increase memory allocation
- `fix-timeout.sh` - Increase timeouts
- `fix-dependencies.sh` - Refresh dependencies
- `fix-lock.sh` - Clear Gradle locks

**Usage**:
```bash
# Fix OutOfMemoryError
./pipeline-utils/scripts/fix-oom.sh

# Fix timeout issues
./pipeline-utils/scripts/fix-timeout.sh

# Fix dependency resolution
./pipeline-utils/scripts/fix-dependencies.sh

# Clear Gradle locks
./pipeline-utils/scripts/fix-lock.sh
```

**Integration in Pipeline**:
```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - ./gradlew build
    failure:
      commands:
        - ./pipeline-utils/scripts/diagnose-failure.sh build.log
        - |
          if grep -q "OutOfMemoryError" build.log; then
            ./pipeline-utils/scripts/fix-oom.sh
            ./gradlew build
          fi
```

### 2. Intelligent Decision Making

#### 2.1 Adaptive Resource Allocation

**Purpose**: Automatically determine optimal resource allocation based on project characteristics

**Script**: `analyze-project-size.sh`

**Usage**:
```bash
./pipeline-utils/scripts/analyze-project-size.sh [options]

Options:
  --yaml, -y    Output as YAML format
  --json, -j    Output as JSON format
```

**Examples**:
```bash
# Get human-readable recommendations
./pipeline-utils/scripts/analyze-project-size.sh

# Export as YAML for pipeline consumption
./pipeline-utils/scripts/analyze-project-size.sh --yaml > config.yaml

# Use in pipeline
steps:
  analyze:
    image: android-ci:latest
    commands:
      - ./pipeline-utils/scripts/analyze-project-size.sh --yaml > .resources.yaml
      - export RECOMMENDED_MEMORY=$(grep 'memory:' .resources.yaml | awk '{print $2}')
      - export RECOMMENDED_CPU=$(grep 'cpu:' .resources.yaml | awk '{print $2}')
```

**Metrics Analyzed**:
- Lines of code
- Number of modules
- Test file count
- Dependency count

**Recommendations Provided**:
- Memory allocation
- CPU cores
- Expected build time
- Gradle configuration
- Pipeline configuration

#### 2.2 Smart Caching

**Purpose**: Detect cache staleness and automatically invalidate when dependencies change

**Script**: `check-cache-freshness.sh`

**Usage**:
```bash
./pipeline-utils/scripts/check-cache-freshness.sh

Environment Variables:
  CACHE_DIR       Cache directory (default: /cache/gradle)
  PROJECT_DIR     Project directory (default: .)
  HASH_FILE       Location to store cache hash (default: $CACHE_DIR/.cache-hash)
```

**Examples**:
```bash
# Check if cache is fresh
./pipeline-utils/scripts/check-cache-freshness.sh

# Custom cache location
CACHE_DIR=/tmp/cache ./pipeline-utils/scripts/check-cache-freshness.sh

# In pipeline
steps:
  check-cache:
    image: android-ci:latest
    commands:
      - if ! ./pipeline-utils/scripts/check-cache-freshness.sh; then
          rm -rf /cache/gradle/*
        fi
```

**How It Works**:
1. Calculates hash of dependency files (build.gradle, settings.gradle, etc.)
2. Compares with stored hash
3. Returns 0 if fresh, 1 if stale
4. Optionally invalidates cache interactively

**Monitored Files**:
- `build.gradle` / `build.gradle.kts`
- `settings.gradle` / `settings.gradle.kts`
- `gradle/wrapper/gradle-wrapper.properties`

### 3. Automated Quality Gates

#### 3.1 Code Coverage Enforcement

**Purpose**: Enforce minimum code coverage standards

**Implementation**: Integration with Jacoco

**Usage**:
```yaml
steps:
  test:
    image: android-ci:latest
    commands:
      - ./gradlew test jacocoTestReport

  coverage-check:
    image: android-ci:latest
    commands:
      - |
        COVERAGE=$(awk -F',' '{print $4}' app/build/reports/jacoco/test/html/index.html | grep -oP '\d+' | head -1)
        if [ "$COVERAGE" -lt 80 ]; then
          echo "Coverage ${COVERAGE}% is below threshold 80%"
          exit 1
        fi
```

#### 3.2 Performance Regression Detection

**Purpose**: Detect performance degradation in builds and tests

**Implementation**: Baseline comparison

**Usage**:
```yaml
steps:
  benchmark:
    image: android-ci:latest
    commands:
      - ./gradlew benchmark

  compare-baseline:
    image: android-ci:latest
    commands:
      - |
        CURRENT_TIME=$(cat benchmark-results.txt | grep 'Total time' | awk '{print $3}')
        BASELINE_TIME=$(cat baseline-benchmark.txt | grep 'Total time' | awk '{print $3}')
        THRESHOLD=1.1  # 10% degradation threshold

        if (( $(echo "$CURRENT_TIME > $BASELINE_TIME * $THRESHOLD" | bc -l) )); then
          echo "Performance regression detected!"
          exit 1
        fi
```

### 4. Security Automation

#### 4.1 Secret Scanning

**Purpose**: Detect secrets and credentials in source code

**Tool**: TruffleHog

**Usage**:
```yaml
steps:
  secret-scan:
    image: android-ci:latest
    commands:
      - trufflehog filesystem --directory /woodpecker/src --json | tee secrets.json

  secret-check:
    image: android-ci:latest
    commands:
      - |
        if [ -s secrets.json ] && [ "$(jq 'length' secrets.json)" -gt 0 ]; then
          echo "Secrets detected in code!"
          jq '.' secrets.json
          exit 1
        fi
    when:
      event:
        - pull_request
```

**Detects**:
- API keys
- Passwords
- Tokens
- Certificates
- SSH keys

#### 4.2 License Compliance

**Purpose**: Ensure all dependencies comply with license policies

**Tool**: License plugin

**Usage**:
```yaml
steps:
  license-check:
    image: android-ci:latest
    commands:
      - ./gradlew downloadLicenses
      - ./gradlew checkLicenses

  license-report:
    image: android-ci:latest
    commands:
      - ./gradlew generateLicenseReport
      - mkdir -p artifacts
      - cp -r build/reports/licenses artifacts/
```

---

## Usage Examples

### Example 1: Complete Autonomous Pipeline

```yaml
when:
  event:
    - push
    - pull_request

steps:
  # Step 1: Analyze project and allocate resources
  resource-analysis:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/analyze-project-size.sh --yaml > .resource-config.yaml

  # Step 2: Check cache freshness
  check-cache:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/check-cache-freshness.sh || rm -rf /cache/gradle/*

  # Step 3: Build with auto-retry
  build:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh --max-retries=3 ./gradlew assembleDebug
    environment:
      GRADLE_USER_HOME: /cache/gradle

  # Step 4: Test with auto-retry
  test:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh --max-retries=2 ./gradlew test

  # Step 5: Lint
  lint:
    image: android-ci:latest
    commands:
      - cd simpleGame
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew lint

  # Step 6: Secret scanning
  secret-scan:
    image: android-ci:latest
    commands:
      - trufflehog filesystem --directory . --json > secrets.json
    when:
      event:
        - pull_request

  # Step 7: Failure diagnosis (if any step failed)
  diagnose:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/diagnose-failure.sh .last-build-log
    when:
      status:
        - failure
```

### Example 2: Progressive Rollout

```yaml
steps:
  # Build with autonomy
  build:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug

  # Deploy to staging
  deploy-staging:
    image: android-ci:latest
    commands:
      - ./deploy.sh staging

  # Smoke tests
  smoke-test:
    image: android-ci:latest
    commands:
      - /opt/pipeline-utils/scripts/retry-command.sh ./scripts/smoke-tests.sh

  # Deploy to production (only if smoke tests pass)
  deploy-production:
    image: android-ci:latest
    commands:
      - ./deploy.sh production
    when:
      event:
        - push
      branch:
        - main
```

### Example 3: Performance Benchmarking

```yaml
steps:
  # Run benchmarks
  benchmark:
    image: android-ci:latest
    commands:
      - ./gradlew benchmark
      - cp build/reports/benchmark/*.txt artifacts/

  # Compare with baseline
  compare:
    image: android-ci:latest
    commands:
      - |
        CURRENT=$(cat artifacts/benchmark.txt | grep 'Total:' | awk '{print $2}')
        BASELINE=$(cat baseline.txt | grep 'Total:' | awk '{print $2}')
        if (( $(echo "$CURRENT > $BASELINE * 1.1" | bc -l) )); then
          echo "Performance regression: $CURRENT > $BASELINE"
          exit 1
        fi
```

---

## Configuration

### Environment Variables

```bash
# Gradle Configuration
GRADLE_OPTS="-Xmx4g -XX:MaxMetaspaceSize=512m"
GRADLE_USER_HOME=/cache/gradle

# Cache Configuration
CACHE_DIR=/cache/gradle
PROJECT_DIR=.

# Database Configuration
DB_CONNECTION="postgresql://user:pass@localhost:5432/woodpecker"

# Retry Configuration
RETRY_MAX_ATTEMPTS=3
RETRY_BACKOFF=exponential
RETRY_INITIAL_DELAY=1

# Autonomous Features
ENABLE_SELF_HEALING=true
ENABLE_CACHE_OPTIMIZATION=true
ENABLE_RESOURCE_ALLOCATION=true
```

### Failure Pattern Configuration

Edit `pipeline-utils/config/failure-patterns.yaml` to add custom patterns:

```yaml
patterns:
  - name: "CustomPattern"
    severity: "medium"
    category: "infrastructure"
    regex: "your-custom-regex-here"
    remediation: |
      Steps to fix this issue:
      1. Do this
      2. Do that
    auto_fixable: true
    auto_fix_script: "fix-custom.sh"
```

### Woodpecker Configuration

```yaml
# Global settings
when:
  event:
    - push
    - pull_request

# Default resources for all steps
labels:
  autoscaling: true

# Default environment
environment:
  CI: true
  ENABLE_AUTONOMY: true

# Volumes
volumes:
  gradle-cache:
    driver: local
  android-sdk:
    driver: local
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Scripts Not Executed

**Symptom**: Scripts are not found or not executable

**Solution**:
```bash
# Make scripts executable
chmod +x pipeline-utils/scripts/*.sh

# Verify scripts are in Docker image
docker run --rm android-ci:latest ls -la /opt/pipeline-utils/scripts/
```

#### Issue 2: Cache Not Working

**Symptom**: Cache is always invalidated

**Solution**:
```bash
# Check cache directory permissions
ls -la /cache/gradle

# Clear hash file to force recalculation
rm /cache/gradle/.cache-hash

# Verify cache directory is mounted
docker volume inspect gradle-cache
```

#### Issue 3: OutOfMemoryError Persists

**Symptom**: Auto-fix doesn't resolve OOM errors

**Solution**:
```yaml
# Manually increase memory allocation
steps:
  build:
    image: android-ci:latest
    commands:
      - export GRADLE_OPTS="-Xmx8g -XX:MaxMetaspaceSize=1g"
      - ./gradlew build
    resources:
      memory: 12GB
```

#### Issue 4: Retry Logic Not Working

**Symptom**: Commands fail immediately without retry

**Solution**:
```bash
# Check retry script syntax
./pipeline-utils/scripts/retry-command.sh --help

# Verify command is properly quoted
./pipeline-utils/scripts/retry-command.sh "./gradlew build --no-daemon"

# Check for interactive prompts
./pipeline-utils/scripts/retry-command.sh --timeout=120 ./gradlew build
```

#### Issue 5: Database Connection Failed

**Symptom**: Cannot connect to PostgreSQL

**Solution**:
```bash
# Test database connection
psql -h localhost -U woodpecker -d woodpecker -c "SELECT 1;"

# Check database is running
docker ps | grep postgres

# Verify credentials
grep DB_ .env
```

### Debug Mode

Enable debug output:

```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - set -x  # Enable bash debug mode
      - export DEBUG_AUTONOMY=true
      - /opt/pipeline-utils/scripts/retry-command.sh ./gradlew build
```

### Log Analysis

Collect diagnostic information:

```bash
# Run integration tests
./pipeline-utils/scripts/test-integration.sh

# Run performance benchmarks
./pipeline-utils/scripts/benchmark-autonomy.sh

# Check Woodpecker logs
docker logs woodpecker-server

# Check agent logs
docker logs woodpecker-agent
```

---

## Best Practices

### 1. Pipeline Design

- **Use retry for network operations**: Always wrap network calls in retry-command.sh
- **Check cache early**: Run cache freshness check before expensive builds
- **Analyze first**: Run project size analysis before resource-intensive steps
- **Fail fast**: Put quick checks (lint, format) before slow builds

### 2. Resource Management

- **Right-size resources**: Use analyze-project-size.sh to determine optimal allocation
- **Limit parallel builds**: Don't exceed CPU count recommendations
- **Monitor memory usage**: Set appropriate heap sizes for Gradle
- **Use volumes wisely**: Mount only what you need

### 3. Error Handling

- **Log everything**: Use `tee` to save logs for diagnosis
- **Save build artifacts**: Collect logs even on failure
- **Run diagnosis**: Always run diagnose-failure.sh on failures
- **Notify intelligently**: Send notifications only for real failures

### 4. Security

- **Scan secrets**: Run TruffleHog on every PR
- **Check licenses**: Verify dependency licenses
- **Rotate credentials**: Never commit secrets to repo
- **Use environment variables**: Store secrets in Woodpecker secrets

### 5. Performance

- **Cache dependencies**: Use Gradle build cache
- **Incremental builds**: Don't use `clean` unnecessarily
- **Parallel execution**: Run independent steps in parallel
- **Monitor benchmarks**: Track performance over time

### 6. Maintenance

- **Update scripts**: Keep utility scripts up to date
- **Review patterns**: Add new failure patterns as they're discovered
- **Monitor metrics**: Review database metrics regularly
- **Test changes**: Run integration tests before deploying

---

## API Reference

### Script APIs

#### retry-command.sh

```bash
./retry-command.sh [OPTIONS] COMMAND

Options:
  --max-retries=N     Maximum retry attempts (default: 3)
  --backoff=TYPE      Backoff strategy: linear|exponential (default: exponential)
  --initial-delay=N   Initial delay in seconds (default: 1)
  --timeout=N         Total timeout in seconds (default: 300)

Exit Codes:
  0   Success
  1   Command failed after all retries
  2   Invalid arguments
  3   Timeout exceeded
```

#### diagnose-failure.sh

```bash
./diagnose-failure.sh LOG_FILE

Arguments:
  LOG_FILE    Path to build log file

Exit Codes:
  0   No patterns found
  1   Critical/high severity patterns found
  2   Medium/low severity patterns found
  3   Log file not found
```

#### analyze-project-size.sh

```bash
./analyze-project-size.sh [OPTIONS]

Options:
  --yaml, -y    Output YAML format
  --json, -j    Output JSON format

Output:
  Human-readable recommendations (default)
  Structured data (with --yaml or --json)
```

#### check-cache-freshness.sh

```bash
./check-cache-freshness.sh

Environment Variables:
  CACHE_DIR       Cache directory (default: /cache/gradle)
  PROJECT_DIR     Project directory (default: .)
  HASH_FILE       Hash storage location (default: $CACHE_DIR/.cache-hash)

Exit Codes:
  0   Cache is fresh
  1   Cache is stale
  2   Error checking cache
```

### Database Schema

See `pipeline-utils/schema/metrics.sql` for complete database schema.

Key tables:
- `build_metrics` - Build performance data
- `failure_patterns` - Detected failure patterns
- `resource_usage` - Resource consumption
- `benchmark_results` - Performance benchmarks

### REST API (Future)

Planned REST API endpoints:
- `GET /api/status` - System status
- `GET /api/metrics` - Build metrics
- `POST /api/diagnose` - Diagnose failure
- `GET /api/benchmarks` - Benchmark history

---

## Support and Contributing

### Getting Help

- Check this guide first
- Review integration test results
- Check benchmark reports
- Review failure pattern database

### Reporting Issues

When reporting issues, include:
- Woodpecker version
- Docker image tag
- Pipeline configuration
- Build logs
- Diagnosis output
- Steps to reproduce

### Contributing

Contributions welcome! Areas needing help:
- Additional failure patterns
- Performance optimizations
- New autonomous features
- Documentation improvements
- Test coverage

---

## Changelog

### Version 1.0 (2026-02-08)
- Initial release
- Self-healing capabilities
- Intelligent resource allocation
- Smart caching
- Security automation
- Comprehensive documentation

---

**End of Guide**
