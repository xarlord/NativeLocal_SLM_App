# Feature 2: Pre-commit Hooks - Implementation Summary

## Overview

Feature 2 implements a comprehensive pre-commit hooks system that automatically checks code quality before each commit. The system includes 6 scripts for installation, checking, and reporting.

## Scripts Created

### 1. install-hooks.sh
**Location**: `pipeline-utils/scripts/install-hooks.sh`

**Purpose**: Installs pre-commit hooks to `.git/hooks` directory

**Features**:
- Detects OS (Windows Git Bash, macOS, Linux)
- Automatically finds `.git/hooks` directory
- Creates pre-commit hook from template
- Makes hook executable
- Creates `.pre-commit-config.yaml`
- Backs up existing hooks
- Verifies installation
- Displays usage instructions

**Usage**:
```bash
./pipeline-utils/scripts/install-hooks.sh
```

### 2. pre-commit-format.sh
**Location**: `pipeline-utils/scripts/pre-commit-format.sh`

**Purpose**: Checks code formatting with ktlint

**Features**:
- Runs `./gradlew ktlintCheck`
- Parses ktlint output for violations
- Extracts file paths and violation counts
- Stores results in `pre_commit_checks` table
- Handles Windows path separators
- Provides fix command on failure
- Timeout: 180 seconds

**Exit codes**:
- 0: No violations
- 1: Violations found

**Database schema**:
```sql
INSERT INTO pre_commit_checks (
  commit_sha, branch, check_type, status,
  duration_ms, exit_code, output, findings, timestamp
)
VALUES ('...', '...', 'format', 'passed/failed', ...);
```

### 3. pre-commit-lint.sh
**Location**: `pipeline-utils/scripts/pre-commit-lint.sh`

**Purpose**: Runs Android lint checks

**Features**:
- Runs `./gradlew lint`
- Parses XML reports: `app/build/reports/lint-results.xml`
- Parses JSON reports: `app/build/reports/lint-results.json`
- Falls back to output parsing if reports missing
- Counts errors and warnings separately
- Stores results in `pre_commit_checks` table
- Shows up to 20 lint issues
- Timeout: 300 seconds (5 minutes)

