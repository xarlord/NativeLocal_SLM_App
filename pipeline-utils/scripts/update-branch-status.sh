#!/bin/bash
################################################################################
# Update Branch Status Script
# Part of Feature 4: Branch Management Automation
#
# Updates branch status in database. Called by other scripts or webhook.
# Tracks: active, stale, merged, deleted. Updates commit count, last commit
# info, calculates branch age, and upserts to branch_history table.
#
# Usage:
#   ./update-branch-status.sh [branch-name] [status] [options]
#
# Examples:
#   ./update-branch-status.sh feature/auth active
#   ./update-branch-status.sh --all
#   ./update-branch-status.sh --webhook /tmp/webhook-data.json
################################################################################

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/pipeline-utils/config"
CONFIG_FILE="${CONFIG_DIR}/branch-strategy.yaml"

# Source security utilities
if [[ -f "${SCRIPT_DIR}/security-utils.sh" ]]; then
    source "${SCRIPT_DIR}/security-utils.sh"
else
    echo "WARNING: security-utils.sh not found, security features disabled" >&2
fi

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Default values
MODE="single"  # single, all, webhook
BRANCH_NAME=""
STATUS=""
COMMIT_SHA=""
COMMIT_COUNT=""
PR_NUMBER=""
VERBOSE=0

# Valid statuses
VALID_STATUSES=("active" "stale" "merged" "deleted" "warned" "protected")

# ============================================
# Helper Functions
# ============================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

usage() {
    cat << EOF
Usage: $0 [options] [branch-name] [status]

Update branch status in database for tracking and reporting.

Modes:
  single [branch] [status]  Update a specific branch (default)
  --all                      Update all branches
  --webhook [file]           Process webhook data

Options:
  -c, --commit SHA           Last commit SHA
  -n, --count N              Commit count
  -p, --pr-number N          Associated PR number
  -v, --verbose              Enable verbose output
  -h, --help                 Show this help message

Valid Statuses:
  active       Branch is actively being developed
  stale        Branch hasn't been updated in threshold days
  merged       Branch has been merged to target
  deleted      Branch has been deleted
  warned       Branch has been warned about inactivity
  protected    Branch is protected from deletion

Examples:
  # Update branch as active
  $0 feature/user-auth active

  # Update branch with commit info
  $0 feature/user-auth active --commit abc123 --count 5

  # Update all branches
  $0 --all

  # Process webhook data
  $0 --webhook /tmp/webhook.json

Exit Codes:
  0      Success
  1      Error occurred
  2      Invalid status
  3      Invalid arguments

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --all)
                MODE="all"
                shift
                ;;
            --webhook)
                MODE="webhook"
                WEBHOOK_FILE="$2"
                shift 2
                ;;
            -c|--commit)
                COMMIT_SHA="$2"
                shift 2
                ;;
            -n|--count)
                COMMIT_COUNT="$2"
                shift 2
                ;;
            -p|--pr-number)
                PR_NUMBER="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$BRANCH_NAME" ]]; then
                    BRANCH_NAME="$1"
                elif [[ -z "$STATUS" ]]; then
                    STATUS="$1"
                else
                    error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract thresholds from config
        STALE_THRESHOLD=$(grep "stale_threshold_days:" "$CONFIG_FILE" | awk '{print $2}' || echo "30")
        ABANDONED_THRESHOLD=$(grep "abandoned_threshold_days:" "$CONFIG_FILE" | awk '{print $2}' || echo "60")
    else
        STALE_THRESHOLD=30
        ABANDONED_THRESHOLD=60
    fi
}

