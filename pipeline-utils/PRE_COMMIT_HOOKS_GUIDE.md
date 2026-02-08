# Pre-commit Hooks Guide

This guide explains how to use the pre-commit hooks system for automated quality checks before committing code.

## Overview

The pre-commit hooks system runs automated checks before each commit to ensure code quality:
- **Format check**: Validates code formatting with ktlint
- **Lint check**: Runs Android lint to detect code issues
- **Tests**: Executes quick unit tests (target: < 30 seconds)
- **Secrets scan**: Scans for secrets and sensitive data using trufflehog

## Installation

### Quick Install

Run the installation script:

```bash
./pipeline-utils/scripts/install-hooks.sh
```

This will:
1. Detect your .git/hooks directory
2. Create the pre-commit hook
3. Make it executable
4. Create .pre-commit-config.yaml

### Manual Install

If you prefer manual installation:

```bash
# Copy the hook template to .git/hooks
cp pipeline-utils/templates/pre-commit-hook.template .git/hooks/pre-commit

# Make it executable
chmod +x .git/hooks/pre-commit
```

## Usage

### Normal Workflow

The hooks run automatically when you commit:

```bash
# Stage your changes
git add .

# Commit - hooks run automatically
git commit -m "Your commit message"
```

If all checks pass, the commit proceeds. If any check fails, the commit is blocked.

### Bypassing Hooks (Not Recommended)

To bypass the pre-commit checks:

```bash
git commit --no-verify -m "Your commit message"
```

**Warning**: Only use this in exceptional circumstances. Bypassing hooks can introduce bugs, formatting issues, or security vulnerabilities.

### Running Checks Manually

You can run individual checks without committing:

```bash
# Format check
./pipeline-utils/scripts/pre-commit-format.sh

# Lint check
./pipeline-utils/scripts/pre-commit-lint.sh

# Unit tests
./pipeline-utils/scripts/pre-commit-tests.sh

# Secrets scan
./pipeline-utils/scripts/pre-commit-secrets.sh

# Full summary
./pipeline-utils/scripts/pre-commit-summary.sh
```

## Configuration

### .pre-commit-config.yaml

The `.pre-commit-config.yaml` file controls hook behavior:

```yaml
hooks:
  - name: format
    script: pipeline-utils/scripts/pre-commit-format.sh
    pass_fail: true

  - name: lint
    script: pipeline-utils/scripts/pre-commit-lint.sh
    pass_fail: true

  - name: tests
    script: pipeline-utils/scripts/pre-commit-tests.sh
    pass_fail: true

  - name: secrets
    script: pipeline-utils/scripts/pre-commit-secrets.sh
    pass_fail: true

options:
  timeout: 300  # 5 minutes per check
  log_level: info

exclude:
  - "build/"
  - "*.md"
  - "docs/"
```

### Environment Variables

Configure database connections and other settings:

```bash
# Database (for storing check results)
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="woodpecker"
export DB_USER="woodpecker"
export DB_PASSWORD="woodpecker"

# Check-specific settings
export COVERAGE_THRESHOLD=80
export TEST_TIMEOUT=30
```

## Check Details

### 1. Format Check (pre-commit-format.sh)

**Purpose**: Ensures code follows ktlint formatting standards

**Run command**: `./gradlew ktlintCheck`

**On failure**:
- Shows files with formatting violations
- Provides auto-fix command: `./gradlew ktlintFormat`

**Fix formatting issues**:
```bash
./gradlew ktlintFormat
git add .
git commit -m "Fix formatting"
```

### 2. Lint Check (pre-commit-lint.sh)

**Purpose**: Runs Android lint to detect code issues

**Run command**: `./gradlew lint`

