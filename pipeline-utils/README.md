# Pipeline Utils

Shared utilities, configurations, and templates for autonomous CI/CD features.

## Directory Structure

```
pipeline-utils/
├── schema/           # Database schemas and migrations
├── scripts/          # Utility scripts for pipelines
├── config/           # Configuration files
├── templates/        # Notification and report templates
└── README.md         # This file
```

## Components

### Database Schema (`schema/`)

- **metrics.sql** - PostgreSQL schema for tracking:
  - Build metrics (duration, resources, results)
  - Failure patterns (classification, remediation)
  - Performance baselines
  - Code coverage history
  - Dependency updates
  - Security scan results
  - Resource usage
  - Code ownership
  - Notification history

**Usage:**
```bash
# Apply schema to database
psql -h localhost -U woodpecker -d woodpecker < schema/metrics.sql
```

### Scripts (`scripts/`)

Utility scripts for pipeline automation:

- **retry-command.sh** - Execute commands with exponential backoff
- **diagnose-failure.sh** - Analyze build failures (TODO)
- **analyze-project-size.sh** - Calculate resource requirements (TODO)
- **check-cache-freshness.sh** - Validate cache status (TODO)
- **smart-test-runner.sh** - Run only affected tests (TODO)
- **create-coverage-comment.sh** - Generate PR comments (TODO)

**Usage in .woodpecker.yml:**
```yaml
steps:
  build-with-retry:
    image: android-ci:latest
    commands:
      - ./pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug
```

### Configuration (`config/`)

Configuration files for autonomous features:

- **failure-patterns.yaml** - Database of failure patterns
  - Pattern detection regex
  - Severity levels
  - Remediation steps
  - Auto-fix capability flags

**Extending the pattern database:**
```yaml
patterns:
  - name: "YourPattern"
    severity: "medium"
    regex: "your.regex.here"
    remediation: "How to fix this issue"
    auto_fixable: false
```

### Templates (`templates/`)

Notification and report templates (TODO):
- PR comment templates
- Slack message templates
- Email templates
- Issue templates

## Installation

### 1. Initial Setup

```bash
# Copy to your project
cp -r pipeline-utils/ /path/to/your/project/

# Setup database
psql -h localhost -U woodpecker -d woodpecker < pipeline-utils/schema/metrics.sql
```

### 2. Make Scripts Executable

```bash
chmod +x pipeline-utils/scripts/*.sh
```

### 3. Configure Paths

Update `.woodpecker.yml` to reference scripts:

```yaml
steps:
  build:
    image: android-ci:latest
    commands:
      - ./pipeline-utils/scripts/retry-command.sh ./gradlew assembleDebug
```

## Usage Examples

### Automatic Retry

```bash
# Use default settings (3 retries, exponential backoff)
./retry-command.sh ./gradlew test

# Custom retry count
./retry-command.sh --max-retries=5 ./gradlew test

# Linear backoff
./retry-command.sh --backoff=linear ./gradlew assembleDebug
```

### Failure Diagnosis

```bash
# Analyze build logs
./diagnose-failure.sh build.log

# Get remediation suggestions
./diagnose-failure.sh build.log --suggest-fix
```

### Project Size Analysis

```bash
# Get resource recommendations
./analyze-project-size.sh

# Output:
# Recommended memory: 6GB
# Recommended CPU: 3 cores
# Estimated build time: 5-8 minutes
```

### Smart Test Selection

```bash
# Run only affected tests
./smart-test-runner.sh $CI_COMMIT_PREV $CI_COMMIT

# Output:
# Changed modules: app, data
# Running tests for :app
# Running tests for :data
# 45% time saved (skipped :domain, :ui)
```

## Database Queries

### Get Build Success Rate (Last 7 Days)

```sql
SELECT
  ROUND(100.0 * COUNT(*) FILTER (WHERE success = TRUE) / COUNT(*), 2) AS success_rate
FROM build_metrics
WHERE timestamp > NOW() - INTERVAL '7 days';
```

### Find Common Failure Patterns

```sql
SELECT
  pattern_type,
  severity,
  COUNT(*) AS occurrences,
  MAX(last_seen) AS most_recent
FROM failure_patterns
WHERE last_seen > NOW() - INTERVAL '30 days'
GROUP BY pattern_type, severity
ORDER BY occurrences DESC
LIMIT 10;
```

### Get Average Build Time by Branch

```sql
SELECT
  branch,
  ROUND(AVG(duration_seconds), 2) AS avg_duration,
  COUNT(*) AS build_count
FROM build_metrics
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY branch
ORDER BY avg_duration DESC;
```

### Check Performance Regressions

```sql
SELECT
  b.benchmark_name,
  b.branch,
  b.score AS current_score,
  p.avg_score AS baseline_avg,
  ROUND((b.score - p.avg_score) / p.avg_score * 100, 2) AS percent_change
FROM performance_baselines b
CROSS JOIN LATERAL (
  SELECT AVG(score) AS avg_score
  FROM performance_baselines
  WHERE benchmark_name = b.benchmark_name
    AND branch = b.branch
    AND timestamp > b.timestamp - INTERVAL '90 days'
) p
WHERE b.timestamp > NOW() - INTERVAL '7 days'
  AND b.score < p.avg_score * 0.95  -- 5% regression threshold
ORDER BY percent_change ASC;
```

## Maintenance

### Cleanup Old Records

```sql
-- Delete records older than 90 days
SELECT cleanup_old_records(90);
```

### Update Failure Patterns

```bash
# Edit the pattern database
vim config/failure-patterns.yaml

# Validate syntax
python3 -c 'import yaml; yaml.safe_load(open("config/failure-patterns.yaml"))'
```

### Backup Database

```bash
# Backup schema and data
pg_dump -h localhost -U woodpecker woodpecker > backup_$(date +%Y%m%d).sql
```

## Development

### Adding New Scripts

1. Create script in `scripts/`
2. Make it executable: `chmod +x scripts/your-script.sh`
3. Add usage documentation to this README
4. Test thoroughly in a pipeline

### Adding New Patterns

1. Edit `config/failure-patterns.yaml`
2. Add pattern with regex, severity, remediation
3. Test with sample log files
4. Update documentation

## Troubleshooting

### Script Not Found

```bash
# Ensure scripts are in the correct location
ls -la pipeline-utils/scripts/

# Check file permissions
ls -la pipeline-utils/scripts/retry-command.sh
# Should show: -rwxr-xr-x
```

### Database Connection Issues

```bash
# Test connection
psql -h localhost -U woodpecker -d woodpecker -c "SELECT 1;"

# Check schema exists
\dt build_metrics
```

### Pattern Not Matching

```bash
# Test regex pattern
echo "Error text here" | grep -E "your.regex.here"

# Enable debug mode
export DEBUG=1
./diagnose-failure.sh build.log
```

## Contributing

When adding new features:

1. Follow existing code style
2. Add comprehensive comments
3. Update this README
4. Test thoroughly
5. Document any breaking changes

## License

Same as parent project.

## Contact

For issues or questions, contact the DevOps team.