**Exit codes**:
- 0: No errors
- 1: Errors found (warnings don't fail)

### 4. pre-commit-tests.sh
**Location**: `pipeline-utils/scripts/pre-commit-tests.sh`

**Purpose**: Runs quick unit tests (no instrumented tests)

**Features**:
- Runs `./gradlew testDebugUnitTest`
- Parses test result XML files
- Extracts passed/failed/skipped counts
- Lists failed test names
- Stores results in `pre_commit_checks` table
- Target: < 30 seconds
- Timeout: 30 seconds (configurable)

**Exit codes**:
- 0: All tests passed
- 1: Tests failed

**Test result locations searched**:
- `app/build/test-results/testDebugUnitTest/`
- `build/test-results/test/`
- `app/build/test-results/test/`

### 5. pre-commit-secrets.sh
**Location**: `pipeline-utils/scripts/pre-commit-secrets.sh`

**Purpose**: Scans staged files for secrets using trufflehog

**Features**:
- Runs `trufflehog git` on repository
- Filters findings to staged files only
- Classifies severity (critical, high, medium, low)
- Verified secrets = critical severity
- Stores results in both:
  - `pre_commit_checks` table
  - `security_scans` table
- Supports `.secretsignore` file
- Blocks commit on critical secrets

**Severity classification**:
- **Critical**: Verified secrets, passwords, API keys
- **High**: AWS, SSH, private keys, tokens
- **Medium**: Credentials, auth tokens
- **Low**: Unlikely matches

**Exit codes**:
- 0: No critical secrets
- 1: Critical secrets found

### 6. pre-commit-summary.sh
**Location**: `pipeline-utils/scripts/pre-commit-summary.sh`

**Purpose**: Generates summary report of all checks

**Features**:
- Queries `pre_commit_checks` table for results
- Displays formatted table with:
  - Check name
  - Status (passed/failed/skipped)
  - Duration (formatted as Xm Xs or X.XXXs)
  - Details (violations, errors, test counts)
- Shows total checks, passed, failed
- Shows total duration
- Displays detailed findings for failed checks
- Color-coded output (green/red/yellow)

**Output format**:
```
═════════════════════════════════════════════════════════
                  PRE-COMMIT CHECKS SUMMARY
═════════════════════════════════════════════════════════

Commit: abc12345
Branch: feature/new-feature
Time:   2026-02-08 16:45:30

────────────────────────────────────────────────────────
Check           Status        Duration       Details
────────────────────────────────────────────────────────
Format          passed        2.450s         No violations
Lint            passed        15.230s        0E, 2W
Tests           passed        8.120s         142 passed, 0 failed
Secrets         passed        1.850s         None found
────────────────────────────────────────────────────────

Total Checks:    4
Passed:          4
Total Duration:  27.650s

✓ All checks passed!
```

## Configuration Files

### .pre-commit-config.yaml
**Location**: `.pre-commit-config.yaml`

**Purpose**: Configuration for pre-commit hooks

**Contents**:
```yaml
hooks:
  - name: format
    script: pipeline-utils/scripts/pre-commit-format.sh
    description: Check code formatting with ktlint
    pass_fail: true

  - name: lint
    script: pipeline-utils/scripts/pre-commit-lint.sh
    description: Run Android lint checks
    pass_fail: true

  - name: tests
    script: pipeline-utils/scripts/pre-commit-tests.sh
    description: Run quick unit tests
    pass_fail: true

  - name: secrets
    script: pipeline-utils/scripts/pre-commit-secrets.sh
    description: Scan for secrets with trufflehog
    pass_fail: true

options:
  skip_on_merge: false
  timeout: 300
  log_level: info

exclude:
  - "build/"
  - ".gradle/"
  - "*.md"

check_settings:
  format:
    auto_fix: false
    max_violations: 0

  lint:
    severity_threshold: error
    max_warnings: 10

  tests:
    max_duration: 30
    min_coverage: 0

  secrets:
    block_on_critical: true
    block_on_high: false
```

### pre-commit-hook.template
**Location**: `pipeline-utils/templates/pre-commit-hook.template`

**Purpose**: Template for `.git/hooks/pre-commit` file

**Features**:
- Runs all 4 checks in sequence
- Tracks overall status
- Generates summary
- Calculates total duration
- Provides bypass instructions
- Provides fix instructions

## Database Schema

### pre_commit_checks table

Added to `pipeline-utils/schema/metrics.sql`:

```sql
CREATE TABLE IF NOT EXISTS pre_commit_checks (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Git information
  commit_sha VARCHAR(40) NOT NULL,
  branch VARCHAR(100) NOT NULL,

  -- Check details
  check_type VARCHAR(50) NOT NULL, -- format, lint, tests, secrets
  status VARCHAR(20) NOT NULL, -- passed, failed, skipped

  -- Performance metrics
  duration_ms INTEGER,
  exit_code INTEGER,

  -- Results
  output TEXT,
  findings JSONB,

  -- Timestamp
  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_pre_commit_check UNIQUE (commit_sha, branch, check_type)
);

CREATE INDEX idx_pre_commit_checks_commit ON pre_commit_checks(commit_sha);
CREATE INDEX idx_pre_commit_checks_branch ON pre_commit_checks(branch);
CREATE INDEX idx_pre_commit_checks_type ON pre_commit_checks(check_type);
CREATE INDEX idx_pre_commit_checks_status ON pre_commit_checks(status);
CREATE INDEX idx_pre_commit_checks_timestamp ON pre_commit_checks(timestamp DESC);
```

### security_scans table

Existing table used for secrets scan results:
- `scan_type`: "secret"
- `findings_count`: Total secrets found
- `critical_count`, `high_count`, `medium_count`, `low_count`
- `action_taken`: "blocked", "warning", "passed"

## Cross-Platform Compatibility

### Windows (Git Bash)

**Path handling**:
- Scripts detect Windows via `uname -s` (MINGW*, MSYS*, CYGWIN*)
- Converts Unix paths to Windows paths when needed
- Uses `gradlew.bat` instead of `./gradlew`

**Executable permissions**:
- Not required on Windows
- Scripts work without `chmod +x`

**Commands**:
- `timeout` command available (built-in)
- `psql` from PostgreSQL for Windows
- `jq` for Windows (if in PATH)

### macOS

**Compatibility**:
- Full Unix support
- Standard bash scripts work natively
- Uses `./gradlew` for Gradle

**Required tools**:
```bash
brew install jq
brew install postgresql
```

**Permissions**:
- Requires `chmod +x` for scripts
- Hook requires executable permission

### Linux

**Compatibility**:
- Full Unix support
- Standard bash scripts work natively

**Required tools**:
```bash
sudo apt install jq postgresql-client coreutils
```

**Path handling**:
- Standard Unix paths
- No conversion needed

## Integration with Existing Scripts

### send-notification.sh

Pre-commit hooks use the existing notification system for failures:

```bash
# In check scripts on failure
if [[ ${exit_code} -ne 0 ]]; then
    # Create notification data
    cat <<EOF > /tmp/notification.json
{
  "title": "Pre-commit Check Failed",
  "message": "Format check found violations",
  "severity": "medium",
  "pattern": "format-violation",
  "metadata": {
    "check_type": "format",
    "violations": ${VIOLATION_COUNT}
  }
}
EOF

    # Send notification
    "${SCRIPT_DIR}/send-notification.sh" /tmp/notification.json
fi
```

### detect-owners.sh

Can be used to notify code owners when their changes fail checks:

```bash
# Detect owners for failed files
OWNERS=$("${SCRIPT_DIR}/detect-owners.sh" /tmp/changed_files.json)

# Include in notification
jq --argjson owners "$OWNERS" '.owners = $owners' notification.json
```

## Usage Workflow

### Installation

```bash
# 1. Install hooks
./pipeline-utils/scripts/install-hooks.sh

# 2. Verify installation
ls -la .git/hooks/pre-commit

# 3. Test hooks
git commit --allow-empty -m "Test hooks"
```

### Daily Usage

```bash
# 1. Make changes
vim app/src/main/java/MyClass.kt

# 2. Stage changes
git add app/src/main/java/MyClass.kt

# 3. Commit (hooks run automatically)
git commit -m "Add new feature"

# Hooks run:
# ✓ Format check (2.5s)
# ✓ Lint check (15.2s)
# ✓ Tests (8.1s)
# ✓ Secrets scan (1.9s)
# ✓ Summary generated
#
# All checks passed! Committing...
```

### Handling Failures

```bash
# If format check fails:
✗ Format check failed
Found 5 formatting violation(s) in 3 file(s)

# Fix automatically:
./gradlew ktlintFormat
git add .
git commit -m "Fix formatting"

# Or bypass (not recommended):
git commit --no-verify -m "WIP"
```

## Environment Variables

### Database

```bash
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="woodpecker"
export DB_USER="woodpecker"
export DB_PASSWORD="woodpecker"
```

### Check-Specific

```bash
# Format check
export KTLINT_VERSION="0.50.0"

# Lint check
export LINT_TIMEOUT=300

# Tests
export TEST_TIMEOUT=30

# Secrets
export BLOCK_ON_CRITICAL="true"
export TRUFFLEHOG_VERSION="3.x"
```

### Logging

```bash
export LOG_LEVEL="info"  # debug, info, warn, error
export LOG_FILE="/tmp/pre-commit.log"
```

## Troubleshooting

### Common Issues

1. **Hooks not running**
   - Check `.git/hooks/pre-commit` exists and is executable
   - Run `./pipeline-utils/scripts/install-hooks.sh`

2. **Permission denied**
   - Windows: Not an issue, ignore
   - Linux/macOS: `chmod +x pipeline-utils/scripts/*.sh`

3. **Gradle wrapper not found**
   - Ensure `gradlew` exists in project root
   - Run `chmod +x gradlew` on Unix-like systems

4. **TruffleHog not found**
   - Install: `go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest`
   - Or remove secrets hook from config

5. **Database connection failed**
   - Check PostgreSQL is running
   - Verify environment variables
   - Hooks continue without database (results not stored)

6. **Checks too slow**
   - Reduce `TEST_TIMEOUT`
   - Skip instrumented tests in pre-commit
   - Use `git commit --no-verify` for emergencies

## Performance

### Expected Durations

| Check | Target | Timeout |
|-------|--------|---------|
| Format | 2-5s | 180s |
| Lint | 10-30s | 300s |
| Tests | < 30s | 30s |
| Secrets | 1-5s | N/A |
| Summary | < 1s | N/A |
| **Total** | **< 60s** | - |

### Optimization Tips

1. **Use Gradle daemon**: Enabled by default
2. **Build cache**: Configure `gradle.properties`
3. **Parallel tests**: Add to `gradle.properties`:
   ```properties
   org.gradle.parallel=true
   org.gradle.caching=true
   ```
4. **Selective tests**: Only test changed modules
5. **Exclude files**: Use `.pre-commit-config.yaml` exclude patterns

## Documentation

### Files Created

1. **Scripts** (6 files):
   - `pipeline-utils/scripts/install-hooks.sh`
   - `pipeline-utils/scripts/pre-commit-format.sh`
   - `pipeline-utils/scripts/pre-commit-lint.sh`
   - `pipeline-utils/scripts/pre-commit-tests.sh`
   - `pipeline-utils/scripts/pre-commit-secrets.sh`
   - `pipeline-utils/scripts/pre-commit-summary.sh`

2. **Configuration** (2 files):
   - `.pre-commit-config.yaml`
   - `pipeline-utils/templates/pre-commit-hook.template`

3. **Database** (1 table):
   - Added `pre_commit_checks` table to `pipeline-utils/schema/metrics.sql`

4. **Documentation** (1 file):
   - `pipeline-utils/PRE_COMMIT_HOOKS_GUIDE.md`

### Total Lines of Code

- **Scripts**: ~1,400 lines
- **Configuration**: ~100 lines
- **Documentation**: ~600 lines

## Testing

### Manual Testing

```bash
# 1. Test installation
./pipeline-utils/scripts/install-hooks.sh

# 2. Test each check individually
./pipeline-utils/scripts/pre-commit-format.sh
./pipeline-utils/scripts/pre-commit-lint.sh
./pipeline-utils/scripts/pre-commit-tests.sh
./pipeline-utils/scripts/pre-commit-secrets.sh

# 3. Test summary
./pipeline-utils/scripts/pre-commit-summary.sh

# 4. Test full workflow
git commit --allow-empty -m "Test pre-commit hooks"
```

### Automated Testing

```bash
# Test with intentional violations
echo "object  BadFormatting{fun test()=println}" > test.kt
git add test.kt
git commit -m "Test format failure"  # Should fail

# Test with secrets
echo 'API_KEY="sk-1234567890"' > config.kt
git add config.kt
git commit -m "Test secrets failure"  # Should fail

# Clean up
git reset HEAD
rm test.kt config.kt
```

## Future Enhancements

### Potential Improvements

1. **Parallel execution**: Run checks concurrently
2. **Incremental checks**: Only check changed files
3. **Caching**: Cache check results by commit SHA
4. **Smart skip**: Skip checks if no relevant changes
5. **Remote checks**: Offload to CI for slow checks
6. **Custom rules**: Support custom lint/format rules
7. **IDE integration**: VSCode, Android Studio plugins
8. **Metrics dashboard**: Track pre-commit stats over time

### Integration Opportunities

1. **Woodpecker CI**: Use same checks in pipeline
2. **GitHub Actions**: Pre-commit as GitHub Action
3. **Pre-commit framework**: Use .pre-commit-hooks.yaml format
4. **IDE hooks**: Run on file save in IDE
5. **Git hooks**: More hooks (pre-push, commit-msg, etc.)

## Summary

Feature 2 successfully implements a comprehensive pre-commit hooks system with:

✅ **6 scripts** for installation, checking, and reporting
✅ **Cross-platform support** for Windows, macOS, and Linux
✅ **Database integration** for tracking results
✅ **Automated fixes** for formatting issues
✅ **Secret detection** with severity classification
✅ **Summary reports** with detailed findings
✅ **Configuration file** for customization
✅ **Comprehensive documentation**

The system improves code quality by catching issues before they enter the codebase, reducing CI failures, and enforcing consistent standards across the team.
