# Quick Reference: Intelligent Notifications System

## Overview

The Phase 7 Intelligent Notifications system provides automated, actionable notifications when builds fail. It analyzes failures, detects code owners, and sends targeted notifications through multiple channels.

## Quick Start

### 1. Configure Environment Variables

```bash
# Database connection
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=woodpecker
export DB_USER=woodpecker
export DB_PASSWORD=woodpecker

# Notification channels
export NOTIFY_CHANNELS=slack,github,email

# Slack
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# GitHub
export GITHUB_TOKEN="ghp_YOUR_GITHUB_TOKEN"
export GITHUB_REPO="owner/repo"

# Email (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT=587
export SMTP_USER="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"
export EMAIL_FROM="ci@example.com"
```

### 2. Create CODEOWNERS File (Optional but Recommended)

Create `.github/CODEOWNERS` in your repository:

```
# Frontend team
*.kt @frontend-team
app/src/main/** @alice @bob

# Backend team
*.java @backend-team
api/** @charlie

# Infrastructure
.dockerfile @devops-team
*.yml @devops-team

# Default owner
* @team-lead
```

### 3. Enable in Woodpecker Pipeline

Add to your `.woodpecker.yml` or include `.notifications.yml`:

```yaml
pipeline:
  # ... your build steps ...

notify-on-failure:
  image: android-ci:latest
  when:
    status: [failure]
  environment:
    SLACK_WEBHOOK_URL:
      from_secret: slack_webhook
    GITHUB_TOKEN:
      from_secret: github_token
  commands:
    - pipeline-utils/scripts/analyze-failure.sh build.log
    - pipeline-utils/scripts/detect-owners.sh
    - export NOTIFY_CHANNELS=slack,github
    - pipeline-utils/scripts/send-notification.sh
```

## Usage Examples

### Manual Failure Analysis

```bash
# Analyze a build log
pipeline-utils/scripts/analyze-failure.sh build.log /tmp/failure.json

# View the analysis
cat /tmp/failure.json | jq '.'

# Check database for stored notifications
psql -h localhost -U woodpecker -d woodpecker
SELECT * FROM notification_history ORDER BY created_at DESC LIMIT 5;
```

### Detect Code Owners

```bash
# For current commit
pipeline-utils/scripts/detect-owners.sh /tmp/owners.json

# View owners
cat /tmp/owners.json | jq '.[] | {name, github_username, files_owned}'

# Get comma-separated list
cat /tmp/owners.json | jq -r '[.[].github_username] | join(",")'
```

### Send Notifications

```bash
# Send to specific channels
export NOTIFY_CHANNELS=slack
pipeline-utils/scripts/send-notification.sh 1234

# Send to multiple channels
export NOTIFY_CHANNELS=slack,github,email
pipeline-utils/scripts/send-notification.sh "" /tmp/notification-data.json

# Send with custom recipients
export NOTIFY_CHANNELS=email
pipeline-utils/scripts/send-notification.sh 1234 /tmp/data.json
```

## Notification Channels

### Slack

**Requirements:**
- Slack webhook URL
- Channel configured to receive webhooks

**Features:**
- Rich block formatting
- Action buttons (View Logs, Retry Build)
- Color-coded by severity
- Threaded responses

**Setup:**
1. Create Slack app at api.slack.com
2. Enable Incoming Webhooks
3. Copy webhook URL to secrets
4. Set `SLACK_WEBHOOK_URL` environment variable

### GitHub

**Requirements:**
- GitHub personal access token
- Repository access

**Features:**
- PR comments for failed builds
- Issues for critical failures
- @mentions for code owners
- Markdown formatting

**Setup:**
1. Create GitHub token with `repo:status` and `public_repo` scopes
2. Add to Woodpecker secrets as `github_token`
3. Set `GITHUB_REPO` to `owner/repo`

### Email

**Requirements:**
- SMTP server (or use Gmail)
- Email credentials

**Features:**
- Professional email format
- Personalized greetings
- Direct links to build logs
- Unsubscribe support (future)

**Setup:**
1. Configure SMTP credentials
2. Set environment variables
3. Ensure `sendmail` is available in Docker image

## Failure Patterns

The system uses `pipeline-utils/config/failure-patterns.yaml` to classify failures:

```yaml
patterns:
  - name: "OutOfMemoryError"
    severity: "high"
    category: "infrastructure"
    regex: "OutOfMemoryError"
    auto_fixable: true
    auto_fix_script: "fix-oom.sh"
```

**Severity Levels:**
- **Critical** - Blocks all development (e.g., secrets detected)
- **High** - Significant impact (e.g., OOM, compilation errors)
- **Medium** - Moderate impact (e.g., test failures)
- **Low** - Minor issues (e.g., lint warnings)

**Categories:**
- Infrastructure - Environment/tool issues
- Code - Source code problems
- Tests - Test failures
- Dependencies - Dependency resolution
- Security - Security vulnerabilities

## Database Tables

### notification_history

Track all notifications sent by the system.

