#!/bin/bash
# rollback-deployment.sh
# Rolls back a deployment to the previous stable version
# Updates the last-stable-version marker
# Creates a GitHub issue for the incident
# Notifies the team via configured channels
# Stores rollback event in database for analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/deployment-policy.yaml"
ENV_FILE="${SCRIPT_DIR}/../../.env"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Default values
DEPLOYMENT_ID="${DEPLOYMENT_ID:-unknown}"
COMMIT_SHA="${COMMIT_SHA:-unknown}"
PREVIOUS_COMMIT="${PREVIOUS_COMMIT:-}"
BUILD_ID="${BUILD_ID:-unknown}"
ROLLBACK_REASON="${ROLLBACK_REASON:-Health check failure}"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Check arguments
SHOW_HELP=false
FORCE=false
SKIP_ISSUE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    --skip-issue)
      SKIP_ISSUE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --deployment-id)
      DEPLOYMENT_ID="$2"
      shift 2
      ;;
    --commit)
      COMMIT_SHA="$2"
      shift 2
      ;;
    --previous-commit)
      PREVIOUS_COMMIT="$2"
      shift 2
      ;;
    --reason)
      ROLLBACK_REASON="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  cat << EOF
Usage: $0 [OPTIONS]

Rolls back the current deployment to the previous stable version.

Options:
  -h, --help              Show this help message
  -f, --force             Force rollback without confirmation
  --skip-issue            Skip creating GitHub issue
  --dry-run               Simulate rollback without making changes
  --deployment-id ID      Current deployment identifier
  --commit SHA            Current commit SHA
  --previous-commit SHA   Commit SHA to rollback to (required if not auto-detected)
  --reason TEXT           Reason for rollback (default: "Health check failure")

Environment Variables:
  DEPLOYMENT_ID           Current deployment identifier
  COMMIT_SHA              Current commit SHA
  PREVIOUS_COMMIT         Target commit SHA for rollback
  BUILD_ID                CI/CD build ID
  ROLLBACK_REASON        Reason for rollback
  GITHUB_REPO             GitHub repository (e.g., owner/repo)
  GITHUB_TOKEN            GitHub personal access token
  DATABASE_URL            PostgreSQL connection string

Exit Codes:
  0 - Rollback successful
  1 - Rollback failed
  2 - Configuration error
  3 - Rollback aborted by user

Example:
  $0 --deployment-id deploy-123 --commit abc123 --previous-commit def456 --reason "High error rate"

The script will:
  1. Verify rollback prerequisites
  2. Identify previous stable version
  3. Perform deployment rollback
  4. Update version markers
  5. Create incident GitHub issue
  6. Store rollback event in database
  7. Notify team members
EOF
  exit 0
fi

# Function to log messages
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to confirm action
confirm_rollback() {
  if [ "$FORCE" = true ] || [ "$DRY_RUN" = true ]; then
    return 0
  fi

  echo ""
  log_warning "This will rollback deployment $DEPLOYMENT_ID to commit ${PREVIOUS_COMMIT:0:8}"
  echo "Reason: $ROLLBACK_REASON"
  echo ""
  read -p "Are you sure you want to proceed? (yes/no): " confirmation

  if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ]; then
    log_info "Rollback aborted by user"
    exit 3
  fi
}

