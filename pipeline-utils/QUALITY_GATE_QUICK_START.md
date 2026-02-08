# Quality Gates Quick Start Guide

Phase 4: Automated Quality Gates - Quick Reference

---

## 🚀 Quick Setup

### 1. Prerequisites

**Database Setup:**
```bash
# Ensure PostgreSQL is running with metrics schema
docker ps | grep postgres
# Should show woodpecker database
```

**Required Tools:**
- xmllint (for parsing JaCoCo reports)
- jq (for JSON processing)
- bc (for calculations)
- gh (GitHub CLI - optional, for PR comments)

**Install in Docker Image:**
```dockerfile
RUN apt-get update && apt-get install -y \
    jq \
    bc \
    libxml2-utils \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Optional: GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh
```

### 2. Configure Secrets

**In Woodpecker:**
```bash
# Set GitHub token (for PR comments/issues)
woodpecker-cli secret add \
  --repository owner/repo \
  --name github_token \
  --value ghp_xxxxxxxxxxxx

# Set database password
woodpecker-cli secret add \
  --repository owner/repo \
  --name db_password \
  --value your_password
```

### 3. Enable JaCoCo in Android Project

**build.gradle (app level):**
```gradle
plugins {
    id 'jacoco'
}

android {
    buildTypes {
        debug {
            testCoverageEnabled true
        }
    }
}

tasks.register('jacocoTestReport', JacocoReport) {
    dependsOn 'testStandardDebugUnitTest'

    reports {
        xml.required = true
        html.required = true
    }

    def fileFilter = [
        '**/R.class',
        '**/R$*.class',
        '**/BuildConfig.*',
        '**/Manifest*.*',
        '**/*Test*.*',
        'android/**/*.*'
    ]

    def debugTree = fileTree(dir: "${buildDir}/intermediates/javac/debugStandard", excludes: fileFilter)
    def mainSrc = "${project.projectDir}/src/main/java"

    sourceDirectories.setFrom(files([mainSrc]))
    classDirectories.setFrom(files([debugTree]))
    executionData.setFrom(fileTree(dir: buildDir, includes: [
        'outputs/unit_test_code_coverage/debugStandardUnitTest/testStandardDebugUnitTest.exec',
        'outputs/code_coverage/debugStandardAndroidTest/connected/*.ec'
    ]))
}
```

---

## 📋 Usage Examples

### Coverage Enforcement

**Basic:**
```bash
./enforce-coverage.sh
```

**With Custom Threshold:**
```bash
./enforce-coverage.sh --threshold=75
```

**With PR Comment:**
```bash
./enforce-coverage.sh --threshold=80 --pr-number=123
```

**With Custom Report Path:**
```bash
./enforce-coverage.sh --report-path=app/build/reports/jacoco/jacocoTestReport/jacocoTestReport.xml
```

**In Pipeline:**
```yaml
enforce-coverage:
  image: android-ci:latest
  commands:
    - ./gradlew test jacocoTestReport
    - /opt/pipeline-utils/scripts/enforce-coverage.sh --threshold=80
  environment:
    GITHUB_TOKEN:
      from_secret: github_token
    COVERAGE_THRESHOLD: 80
```

### Performance Regression Detection

**Basic:**
```bash
./detect-regression.sh
```

**With Custom Threshold:**
```bash
./detect-regression.sh --regression-threshold=10
```

**Update Baselines:**
```bash
./detect-regression.sh --update-baselines
```

**With Custom Results:**
```bash
./detect-regression.sh --results-path=benchmark/build/outputs/results.json
```

**In Pipeline:**
```yaml
detect-regression:
  image: android-ci:latest
  commands:
    - ./gradlew connectedCheck
    - /opt/pipeline-utils/scripts/detect-regression.sh --regression-threshold=5
  environment:
    GITHUB_TOKEN:
      from_secret: github_token
    REGRESSION_THRESHOLD: 5
```

---

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `GITHUB_TOKEN` | GitHub API token | - | Yes (for PR comments) |
| `GITHUB_REPO` | Repository name | `${CI_REPO}` | No |
| `COVERAGE_THRESHOLD` | Coverage percentage | 80 | No |
| `REGRESSION_THRESHOLD` | Regression percentage | 5 | No |
| `DB_HOST` | Database host | localhost | No |
| `DB_PORT` | Database port | 5432 | No |
| `DB_NAME` | Database name | woodpecker | No |
| `DB_USER` | Database user | woodpecker | No |
| `DB_PASSWORD` | Database password | - | No |