```sql
-- View recent notifications
SELECT
    id,
    notification_type,
    channel,
    title,
    sent,
    delivery_status,
    created_at
FROM notification_history
ORDER BY created_at DESC
LIMIT 10;

-- View failed notifications
SELECT * FROM notification_history
WHERE delivery_status = 'failed'
ORDER BY created_at DESC;

-- Summary by channel
SELECT
    channel,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE sent = true) as sent,
    COUNT(*) FILTER (WHERE sent = false) as failed
FROM notification_history
GROUP BY channel;
```

### failure_patterns

Track recurring failure patterns.

```sql
-- View top failure patterns
SELECT
    pattern_type,
    severity,
    COUNT(*) as occurrences,
    MAX(last_seen) as most_recent,
    auto_fixable
FROM failure_patterns
WHERE last_seen > NOW() - INTERVAL '30 days'
GROUP BY pattern_type, severity, auto_fixable
ORDER BY occurrences DESC;

-- View auto-fixable failures
SELECT
    pattern_type,
    COUNT(*) as occurrences,
    remediation
FROM failure_patterns
WHERE auto_fixable = true
GROUP BY pattern_type;
```

### code_ownership

File to owner mappings.

```sql
-- View all owners
SELECT
    owner_name,
    github_username,
    COUNT(*) as files_owned,
    MAX(last_verified) as last_updated
FROM code_ownership
GROUP BY owner_name, github_username
ORDER BY files_owned DESC;

-- View owners for specific file pattern
SELECT * FROM code_ownership
WHERE 'app/src/main/MainActivity.kt' ~ file_pattern;
```

## Troubleshooting

### Notifications Not Sending

1. **Check environment variables:**
   ```bash
   env | grep -E "(SLACK|GITHUB|SMTP|NOTIFY)"
   ```

2. **Check database connection:**
   ```bash
   psql -h localhost -U woodpecker -d woodpecker -c "SELECT 1"
   ```

3. **Check notification status:**
   ```sql
   SELECT * FROM notification_history
   WHERE delivery_status = 'failed'
   ORDER BY created_at DESC;
   ```

4. **View error messages:**
   ```sql
   SELECT
       channel,
       error_message,
       created_at
   FROM notification_history
   WHERE sent = false
   ORDER BY created_at DESC;
   ```

### CODEOWNERS Not Working

1. **Check file location:**
   ```bash
   ls -la .github/CODEOWNERS docs/CODEOWNERS CODEOWNERS
   ```

2. **Verify format:**
   ```bash
   grep -vE '^#|^$' .github/CODEOWNERS
   ```

3. **Test pattern matching:**
   ```bash
   pipeline-utils/scripts/detect-owners.sh /tmp/owners.json
   cat /tmp/owners.json | jq '.'
   ```

### Wrong Owners Detected

1. **Update .mailmap** for author name mapping:
   ```
   Jane Doe <jane@example.com> <jane@oldcompany.com>
   ```

2. **Override with CODEOWNERS:**
   ```
   app/src/** @correct-owner
   ```

3. **Manually update database:**
   ```sql
   INSERT INTO code_ownership (file_pattern, owner_name, github_username, ownership_strength)
   VALUES ('app/src/**', 'Correct Owner', '@correct-owner', 1.0);
   ```

## Best Practices

### 1. Create CODEOWNERS File
- Define clear ownership for each module
- Use team mentions for shared code
- Keep it updated as team changes

### 2. Customize Templates
- Edit templates in `pipeline-utils/templates/`
- Match your team's communication style
- Include project-specific links

### 3. Monitor Delivery
- Check `notification_history` regularly
- Investigate failed deliveries
- Update secrets as needed

### 4. Tune Failure Patterns
- Review recurring failures
- Add custom patterns to `failure-patterns.yaml`
- Update remediation steps

### 5. Set Notification Rules
- Use `NOTIFY_CHANNELS` to control routing
- Configure branch-based rules
- Set severity thresholds

## Integration with Other Phases

### Phase 2 (Self-Healing)
- Detects auto-fixable failures
- Suggests remediation scripts
- Tracks fix application

### Phase 5 (Dependencies)
- Notifies on dependency issues
- Alerts on security vulnerabilities
- Tracks update failures

### Phase 8 (Security)
- Immediate alerts on secrets detected
- Critical severity notifications
- Security team routing

## Advanced Configuration

### Custom Notification Channels

Add new channels in `send-notification.sh`:

```bash
discord)
    # Discord webhook implementation
    send_discord "${rendered}"
    ;;
```

### Conditional Notifications

Use severity to filter:

```bash
if [ "$severity" != "low" ]; then
    # Send notification
fi
```

### Rate Limiting

Prevent notification spam:

```sql
-- Check recent notifications
SELECT COUNT(*) FROM notification_history
WHERE build_id = 1234
  AND created_at > NOW() - INTERVAL '1 hour';
```

## Support and Documentation

- **Full Summary:** `pipeline-utils/PHASE7_SUMMARY.md`
- **Progress Log:** `progress_autonomy.md`
- **Database Schema:** `pipeline-utils/schema/metrics.sql`
- **Failure Patterns:** `pipeline-utils/config/failure-patterns.yaml`

---

**Need Help?**
1. Check logs: `/tmp/failure-analysis.json`
2. Query database: `SELECT * FROM notification_history`
3. Review templates: `pipeline-utils/templates/`
4. Enable verbose mode: Add `set -x` to scripts