# Function to get previous stable commit
get_previous_commit() {
  log_info "Determining previous stable commit..."

  # If previous commit is provided, use it
  if [ -n "$PREVIOUS_COMMIT" ]; then
    log_info "Using provided previous commit: ${PREVIOUS_COMMIT:0:8}"
    echo "$PREVIOUS_COMMIT"
    return 0
  fi

  # Try to get from git history
  if command -v git >/dev/null 2>&1; then
    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
      # Get the commit before the current one
      local prev_commit=$(git log --format=%H -n 2 | tail -1)

      if [ -n "$prev_commit" ]; then
        log_info "Auto-detected previous commit: ${prev_commit:0:8}"
        echo "$prev_commit"
        return 0
      fi
    fi
  fi

  # Try to get from database
  if [ -n "$DATABASE_URL" ] && command -v psql >/dev/null 2>&1; then
    local db_commit=$(psql "$DATABASE_URL" -t -A -c "
      SELECT commit_sha
      FROM deployments
      WHERE status = 'success'
        AND commit_sha != '$COMMIT_SHA'
      ORDER BY timestamp DESC
      LIMIT 1;
    " 2>/dev/null || echo "")

    if [ -n "$db_commit" ]; then
      log_info "Found previous commit from database: ${db_commit:0:8}"
      echo "$db_commit"
      return 0
    fi
  fi

  log_error "Could not determine previous commit automatically"
  log_error "Please specify --previous-commit"
  return 1
}

# Function to verify rollback prerequisites
verify_prerequisites() {
  log_info "Verifying rollback prerequisites..."

  local all_good=true

  # Check if previous commit is provided or can be detected
  PREVIOUS_COMMIT=$(get_previous_commit)
  if [ -z "$PREVIOUS_COMMIT" ]; then
    log_error "Previous commit not available"
    all_good=false
  fi

  # Check if git is available for rollback (if using git-based deployment)
  if [ -n "$DEPLOYMENT_SCRIPT" ] && [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    log_warning "Deployment script not found: $DEPLOYMENT_SCRIPT"
    log_warning "Will proceed with git-based rollback if available"
  fi

  # Check database connection (optional)
  if [ -n "$DATABASE_URL" ]; then
    if command -v psql >/dev/null 2>&1; then
      if psql "$DATABASE_URL" -c "SELECT 1" >/dev/null 2>&1; then
        log_verbose "Database connection verified"
      else
        log_warning "Database connection failed, will not store rollback event"
      fi
    fi
  fi

  if [ "$all_good" = false ]; then
    return 1
  fi

  log_success "Prerequisites verified"
  return 0
}

# Function to perform actual rollback
perform_rollback() {
  log_info "Performing rollback to ${PREVIOUS_COMMIT:0:8}..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would rollback to ${PREVIOUS_COMMIT:0:8}"
    return 0
  fi

  # Check if there's a custom deployment script
  if [ -n "$DEPLOYMENT_SCRIPT" ] && [ -f "$DEPLOYMENT_SCRIPT" ]; then
    log_info "Using deployment script: $DEPLOYMENT_SCRIPT"

    if bash "$DEPLOYMENT_SCRIPT" rollback "$PREVIOUS_COMMIT"; then
      log_success "Deployment script rollback successful"
      return 0
    else
      log_error "Deployment script rollback failed"
      return 1
    fi
  fi

  # Default: git-based rollback
  if command -v git >/dev/null 2>&1; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
      log_info "Performing git-based rollback..."

      # Fetch if needed
      if git remote get-url origin >/dev/null 2>&1; then
        git fetch origin >/dev/null 2>&1 || true
      fi

      # Reset to previous commit
      if git reset --hard "$PREVIOUS_COMMIT" 2>&1; then
        log_success "Git reset successful"

        # Push if this is the main branch and we have access
        CURRENT_BRANCH=$(git branch --show-current)
        if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
          if [ -n "$GITHUB_TOKEN" ]; then
            log_info "Force pushing to $CURRENT_BRANCH..."
            if git push --force origin "$CURRENT_BRANCH" 2>&1; then
              log_success "Force push successful"
            else
              log_warning "Force push failed, manual intervention required"
              return 1
            fi
          else
            log_warning "GITHUB_TOKEN not set, skipping force push"
            log_warning "Manual intervention required to push rollback"
          fi
        fi

        return 0
      else
        log_error "Git reset failed"
        return 1
      fi
    fi
  fi

  log_error "No rollback mechanism available"
  log_error "Please configure DEPLOYMENT_SCRIPT or ensure git is available"
  return 1
}

# Function to update last-stable-version marker
update_version_marker() {
  log_info "Updating last-stable-version marker..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would update version marker to ${PREVIOUS_COMMIT:0:8}"
    return 0
  fi

  # Create/update marker file
  local marker_file="${SCRIPT_DIR}/../../.last-stable-version"
  echo "$PREVIOUS_COMMIT" > "$marker_file"
  log_success "Version marker updated to ${PREVIOUS_COMMIT:0:8}"

  # Update in database if available
  if [ -n "$DATABASE_URL" ] && command -v psql >/dev/null 2>&1; then
    local update_sql="
    INSERT INTO version_markers (marker_name, commit_sha, updated_at)
    VALUES ('last_stable', '$PREVIOUS_COMMIT', NOW())
    ON CONFLICT (marker_name) DO UPDATE
      SET commit_sha = EXCLUDED.commit_sha,
          updated_at = EXCLUDED.updated_at;
    "

    echo "$update_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "INSERT 0 1" || true
    log_verbose "Version marker updated in database"
  fi
}

# Function to create GitHub issue
create_incident_issue() {
  if [ "$SKIP_ISSUE" = true ]; then
    log_info "Skipping GitHub issue creation (--skip-issue)"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would create incident issue"
    return 0
  fi

  # Check if GitHub CLI is available and configured
  if ! command -v gh >/dev/null 2>&1; then
    log_warning "GitHub CLI not available, skipping issue creation"
    return 0
  fi

  if [ -z "$GITHUB_TOKEN" ]; then
    log_warning "GITHUB_TOKEN not set, skipping issue creation"
    return 0
  fi

  if [ -z "$GITHUB_REPO" ]; then
    # Try to detect repo from git remote
    if command -v git >/dev/null 2>&1; then
      GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed -e 's|https://github.com/||' -e 's|git@github.com:||' -e 's|\.git$||' || echo "")
    fi
  fi

  if [ -z "$GITHUB_REPO" ]; then
    log_warning "Could not determine GitHub repository, skipping issue creation"
    return 0
  fi

  log_info "Creating incident issue in $GITHUB_REPO..."

  local issue_title="Deployment Rollback: $DEPLOYMENT_ID"
  local issue_body=$(cat << EOF
## Deployment Rollback Incident

**Deployment ID:** \`$DEPLOYMENT_ID\`
**Rollback Commit:** \`${PREVIOUS_COMMIT:0:8}\`
**Failed Commit:** \`${COMMIT_SHA:0:8}\`
**Rollback Time:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

### Reason
$ROLLBACK_REASON

### Details
- The deployment was automatically rolled back due to health check failures
- Previous stable version has been restored
- Service should be recovering now

### Action Items
- [ ] Investigate root cause of the deployment failure
- [ ] Review health check metrics and logs
- [ ] Fix the issue in the failed commit
- [ ] Test thoroughly before redeploying
- [ ] Update deployment procedures if needed

### Metadata
- **Build ID:** \`$BUILD_ID\`
- **Triggered By:** Automated rollback system
- **Severity:** High

---
*This issue was automatically created during rollback*
EOF
)

  if gh issue create --repo "$GITHUB_REPO" --title "$issue_title" --body "$issue_body" --label "incident,rollback,automated" 2>&1; then
    log_success "Incident issue created"
  else
    log_warning "Failed to create GitHub issue"
  fi
}

# Function to notify team
notify_team() {
  log_info "Notifying team about rollback..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would send team notification"
    return 0
  fi

  # Store notification in database
  if [ -n "$DATABASE_URL" ] && command -v psql >/dev/null 2>&1; then
    local notification_sql="
    INSERT INTO notification_history (
      notification_type, channel, title, message, metadata, sent
    ) VALUES (
      'rollback', 'incident', 'Deployment Rollback: $DEPLOYMENT_ID',
      'Deployment $DEPLOYMENT_ID has been rolled back to ${PREVIOUS_COMMIT:0:8}. Reason: $ROLLBACK_REASON',
      '{\"deployment_id\": \"$DEPLOYMENT_ID\", \"rollback_commit\": \"$PREVIOUS_COMMIT\", \"reason\": \"$ROLLBACK_REASON\"}'::jsonb,
      false
    );
    "

    echo "$notification_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "INSERT 0 1" || true
    log_verbose "Notification stored in database"
  fi

  # Additional notification methods can be added here:
  # - Slack webhook
  # - Email notification
  # - PagerDuty alert
  # etc.
}

# Function to store rollback event in database
store_rollback_event() {
  log_info "Storing rollback event in database..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would store rollback event"
    return 0
  fi

  if [ -z "$DATABASE_URL" ]; then
    log_warning "DATABASE_URL not set, skipping database storage"
    return 0
  fi

  if ! command -v psql >/dev/null 2>&1; then
    log_warning "psql not available, skipping database storage"
    return 0
  fi

  # Create deployments table if not exists
  local create_table_sql="
  CREATE TABLE IF NOT EXISTS deployments (
    id SERIAL PRIMARY KEY,
    deployment_id VARCHAR(100) UNIQUE NOT NULL,
    commit_sha VARCHAR(40) NOT NULL,
    previous_commit VARCHAR(40),
    build_id INTEGER,

    status VARCHAR(20) NOT NULL,
    deployment_type VARCHAR(20) DEFAULT 'standard',

    rollback_from_commit VARCHAR(40),
    rollback_reason TEXT,

    timestamp TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_deployments_id ON deployments(deployment_id);
  CREATE INDEX IF NOT EXISTS idx_deployments_commit ON deployments(commit_sha);
  CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);
  CREATE INDEX IF NOT EXISTS idx_deployments_timestamp ON deployments(timestamp DESC);

  -- Create version_markers table
  CREATE TABLE IF NOT EXISTS version_markers (
    marker_name VARCHAR(50) PRIMARY KEY,
    commit_sha VARCHAR(40) NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW()
  );
  "

  # Insert rollback event
  local insert_sql="
  INSERT INTO deployments (
    deployment_id, commit_sha, previous_commit, build_id,
    status, deployment_type, rollback_from_commit, rollback_reason
  ) VALUES (
    '${DEPLOYMENT_ID}-rollback', '$PREVIOUS_COMMIT', '$COMMIT_SHA', '$BUILD_ID',
    'rolled_back', 'rollback', '$COMMIT_SHA', '$ROLLBACK_REASON'
  )
  ON CONFLICT (deployment_id) DO UPDATE
    SET status = 'rolled_back',
        commit_sha = EXCLUDED.commit_sha,
        rollback_from_commit = EXCLUDED.rollback_from_commit,
        rollback_reason = EXCLUDED.rollback_reason;
  "

  # Execute SQL
  echo "$create_table_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "CREATE TABLE\|CREATE INDEX" || true
  echo "$insert_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "INSERT 0 1" || true

  log_success "Rollback event stored in database"
}

# Main execution
log_info "=== Deployment Rollback ==="
log_info "Deployment ID: $DEPLOYMENT_ID"
log_info "Current Commit: ${COMMIT_SHA:0:8}"
log_info "Rollback Reason: $ROLLBACK_REASON"
echo ""

# Verify prerequisites
if ! verify_prerequisites; then
  log_error "Prerequisites verification failed"
  exit 2
fi

# Confirm rollback
confirm_rollback

# Perform rollback
if ! perform_rollback; then
  log_error "Rollback failed"
  exit 1
fi

# Update version marker
update_version_marker

# Store rollback event
store_rollback_event

# Create incident issue
create_incident_issue

# Notify team
notify_team

echo ""
log_success "=== Rollback Complete ==="
log_info "Deployment rolled back to: ${PREVIOUS_COMMIT:0:8}"
log_info "Last-stable marker updated"
log_info "Incident issue created (if configured)"
log_info "Team notified"

exit 0