### Threshold Guidelines

**Coverage:**
- New projects: Start at 60%, increase gradually
- Mature projects: 80-90%
- Critical systems: 90%+
- Documentation/tests: Exempt

**Performance:**
- Time-based: 5-10% degradation allowed
- Score-based: 5-10% degradation allowed
- Noisy benchmarks: Use 10-15%
- Stable benchmarks: Use 3-5%

---

## 📊 Database Queries

### Coverage Trends
```sql
-- Last 30 days
SELECT
  DATE(timestamp) as date,
  ROUND(AVG(overall_coverage), 2) as avg_coverage,
  COUNT(*) as builds
FROM coverage_history
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- By branch
SELECT
  branch,
  ROUND(AVG(overall_coverage), 2) as avg_coverage,
  COUNT(*) as builds
FROM coverage_history
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY branch
ORDER BY avg_coverage DESC;
```

### Performance Baselines
```sql
-- Current baselines
SELECT
  benchmark_name,
  branch,
  ROUND(score, 2) as current_score,
  ROUND(min_score, 2) as best_score,
  ROUND(max_score, 2) as worst_score,
  ROUND(std_dev, 2) as variability,
  sample_size
FROM performance_baselines
ORDER BY benchmark_name, branch;

-- Regressions (last 7 days)
WITH latest AS (
  SELECT DISTINCT ON (benchmark_name, branch)
    benchmark_name,
    branch,
    score as latest_score,
    timestamp
  FROM performance_baselines
  WHERE timestamp > NOW() - INTERVAL '7 days'
  ORDER BY benchmark_name, branch, timestamp DESC
)
SELECT
  l.benchmark_name,
  l.branch,
  l.latest_score,
  b.score as baseline_score,
  ROUND((l.latest_score - b.score) / b.score * 100, 2) as percent_change
FROM latest l
JOIN performance_baselines b ON
  l.benchmark_name = b.benchmark_name AND
  l.branch = b.branch AND
  b.timestamp < l.timestamp - INTERVAL '1 day'
WHERE l.latest_score < b.score * 0.95; -- 5% regression
```

### Recent Failures
```sql
-- Coverage failures
SELECT
  branch,
  overall_coverage,
  threshold_value,
  timestamp
FROM coverage_history
WHERE threshold_met = FALSE
  AND timestamp > NOW() - INTERVAL '30 days'
ORDER BY timestamp DESC;

-- Gate success rate
SELECT
  DATE(timestamp) as date,
  COUNT(*) FILTER (WHERE threshold_met = TRUE) as passed,
  COUNT(*) FILTER (WHERE threshold_met = FALSE) as failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE threshold_met = TRUE) / COUNT(*), 2) as pass_rate
FROM coverage_history
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;
```

---

## 🎯 Common Workflows

### Workflow 1: Enable Coverage Gate Gradually

**Step 1: Monitoring Mode (Week 1)**
```yaml
coverage-check:
  image: android-ci:latest
  commands:
    - /opt/pipeline-utils/scripts/enforce-coverage.sh --threshold=80 || true
  # Don't fail the build
```

**Step 2: Warn Mode (Week 2)**
```yaml
coverage-check:
  image: android-ci:latest
  commands:
    - /opt/pipeline-utils/scripts/enforce-coverage.sh --threshold=80
  when:
    branch:
      - exclude:
        - main
```

**Step 3: Full Enforcement (Week 3+)**
```yaml
coverage-check:
  image: android-ci:latest
  commands:
    - /opt/pipeline-utils/scripts/enforce-coverage.sh --threshold=80
  # No exclusions
```

### Workflow 2: Set Up Performance Baselines

**Initial Baseline Creation:**
```bash
# Run on stable main branch
git checkout main
./gradlew benchmark
./detect-regression.sh --update-baselines

# Verify baseline
psql -d woodpecker -c "SELECT * FROM performance_baselines ORDER BY timestamp DESC LIMIT 10;"
```

**Update Baseline After Improvements:**
```yaml
update-baselines:
  image: android-ci:latest
  commands:
    - ./gradlew benchmark
    - /opt/pipeline-utils/scripts/detect-regression.sh --update-baselines
  when:
    branch:
      - main
    event:
      - push
```

### Workflow 3: Debug Coverage Failures

**1. Check PR Comment:**
- Review the detailed coverage breakdown
- Identify low-coverage modules

**2. Generate Local Report:**
```bash
./gradlew test jacocoTestReport
# Open: app/build/reports/jacoco/jacocoTestReport/html/index.html
```

