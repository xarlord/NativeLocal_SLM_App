# Issue Triage Automation - Implementation Summary

## Overview

Feature 5 - Issue Triage Automation has been successfully implemented. This system provides automated classification, duplicate detection, smart assignment, complexity estimation, and weekly reporting for GitHub issues.

## Created Scripts

### 1. classify-issue.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\classify-issue.sh`

**Purpose:** Classify issue type based on title and body content

**Categories:**
- bug - Error reports, crashes, failures
- feature - New feature requests
- enhancement - Improvements and optimizations
- documentation - Documentation issues
- performance - Performance-related issues
- security - Security vulnerabilities
- question - Questions and help requests

**Usage:**
```bash
./classify-issue.sh {issue_number}
```

**Features:**
- Keyword matching using configurable keywords from `issue-triage.yaml`
- Applies labels to GitHub issues
- Logs classification to `issue_triage` database table
- Confidence scoring (default 0.70)
- Removes common stop words for better matching

### 2. detect-duplicates.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\detect-duplicates.sh`

**Purpose:** Find potential duplicate issues using similarity analysis

**Usage:**
```bash
./detect-duplicates.sh {issue_number}
```

**Features:**
- Uses GitHub search API to find similar issues
- Calculates Jaccard similarity score (word overlap)
- Configurable threshold (default: 0.7 = 70%)
- Adds "duplicate" label when similarity exceeds threshold
- Posts comment with reference to original issue
- Logs to `issue_duplicates` database table
- Skips already-labeled duplicates

**Algorithm:**
```
Similarity = Intersection(Issue1_keywords, Issue2_keywords) / Union(Issue1_keywords, Issue2_keywords)
```

### 3. assign-issue.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\assign-issue.sh`

**Purpose:** Smart assignment based on code ownership patterns

**Usage:**
```bash
./assign-issue.sh {issue_number}
```

**Features:**
- Parses issue for file paths and module references
- Queries `code_ownership` database table for owners
- Assigns to up to 3 GitHub usernames via gh CLI
- Falls back to default assignee from config
- Skips if already assigned
- Posts assignment comment with reasoning
- Logs to `issue_assignments` database table

**Assignment Priority:**
1. Code ownership based on file/module mentions
2. Default assignee from configuration
3. Skip (leave unassigned)

### 4. link-issues-to-commits.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\link-issues-to-commits.sh`

**Purpose:** Link commits to issues based on commit message references

**Usage:**
```bash
./link-issues-to-commits.sh [commit_range]
# Default: HEAD~100..HEAD
```