# Database query function (with SQL injection protection)
query_db() {
    local query="$1"
    # Query should be escaped by caller
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Initialize database table
init_db() {
    local query="
CREATE TABLE IF NOT EXISTS branch_history (
  id SERIAL PRIMARY KEY,
  branch_name VARCHAR(255) NOT NULL,
  status VARCHAR(20) NOT NULL,
  last_commit_sha VARCHAR(40),
  last_commit_date TIMESTAMP,
  last_author VARCHAR(255),
  commit_count INTEGER DEFAULT 0,
  age_days INTEGER,
  has_open_pr BOOLEAN DEFAULT FALSE,
  pr_number INTEGER,
  category VARCHAR(50),
  metadata JSONB,
  detected_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_branch_history_name ON branch_history(branch_name);
CREATE INDEX IF NOT EXISTS idx_branch_history_status ON branch_history(status);
CREATE INDEX IF NOT EXISTS idx_branch_history_detected ON branch_history(detected_at DESC);
"

    query_db "$query" >/dev/null
}

# Validate status
validate_status() {
    local status="$1"

    for valid_status in "${VALID_STATUSES[@]}"; do
        if [[ "$status" == "$valid_status" ]]; then
            return 0
        fi
    done

    return 1
}

# Get branch metadata from git
get_branch_metadata() {
    local branch="$1"

    local commit_sha
    local commit_date
    local commit_author
    local commit_count

    commit_sha=$(git rev-parse "$branch" 2>/dev/null || echo "")
    commit_date=$(git log -1 --format='%ct' "$branch" 2>/dev/null || echo "")
    commit_author=$(git log -1 --format='%an' "$branch" 2>/dev/null || echo "")
    commit_count=$(git rev-list --count "$branch" 2>/dev/null || echo "0")

    echo "${commit_sha}|${commit_date}|${commit_author}|${commit_count}"
}

# Calculate branch age in days
calculate_age() {
    local commit_timestamp="$1"

    if [[ -z "$commit_timestamp" ]]; then
        echo "0"
        return
    fi

    local current_timestamp
    current_timestamp=$(date +%s)
    local age_seconds=$((current_timestamp - commit_timestamp))

    echo $((age_seconds / 86400))
}

# Determine if branch has open PR
has_open_pr() {
    local branch="$1"

    if command -v gh &>/dev/null; then
        local pr_count
        pr_count=$(gh pr list --head "$branch" --state open --json number --jq 'length' 2>/dev/null || echo "0")
        [[ $pr_count -gt 0 ]] && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Get PR number for branch
get_pr_number() {
    local branch="$1"

    if command -v gh &>/dev/null; then
        local pr_num
        pr_num=$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")
        echo "$pr_num"
    else
        echo ""
    fi
}

# Determine category based on age and status
determine_category() {
    local status="$1"
    local age_days="$2"

    case "$status" in
        deleted)
            echo "merged"
            ;;
        active)
            if [[ $age_days -ge $ABANDONED_THRESHOLD ]]; then
                echo "abandoned"
            elif [[ $age_days -ge $STALE_THRESHOLD ]]; then
                echo "stale"
            else
                echo "active"
            fi
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Upsert branch status to database
upsert_branch_status() {
    local branch="$1"
    local status="$2"
    local commit_sha="$3"
    local commit_date="$4"
    local commit_author="$5"
    local commit_count="$6"
    local age_days="$7"
    local has_pr="$8"
    local pr_number="$9"

    # Validate and escape inputs using security functions
    if declare -f validate_branch_name > /dev/null; then
        branch=$(validate_branch_name "$branch") || return 1
        status=$(psql_escape "$status")
        commit_sha=$(psql_escape "$commit_sha")
        commit_author=$(psql_escape "$commit_author")
    else
        # Basic escaping
        branch="${branch//\'/''}"
        status="${status//\'/''}"
        commit_sha="${commit_sha//\'/''}"
        commit_author="${commit_author//\'/''}"
    fi

    # Convert has_pr to boolean
    local has_pr_bool="false"
    [[ "$has_pr" == "true" ]] && has_pr_bool="true"

    # Format commit date for PostgreSQL
    local commit_date_formatted
    if [[ -n "$commit_date" && "$commit_date" != "null" ]]; then
        commit_date_formatted=$(date -d "@$commit_date" -u +'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "NULL")
    else
        commit_date_formatted="NULL"
    fi

    # Determine category
    local category
    category=$(determine_category "$status" "$age_days")

    if declare -f psql_escape > /dev/null; then
        category=$(psql_escape "$category")
    else
        category="${category//\'/''}"
    fi

    # Build metadata JSON
    local metadata
    metadata=$(cat << EOF
{
  "updated_by": "update-branch-status.sh",
  "stale_threshold": $STALE_THRESHOLD,
  "abandoned_threshold": $ABANDONED_THRESHOLD
}
EOF
)

    if declare -f psql_escape > /dev/null; then
        metadata=$(psql_escape "$metadata")
    else
        metadata="${metadata//\'/''}"
    fi

    # Upsert query
    local query="
INSERT INTO branch_history (
  branch_name, status, last_commit_sha, last_commit_date, last_author,
  commit_count, age_days, has_open_pr, pr_number, category, metadata, detected_at
) VALUES (
  '\$branch', '\$status', '\$commit_sha', \$commit_date_formatted::timestamp,
  '\$commit_author', \$commit_count::integer, \$age_days::integer,
  \$has_pr_bool::boolean, \$pr_number::integer, '\$category',
  '\$metadata'::jsonb, NOW()
)
ON CONFLICT (branch_name, detected_at) DO UPDATE SET
  status = EXCLUDED.status,
  last_commit_sha = EXCLUDED.last_commit_sha,
  last_commit_date = EXCLUDED.last_commit_date,
  last_author = EXCLUDED.last_author,
  commit_count = EXCLUDED.commit_count,
  age_days = EXCLUDED.age_days,
  has_open_pr = EXCLUDED.has_open_pr,
  pr_number = EXCLUDED.pr_number,
  category = EXCLUDED.category,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();
"

    # Replace variables in query (simple substitution)
    query="${query//\$branch/$branch}"
    query="${query//\$status/$status}"
    query="${query//\$commit_sha/$commit_sha}"
    query="${query//\$commit_date_formatted/$commit_date_formatted}"
    query="${query//\$commit_author/$commit_author}"
    query="${query//\$commit_count/$commit_count}"
    query="${query//\$age_days/$age_days}"
    query="${query//\$has_pr_bool/$has_pr_bool}"
    query="${query//\$pr_number/${pr_number:-NULL}}"
    query="${query//\$category/$category}"
    query="${query//\$metadata/$metadata}"

    query_db "$query" >/dev/null
}

# Update a single branch
update_single_branch() {
    local branch="$1"
    local status="$2"

    log "Updating branch: $branch -> $status"

    # Get branch metadata
    local metadata
    metadata=$(get_branch_metadata "$branch")
    IFS='|' read -r commit_sha commit_date commit_author commit_count <<< "$metadata"

    # Override with provided values if available
    [[ -n "$COMMIT_SHA" ]] && commit_sha="$COMMIT_SHA"
    [[ -n "$COMMIT_COUNT" ]] && commit_count="$COMMIT_COUNT"

    # Calculate age
    local age_days
    age_days=$(calculate_age "$commit_date")

    # Get PR info
    local has_pr
    local pr_number

    if [[ -n "$PR_NUMBER" ]]; then
        pr_number="$PR_NUMBER"
        has_pr="true"
    else
        has_pr=$(has_open_pr "$branch")
        pr_number=$(get_pr_number "$branch")
    fi

    # Upsert to database
    upsert_branch_status "$branch" "$status" "$commit_sha" "$commit_date" \
        "$commit_author" "$commit_count" "$age_days" "$has_pr" "$pr_number"

    [[ $VERBOSE -eq 1 ]] && log "  Updated: $branch (status=$status, age=$age_days days)"
}

# Update all branches
update_all_branches() {
    log "Updating all branches..."

    # Get all branches
    local branches
    branches=$(git branch | sed 's/^[* ] //')

    if [[ -z "$branches" ]]; then
        log "No branches found"
        return 1
    fi

    local updated_count=0
    local failed_count=0

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue

        # Get branch metadata
        local metadata
        metadata=$(get_branch_metadata "$branch")
        IFS='|' read -r commit_sha commit_date commit_author commit_count <<< "$metadata"

        # Calculate age
        local age_days
        age_days=$(calculate_age "$commit_date")

        # Determine status based on age
        local status
        if [[ $age_days -ge $ABANDONED_THRESHOLD ]]; then
            status="stale"
        elif [[ $age_days -ge $STALE_THRESHOLD ]]; then
            status="stale"
        else
            status="active"
        fi

        # Get PR info
        local has_pr
        local pr_number
        has_pr=$(has_open_pr "$branch")
        pr_number=$(get_pr_number "$branch")

        # Upsert to database
        if upsert_branch_status "$branch" "$status" "$commit_sha" "$commit_date" \
            "$commit_author" "$commit_count" "$age_days" "$has_pr" "$pr_number"; then
            ((updated_count++))
            [[ $VERBOSE -eq 1 ]] && log "  ✓ Updated: $branch ($status, ${age_days} days)"
        else
            ((failed_count++))
            log "  ✗ Failed: $branch"
        fi
    done <<< "$branches"

    log "Update complete! Updated: $updated_count, Failed: $failed_count"
}

# Process webhook data
process_webhook() {
    local webhook_file="$1"

    log "Processing webhook: $webhook_file"

    if [[ ! -f "$webhook_file" ]]; then
        error "Webhook file not found: $webhook_file"
    fi

    # Parse webhook JSON (requires jq)
    if ! command -v jq &>/dev/null; then
        error "jq not found. Please install jq to parse webhook data"
    fi

    # Extract branch and status from webhook
    local branch
    local status
    local commit_sha

    branch=$(jq -r '.ref // .branch // empty' "$webhook_file" | sed 's|^refs/heads/||')
    status=$(jq -r '.status // .state // "active"' "$webhook_file")
    commit_sha=$(jq -r '.sha // .commit.sha // .after // empty' "$webhook_file")

    if [[ -z "$branch" ]]; then
        error "Could not extract branch name from webhook"
    fi

    log "Extracted from webhook: branch=$branch, status=$status, commit=$commit_sha"

    # Update branch
    COMMIT_SHA="$commit_sha"
    update_single_branch "$branch" "$status"
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"
    load_config

    # Change to project root if in git mode
    if [[ "$MODE" != "webhook" ]]; then
        cd "$PROJECT_ROOT" || error "Failed to change to project root: $PROJECT_ROOT"

        # Validate git repository
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            error "Not a git repository: $PROJECT_ROOT"
        fi
    fi

    # Initialize database
    init_db

    case "$MODE" in
        single)
            if [[ -z "$BRANCH_NAME" ]]; then
                error "Branch name required"
            fi

            if [[ -z "$STATUS" ]]; then
                error "Status required"
            fi

            # Validate status
            if ! validate_status "$STATUS"; then
                error "Invalid status: $STATUS. Valid statuses: ${VALID_STATUSES[*]}"
            fi

            update_single_branch "$BRANCH_NAME" "$STATUS"
            ;;

        all)
            update_all_branches
            ;;

        webhook)
            if [[ -z "${WEBHOOK_FILE:-}" ]]; then
                error "Webhook file required"
            fi

            process_webhook "$WEBHOOK_FILE"
            ;;

        *)
            error "Invalid mode: $MODE"
            ;;
    esac

    exit 0
}

# Run main function
main "$@"