**3. Find Uncovered Code:**
- Look at HTML report
- Red lines = uncovered
- Focus on critical paths

**4. Add Tests:**
```kotlin
@Test
fun testPreviouslyUncoveredCode() {
    // Test the uncovered code path
}
```

**5. Verify Fix:**
```bash
./gradlew test jacocoTestReport
./enforce-coverage.sh --threshold=80
```

---

## 🐛 Troubleshooting

### Issue: "No JaCoCo report found"

**Solution:**
```bash
# Check if report exists
find . -name "jacocoTestReport.xml"

# If not found, ensure JaCoCo is configured
./gradlew tasks --all | grep jacoco

# Generate report manually
./gradlew jacocoTestReport
```

### Issue: "Coverage 0.00%"

**Solution:**
```bash
# Check if tests ran
./gradlew test --info

# Verify test execution data
find . -name "*.exec" -o -name "*.ec"

# Check JaCoCo configuration
# Ensure sourceDirectories and classDirectories are correct
```

### Issue: "No baseline found"

**Solution:**
```bash
# Create initial baseline
./detect-regression.sh --update-baselines

# Or use synthetic data for testing
./detect-regression.sh
# Will create synthetic data if no benchmarks found
```

### Issue: "Database connection failed"

**Solution:**
```bash
# Test connection
psql -h localhost -U woodpecker -d woodpecker -c "SELECT 1;"

# If using Docker, use host.docker.internal
export DB_HOST=host.docker.internal

# Check PostgreSQL is running
docker ps | grep postgres
```

### Issue: "GitHub API rate limit"

**Solution:**
```bash
# Use authenticated token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Check rate limit
gh api /rate_limit

# Use token with higher rate limit
# GitHub App token: ~5000 requests/hour
# Personal token: ~5000 requests/hour
# No token: ~60 requests/hour
```

---

## 📈 Best Practices

### 1. Coverage Targets

**Realistic Goals:**
- Start: 60% (achievable)
- Good: 70-80% (industry standard)
- Excellent: 80-90% (high quality)
- Exceptional: 90%+ (critical systems)

**Per-Module Targets:**
- Core business logic: 90%+
- UI components: 70-80%
- Data models: 80-90%
- Utilities: 70-80%

### 2. Performance Baselines

**Establish Baselines:**
1. Run on stable hardware
2. Use sufficient samples (10+ runs)
3. Exclude outliers
4. Document conditions

**Update Baselines:**
1. Only for valid improvements
2. Document reason
3. Keep history
4. Compare trends

### 3. Gate Configuration

**Conservative Start:**
- Lower thresholds initially
- Gradual increases
- Monitor false positives
- Adjust based on data

**Branch-Specific Rules:**
```yaml
# Main branch: strict
coverage-check-main:
  commands:
    - ./enforce-coverage.sh --threshold=80
  when:
    branch: main

# Feature branches: lenient
coverage-check-feature:
  commands:
    - ./enforce-coverage.sh --threshold=70
  when:
    branch:
      exclude:
        - main
        - release/*
```

### 4. Issue Management

**Automatic Issues:**
- Label clearly
- Include context
- Link to PR
- Provide steps

**Issue Resolution:**
1. Fix the problem
2. Verify locally
3. Update PR
4. Close issue

---

## 🔗 Related Documentation

- [Phase 4 Summary](pipeline-utils/PHASE4_SUMMARY.md) - Detailed documentation
- [Progress Log](progress_autonomy.md) - Implementation progress
- [Database Schema](pipeline-utils/schema/metrics.sql) - Database structure
- [Pipeline Utils README](pipeline-utils/README.md) - General utilities

---

## ✅ Checklist

**Initial Setup:**
- [ ] PostgreSQL database configured
- [ ] Metrics schema applied
- [ ] JaCoCo enabled in Android project
- [ ] GitHub token configured
- [ ] Quality gate pipeline added

**Testing:**
- [ ] Run coverage enforcement locally
- [ ] Run regression detection locally
- [ ] Test with synthetic data
- [ ] Verify PR comments work
- [ ] Verify GitHub issues created

**Production:**
- [ ] Enable in monitoring mode
- [ ] Review metrics for 1 week
- [ ] Enable warnings
- [ ] Enable blocking
- [ ] Set up alerts

---

**Quick Start Complete!**

For more details, see [PHASE4_SUMMARY.md](pipeline-utils/PHASE4_SUMMARY.md)