**Features:**
- Scans commit messages for issue references (#123)
- Recognizes closing keywords: closes, fixes, resolves
- Adds commit reference comments to issues
- Applies "in-progress" label for closing commits
- Logs to `issue_commits` database table
- Prevents duplicate linking

**Supported Patterns:**
- `#123`
- `closes #123`
- `fixes #123`
- `resolves #123`

### 5. estimate-complexity.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\estimate-complexity.sh`

**Purpose:** Estimate issue complexity on a 1-5 scale

**Usage:**
```bash
./estimate-complexity.sh {issue_number}
```

**Complexity Scale:**
- **1/5** - Trivial: Quick fix, minimal changes (~1 hour)
- **2/5** - Low: Simple changes, well-defined scope (~4 hours)
- **3/5** - Medium: Moderate changes (~2 days)
- **4/5** - High: Complex changes, multiple components (~1 week)
- **5/5** - Critical: Major refactoring or architecture (~2 weeks)

**Factors (Configurable Weights):**
- Lines of code estimate (default weight: 0.3)
- Files affected count (default weight: 0.2)
- Keyword analysis (default weight: 0.5)
- Historical data from similar issues (30% blend)

**Features:**
- Applies `complexity-X` labels (complexity-1 through complexity-5)
- Posts detailed complexity breakdown comment
- Logs to `issue_complexity` database table
- Uses keyword heuristics for estimation

### 6. generate-issue-report.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\generate-issue-report.sh`

**Purpose:** Generate weekly issue triage report

**Usage:**
```bash
./generate-issue-report.sh [--format markdown|html] [--output file] [--days N]
```

**Report Sections:**
1. **Summary** - New, closed, unassigned, stale issue counts
2. **New Issues This Week** - List of newly created issues
3. **Closed Issues This Week** - List of resolved issues
4. **Issues by Label** - Breakdown by bug, feature, etc.
5. **Unassigned Issues** - Issues needing assignment
6. **Stale Issues** - Issues with no activity > 7 days
7. **Duplicate Detection Results** - Statistics on duplicates found
8. **Complexity Distribution** - Complexity score breakdown
9. **Recommendations** - Actionable insights based on data

**Output Format:** Markdown (HTML planned for future)

## Helper Scripts

### classify-new-issues.sh
**Purpose:** Batch classify all new issues from the last N days

**Usage:**
```bash
./classify-new-issues.sh [days]
# Default: 7 days
```

### assign-unassigned-issues.sh
**Purpose:** Batch assign all unassigned issues

**Usage:**
```bash
./assign-unassigned-issues.sh [limit]
# Default: 20 issues
```

## Configuration

### issue-triage.yaml
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\config\issue-triage.yaml`

**Key Settings:**

```yaml
# Classification keywords (customizable)
classification_keywords:
  bug:
    - crash
    - error
    - broken
    # ... more keywords

# Duplicate detection threshold
duplicate_threshold: 0.7  # 70% similarity

# Default assignee
default_assignee: ""

# Complexity weights (must sum to 1.0)
complexity_factors:
  lines_of_code_weight: 0.3
  files_affected_weight: 0.2
  keyword_weight: 0.5

# Report settings
report:
  format: markdown
  report_days: 7
```

## Database Schema

### New Tables Created

**issue_triage**
```sql
- issue_number (integer, unique)
- classification (varchar)
- confidence (numeric)
- labels (text[])
- classified_at (timestamp)
```

**issue_duplicates**
```sql
- issue_number (integer)
- duplicate_of (integer)
- similarity_score (numeric)
- detected_at (timestamp)
- confirmed (boolean)
```

**issue_assignments**
```sql
- issue_number (integer)
- assigned_to (varchar)
- assignment_method (varchar)
- file_pattern (varchar)
- assigned_at (timestamp)
```

**issue_complexity**
```sql
- issue_number (integer, unique)
- issue_title (text)
- complexity_score (integer)
- lines_estimate (integer)
- files_estimate (integer)
- keyword_score (integer)
```

**issue_commits**
```sql
- issue_number (integer)
- commit_hash (varchar)
- commit_url (text)
- closes_issue (boolean)
- linked_at (timestamp)
```

### Views Created

- `v_issue_classification_summary` - Classification stats
- `v_duplicate_detection_summary` - Duplicate detection metrics
- `v_assignment_summary` - Assignment distribution
- `v_complexity_distribution` - Complexity breakdown
- `v_recent_issue_activity` - Recent triage activity

## Woodpecker Pipeline

### .woodpecker-issue-triage.yml
**Location:** `C:\Users\plner\claudePlayground\.woodpecker-issue-triage.yml`

**Trigger:** Weekly cron job

**Pipeline Steps:**
1. **classify-new** - Classify new issues from last 7 days
2. **detect-duplicates** - Check recent issues for duplicates
3. **assign-unassigned** - Assign unassigned issues
4. **estimate-complexity** - Estimate complexity for new issues
5. **link-commits** - Link recent commits to issues
6. **weekly-report** - Generate and output weekly report
7. **send-notifications** - Send report notifications

**Manual Trigger:** Can be adapted for manual execution by changing `when.event` to `manual`

## Triage Rules

### Classification Rules

Issues are classified based on keyword matching:

**Bug Indicators:**
- crash, error, broken, doesn't work, failing, fix, bug, problem

**Feature Indicators:**
- add, implement, new feature, would like, request

**Enhancement Indicators:**
- improve, enhance, better, optimize, refactor

**Documentation Indicators:**
- docs, readme, documentation, guide, tutorial

**Performance Indicators:**
- slow, performance, optimize, faster, lag, speed

**Security Indicators:**
- security, vulnerability, exploit, attack, CVE

**Question Indicators:**
- how, what, why, when, where, help, ?

### Duplicate Detection Rules

1. Search for issues with similar titles (top 20 results)
2. Calculate Jaccard similarity based on keyword overlap
3. Mark as duplicate if similarity >= 0.7 (configurable)
4. Comment with reference to original issue
5. Apply "duplicate" label

### Assignment Rules

1. Extract file paths and module references from issue
2. Query `code_ownership` table for matching patterns
3. Sort by ownership strength (highest first)
4. Assign to top 3 owners (configurable)
5. Fall back to default assignee if no owners found
6. Skip if already assigned

### Complexity Estimation Rules

**Score Calculation:**
```
Lines Score = min(lines / 1000, 1.0) * 0.3
Files Score = min(files / 20, 1.0) * 0.2
Keyword Score = min(keywords / 15, 1.0) * 0.5
Total Score = Lines Score + Files Score + Keyword Score
Complexity = round(Total Score * 4 + 1)
```

**Keyword Scores:**
- High complexity (+5): refactor, rewrite, redesign, architecture, migration
- Medium complexity (+2): feature, enhancement, implement, add
- Low complexity (+1): minor, trivial, simple, small, typo

**Historical Adjustment:**
- Blend with historical average from similar issues (70/30 weight)

## Integration with Existing Scripts

### Uses code_ownership Table
The assignment script queries the existing `code_ownership` table (from `detect-owners.sh`) to find owners based on file patterns.

### Uses send-notification.sh
The report generator can send notifications using the existing `send-notification.sh` script.

### Follows Existing Patterns
All scripts follow the same patterns as existing pipeline scripts:
- Helper functions for logging and database queries
- Environment variable configuration
- gh CLI for GitHub operations
- Database integration with PostgreSQL
- Error handling and rate limiting

## Rate Limiting

To avoid GitHub API rate limits:

- Default 1 second delay between API calls
- Configurable via `api_call_delay` in config
- Automatic retry with exponential backoff
- Batch processing with sleep intervals

## Setup Instructions

1. **Create database tables:**
   ```bash
   psql -h localhost -U woodpecker -d woodpecker -f pipeline-utils/schema/issue-triage.sql
   ```

2. **Configure settings:**
   Edit `pipeline-utils/config/issue-triage.yaml` to customize:
   - Classification keywords
   - Duplicate threshold
   - Default assignee
   - Complexity weights

3. **Test individual scripts:**
   ```bash
   ./pipeline-utils/scripts/classify-issue.sh 123
   ./pipeline-utils/scripts/detect-duplicates.sh 123
   ./pipeline-utils/scripts/assign-issue.sh 123
   ```

4. **Run batch operations:**
   ```bash
   ./pipeline-utils/scripts/classify-new-issues.sh 7
   ./pipeline-utils/scripts/assign-unassigned-issues.sh 20
   ```

5. **Enable Woodpecker pipeline:**
   - Copy `.woodpecker-issue-triage.yml` to `.woodpecker/` directory
   - Or rename to `.woodpecker.yml` for automatic weekly runs
   - Configure Woodpecker secrets for database and GitHub tokens

6. **Generate weekly report:**
   ```bash
   ./pipeline-utils/scripts/generate-issue-report.sh
   ```

## Environment Variables

Required for database and GitHub access:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=woodpecker
DB_USER=woodpecker
DB_PASSWORD=your_password

# GitHub
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
GITHUB_REPO=owner/repo

# Issue Triage (optional, overrides config)
DUPLICATE_THRESHOLD=0.7
DEFAULT_ASSIGNEE=username
REPORT_DAYS=7

# Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
NOTIFY_CHANNELS=slack
```

## Troubleshooting

### "GitHub CLI is not authenticated"
Run: `gh auth login`

### "Failed to fetch issue #123"
Check GitHub token permissions and issue number

### "No code owners found for file"
Ensure `code_ownership` table is populated by running `detect-owners.sh`

### "Rate limit exceeded"
Increase `api_call_delay` in config or reduce batch size

### "Database connection failed"
Verify database is running and credentials are correct

## Future Enhancements

Potential improvements for future iterations:

1. **ML-based Classification** - Train model on historical issues
2. **Semantic Similarity** - Use embeddings for better duplicate detection
3. **Auto PR Creation** - Generate PRs for simple issues
4. **HTML Reports** - Rich HTML format for reports
5. **Slack Integration** - Direct Slack posting for reports
6. **Issue Aging** - Automatic stale issue closing
7. **Predictive Assignment** - ML-based assignee prediction
8. **Dependency Tracking** - Track issue dependencies and blocking

## Files Created

### Scripts (8 files)
1. `pipeline-utils/scripts/classify-issue.sh` - Main classification script
2. `pipeline-utils/scripts/detect-duplicates.sh` - Duplicate detection
3. `pipeline-utils/scripts/assign-issue.sh` - Smart assignment
4. `pipeline-utils/scripts/link-issues-to-commits.sh` - Commit linking
5. `pipeline-utils/scripts/estimate-complexity.sh` - Complexity estimation
6. `pipeline-utils/scripts/generate-issue-report.sh` - Weekly reports
7. `pipeline-utils/scripts/classify-new-issues.sh` - Batch classification
8. `pipeline-utils/scripts/assign-unassigned-issues.sh` - Batch assignment

### Configuration (1 file)
9. `pipeline-utils/config/issue-triage.yaml` - Triage settings

### Pipeline (1 file)
10. `.woodpecker-issue-triage.yml` - Weekly automation pipeline

### Database Schema (1 file)
11. `pipeline-utils/schema/issue-triage.sql` - Database tables and views

## Summary

The Issue Triage Automation system is now fully implemented and ready for use. It provides:

- **Automated Classification** - Issues automatically categorized by type
- **Duplicate Detection** - Potential duplicates identified and flagged
- **Smart Assignment** - Issues assigned based on code ownership
- **Commit Linking** - Issues linked to relevant commits
- **Complexity Estimation** - Development effort estimated
- **Weekly Reports** - Comprehensive triage summaries

All scripts integrate seamlessly with existing infrastructure, follow established patterns, and include comprehensive database logging for tracking and analysis.
