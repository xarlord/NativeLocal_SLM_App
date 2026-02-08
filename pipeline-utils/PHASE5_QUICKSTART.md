# Phase 5 Quick Start Guide

## Prerequisites

### 1. GitHub CLI Setup
```bash
# Install GitHub CLI
# On Ubuntu/Debian:
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt-get update
sudo apt-get install gh

# Authenticate
gh auth login

# Verify authentication
gh auth status
```

### 2. Database Setup
```bash
# Ensure PostgreSQL is running
docker-compose up -d postgres

# Verify connection
psql -h localhost -U woodpecker -d woodpecker -c "SELECT 1;"

# Tables should already exist from Phase 1
# Verify dependency_updates and security_scans tables exist
psql -h localhost -U woodpecker -d woodpecker -c "\dt dependency_updates security_scans;"
```

### 3. Gradle Project Setup
```bash
# Ensure you have a Gradle project
cd /path/to/your/project

# For this implementation, project structure is:
# - build.gradle or build.gradle.kts
# - gradlew wrapper script
```

## Usage

### Manual Dependency Update Check

```bash
# Navigate to project root
cd C:\Users\plner\claudePlayground

# Run dependency update script
./pipeline-utils/scripts/auto-update-deps.sh
```

**What it does:**
1. Checks for Gradle dependency updates
2. Creates branches for each update
3. Generates PRs from template
4. Stores metadata in database

**Expected output:**
```
2026-02-08 14:30:00 - === Starting Dependency Update Process ===
2026-02-08 14:30:00 - Repository: xarlord/GravityWell
2026-02-08 14:30:01 - Checking for Gradle dependency updates...
2026-02-08 14:30:15 - Found 3 dependency update(s)
2026-02-08 14:30:15 - Processing update: com.example:library (1.0.0 -> 1.2.0)
...
```

### Manual Security Scan

```bash
# Navigate to project root
cd C:\Users\plner\claudePlayground

# Run vulnerability scanner
./pipeline-utils/scripts/triage-vulnerabilities.sh
```

**What it does:**
1. Runs OWASP Dependency Check
2. Parses vulnerability reports
3. Creates GitHub issues for critical/high
4. Stores results in database

**Expected output:**
```
2026-02-08 14:35:00 - === Starting Security Vulnerability Scan ===
2026-02-08 14:35:00 - Repository: xarlord/GravityWell
2026-02-08 14:35:01 - Running OWASP Dependency Check...
...
2026-02-08 14:36:00 - Vulnerabilities found:
2026-02-08 14:36:00 -   Critical: 1
2026-02-08 14:36:00 -   High:     2
...
```

### Pipeline Execution

#### Option 1: Woodpecker Web UI
1. Go to your Woodpecker instance
2. Select the repository
3. Click "New Build"
4. Select `.dependency-automation.yml` pipeline
5. Click "Run"

#### Option 2: Woodpecker CLI
```bash
# Trigger the pipeline
woodpecker-cli build create \
  --repository xarlord/GravityWell \
  --branch main \
  --event manual

# Or use execute command
woodpecker execute .dependency-automation.yml
```

#### Option 3: Scheduled (Automatic)
The pipeline runs automatically:
- **Every Sunday at 2 AM** - Dependency update checks
- **Every push** - Security vulnerability scans

## Database Queries

### Check Dependency Updates
```sql
-- View recent updates
SELECT
  dependency_name,
  old_version,
  new_version,
  update_type,
  status,
  pr_number,
  created_at
FROM dependency_updates
ORDER BY created_at DESC
LIMIT 20;

-- View pending updates
SELECT
  dependency_name,
  old_version,
  new_version,
  pr_url
FROM dependency_updates
WHERE status = 'pending'
ORDER BY created_at;

-- View security fixes
SELECT
  dependency_name,
  new_version,
  vulnerability_severity,
  pr_url
FROM dependency_updates
WHERE has_security_fix = true
ORDER BY created_at DESC;
```

### Check Security Scans
```sql
-- View recent scans
SELECT
  scan_type,
  findings_count,
  critical_count,
  high_count,
  medium_count,
  low_count,
  action_taken,
  timestamp
FROM security_scans
ORDER BY timestamp DESC
LIMIT 20;

-- View critical vulnerabilities
SELECT
  id,
  findings,
  issue_url,
  timestamp
FROM security_scans
WHERE critical_count > 0
ORDER BY timestamp DESC;

-- Statistics by severity
SELECT
  SUM(critical_count) as total_critical,
  SUM(high_count) as total_high,
  SUM(medium_count) as total_medium,
  SUM(low_count) as total_low,
  COUNT(*) as total_scans
FROM security_scans
WHERE timestamp > NOW() - INTERVAL '30 days';
```

## Configuration

### Environment Variables
```bash
# Database connection (set in .woodpecker.yml or CI/CD config)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=woodpecker
export DB_USER=woodpecker
export DB_PASSWORD=woodpecker

# Gradle settings
export GRADLE_USER_HOME=/cache/gradle
export ANDROID_HOME=/opt/android-sdk
```

### Pipeline Triggers
Edit `.dependency-automation.yml`:

```yaml
when:
  event:
    - push
    - pull_request
    - cron
  cron:
    - "0 2 * * 0"  # Change schedule here
  evaluate: 'CI_COMMIT_MESSAGE does not contain "[skip deps]"'
```