**Reports**:
- Errors (block commit)
- Warnings (show but don't block)

**Timeout**: 5 minutes

**Output**: Parses XML or JSON reports from `app/build/reports/`

### 3. Unit Tests (pre-commit-tests.sh)

**Purpose**: Runs quick unit tests before commit

**Run command**: `./gradlew testDebugUnitTest`

**Scope**:
- Unit tests only (no instrumented tests)
- Target duration: < 30 seconds

**Timeout**: 30 seconds (configurable)

**Results**:
- Shows passed/failed/skipped counts
- Lists failed tests with details

### 4. Secrets Scan (pre-commit-secrets.sh)

**Purpose**: Scans for secrets and sensitive data

**Tool**: TruffleHog (https://github.com/trufflesecurity/trufflehog)

**Install TruffleHog**:
```bash
go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest
```

**Severity levels**:
- **Critical**: Verified secrets (blocks commit)
- **High**: Sensitive patterns (AWS, SSH, passwords)
- **Medium**: Potential secrets
- **Low**: Unlikely matches

**Exclusions**: Use `.secretsignore` file:
```
*.test.*
*.mock.*
*Test.kt
```

## Results Storage

All check results are stored in the database:

### pre_commit_checks table

```sql
CREATE TABLE pre_commit_checks (
  id SERIAL PRIMARY KEY,
  commit_sha VARCHAR(40) NOT NULL,
  branch VARCHAR(100) NOT NULL,
  check_type VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL,
  duration_ms INTEGER,
  exit_code INTEGER,
  output TEXT,
  findings JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);
```

### security_scans table

For secrets scans, results are also stored in `security_scans`:
- Scan type: "secret"
- Severity distribution
- Action taken (blocked/warning/passed)

## Troubleshooting

### Hooks Not Running

**Check if hook is installed**:
```bash
ls -la .git/hooks/pre-commit
```

**Make executable**:
```bash
chmod +x .git/hooks/pre-commit
```

### Script Permission Denied

**Fix permissions**:
```bash
chmod +x pipeline-utils/scripts/*.sh
```

### Gradle Wrapper Not Found

**Ensure gradlew exists**:
```bash
ls -la gradlew
```

**Make executable** (Linux/macOS):
```bash
chmod +x gradlew
```

### TruffleHog Not Found

**Install TruffleHog**:
```bash
go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest
```

**Or skip secrets check** (not recommended):
Edit `.pre-commit-config.yaml` to remove the secrets hook

### Database Connection Failed

**Check database is running**:
```bash
psql -h localhost -U woodpecker -d woodpecker
```

**Verify environment variables**:
```bash
echo $DB_HOST $DB_PORT $DB_NAME $DB_USER
```

**Pre-commit hooks will continue without database** (results just won't be stored)

### Checks Too Slow

**Reduce test timeout**:
```bash
export TEST_TIMEOUT=20
```

**Skip checks temporarily**:
```bash
git commit --no-verify -m "WIP"
```

**Adjust in .pre-commit-config.yaml**:
```yaml
check_settings:
  tests:
    max_duration: 20
```

## Platform-Specific Notes

### Windows (Git Bash)

- Use Git Bash for best compatibility
- Scripts handle Windows paths automatically
- `gradlew.bat` is used instead of `./gradlew`
- Permissions not required on Windows

### macOS

- Install required tools:
  ```bash
  brew install jq
  ```
- Permissions handled automatically
- Paths work as expected

### Linux

- Ensure bash is available: `sudo apt install bash`
- Install dependencies:
  ```bash
  sudo apt install jq coreutils
  ```
- Make scripts executable: `chmod +x pipeline-utils/scripts/*.sh`

## Output Examples

### Successful Check

```
=== Pre-commit Checks Summary ===
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

### Failed Check

```
=== Pre-commit Checks Summary ===
────────────────────────────────────────────────────────
Check           Status        Duration       Details
────────────────────────────────────────────────────────
Format          failed        1.230s         Violations found
Lint            passed        14.560s        0E, 1W
Tests           passed        7.890s         142 passed, 0 failed
Secrets         passed        1.750s         None found
────────────────────────────────────────────────────────

Total Checks:    4
Passed:          3
Failed:          1
Total Duration:  25.430s

✗ Some checks failed. Commit blocked.

Detailed Findings:

Format:
  Files with violations:
    - app/src/main/java/com/example/MyClass.kt
    - app/src/main/java/com/example/Utils.kt

To fix formatting issues:
  ./gradlew ktlintFormat
```

## Best Practices

1. **Fix issues immediately**: Don't bypass hooks
2. **Use auto-fix**: Run `./gradlew ktlintFormat` for formatting
3. **Review warnings**: Lint warnings indicate potential issues
4. **Keep tests fast**: Pre-commit tests should complete in < 30 seconds
5. **Never commit secrets**: Use environment variables for secrets
6. **Update .secretsignore**: Add legitimate exclusions
7. **Check the database**: Query results for trends and patterns

## Database Queries

### View recent check results

```sql
SELECT
  commit_sha,
  branch,
  check_type,
  status,
  duration_ms,
  timestamp
FROM pre_commit_checks
ORDER BY timestamp DESC
LIMIT 50;
```

### Check failure rate by type

```sql
SELECT
  check_type,
  COUNT(*) FILTER (WHERE status = 'failed') AS failures,
  COUNT(*) AS total,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / COUNT(*), 2) AS failure_rate
FROM pre_commit_checks
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY check_type
ORDER BY failure_rate DESC;
```

### Average check duration

```sql
SELECT
  check_type,
  ROUND(AVG(duration_ms) / 1000.0, 2) AS avg_seconds
FROM pre_commit_checks
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY check_type
ORDER BY avg_seconds DESC;
```

## Uninstalling

To remove the pre-commit hooks:

```bash
# Remove the hook
rm .git/hooks/pre-commit

# Or run the install script with --uninstall (if supported)
./pipeline-utils/scripts/install-hooks.sh --uninstall
```

## Support

For issues or questions:
- Check logs in the hook output
- Review individual check scripts for details
- Query the database for historical results
- See pipeline-utils/NOTIFICATIONS_GUIDE.md for alerting setup

## Related Documentation

- `pipeline-utils/README.md` - Main utilities overview
- `pipeline-utils/schema/metrics.sql` - Database schema
- `pipeline-utils/scripts/send-notification.sh` - Alerting setup
- `.pre-commit-config.yaml` - Configuration reference