### Slack Notifications
Edit `.dependency-automation.yml`:

```yaml
notify-critical:
  image: plugins/slack
  settings:
    webhook: https://hooks.slack.com/services/YOUR/WEBHOOK/URL  # Add your webhook
```

### Severity Thresholds
Edit `triage-vulnerabilities.sh`:

```bash
# Line ~180: Modify CVSS thresholds
if (( $(echo "$cvss_score >= 9.0" | bc -l) )); then
    echo "critical"  # Change threshold
elif (( $(echo "$cvss_score >= 7.0" | bc -l) )); then
    echo "high"      # Change threshold
fi
```

## Templates

### Customizing PR Template
Edit `pipeline-utils/templates/dep-update-pr.md`:
- Add custom sections
- Modify testing instructions
- Change rollback procedures
- Add project-specific requirements

### Customizing Issue Template
Edit `pipeline-utils/templates/vulnerability-issue.md`:
- Add project-specific remediation steps
- Include team contacts
- Add compliance requirements
- Modify severity guidelines

## Troubleshooting

### Issue: GitHub CLI not authenticated
```bash
# Error: GitHub CLI not authenticated. Run: gh auth login
# Solution:
gh auth login
# Follow the prompts to authenticate
```

### Issue: Database connection failed
```bash
# Error: Could not connect to PostgreSQL
# Solution:
docker-compose up -d postgres
# Wait for database to start
# Check connection:
psql -h localhost -U woodpecker -d woodpecker
```

### Issue: No Gradle project found
```bash
# Error: No Gradle project found
# Solution:
# Ensure you're in the correct directory
cd simpleGame  # or your project directory
# Verify gradlew exists
ls -la gradlew
```

### Issue: PR creation failed
```bash
# Error: Failed to create PR
# Solution:
# Check branch exists
git branch -a
# Check if PR already exists
gh pr list --state all
# Check GitHub permissions
gh repo view
```

### Issue: Vulnerability scan returns no results
```bash
# Check if OWASP Dependency Check is installed
dependency-check --version

# If not installed, script falls back to manual scan
# Check manual scan log
cat .security-scan.log

# Review dependency list
cat .gradle-deps.txt
```

## Integration with Existing CI/CD

### Add to Main Pipeline
Add to `.woodpecker.yml`:

```yaml
steps:
  # ... existing steps ...

  security-scan:
    image: android-ci:latest
    commands:
      - ./pipeline-utils/scripts/triage-vulnerabilities.sh
    environment:
      GRADLE_USER_HOME: /cache/gradle

  # ... more steps ...
```

### Chain Pipelines
Make dependency automation a separate pipeline that runs on schedule:

```yaml
# In .dependency-automation.yml
when:
  event:
    - cron
  cron:
    - "0 2 * * 0"
```

### Conditional Execution
Skip dependency checks with commit message:

```bash
git commit -m "Fix bug [skip deps]"
```

## Monitoring

### Check Logs
```bash
# Dependency update log
cat .dependency-update.log

# Security scan log
cat .security-scan.log

# Woodpecker build logs
# Check Woodpecker UI
```

### Database Monitoring
```sql
-- Updates in last 7 days
SELECT COUNT(*) as updates_last_7_days
FROM dependency_updates
WHERE created_at > NOW() - INTERVAL '7 days';

-- Scans in last 7 days
SELECT COUNT(*) as scans_last_7_days
FROM security_scans
WHERE timestamp > NOW() - INTERVAL '7 days';

-- Critical vulnerabilities
SELECT COUNT(*) as open_critical
FROM security_scans
WHERE critical_count > 0
AND timestamp > NOW() - INTERVAL '30 days';
```

### GitHub Dashboard
1. Check open PRs with "dependencies" label
2. Check open issues with "security" label
3. Review automated PR/issue quality
4. Merge after testing

## Best Practices

1. **Review Automated PRs**
   - Don't auto-merge dependency updates
   - Test thoroughly before merging
   - Pay special attention to major updates

2. **Security Issues**
   - Address critical vulnerabilities immediately
   - Plan high-priority fixes within 1 week
   - Document workarounds if no fix available

3. **Database Maintenance**
   - Clean up old records periodically
   - Monitor database growth
   - Archive old updates if needed

4. **Notification Management**
   - Configure Slack for critical issues only
   - Avoid notification fatigue
   - Use labels for filtering

5. **Testing**
   - Always run tests after dependency updates
   - Use staging environment for validation
   - Monitor production after updates

## Next Steps

1. **Set up GitHub authentication** for your environment
2. **Configure Slack webhook** for critical notifications
3. **Test with real dependencies** in your project
4. **Review and customize templates** for your needs
5. **Monitor first few automated PRs/issues**
6. **Adjust thresholds and schedules** based on experience

## Support

For issues or questions:
1. Check the main Phase 5 summary: `pipeline-utils/PHASE5_SUMMARY.md`
2. Review the scripts: `pipeline-utils/scripts/*.sh`
3. Check database schema: `pipeline-utils/schema/metrics.sql`
4. Review Woodpecker logs
5. Check GitHub issues in repository

---

**Last Updated:** 2026-02-08
**Phase:** 5 - Dependency Management Automation
**Status:** ✅ Complete
