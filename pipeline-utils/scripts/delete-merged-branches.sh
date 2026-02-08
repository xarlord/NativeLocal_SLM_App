#!/bin/bash
################################################################################
# Delete Merged Branches Script
# Part of Feature 4: Branch Management Automation
#
# Finds all branches merged to main/develop, excludes protected branches,
# confirms before deletion (or --force flag), logs deletions to database,
# and sends notification with deleted branches list.
#
# Usage:
#   ./delete-merged-branches.sh [options]
#
# Examples:
#   ./delete-merged-branches.sh --dry-run
#   ./delete-merged-branches.sh --force --target main
#   ./delete-merged-branches.sh --confirm --days 7
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
TARGET_BRANCHES="main develop"
MERGED_RETENTION_DAYS=7
DRY_RUN=true
FORCE=false
LOG_TO_DB=true
SEND_NOTIFICATION=true
VERBOSE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
Usage: $0 [options]

Find and delete branches that have been merged to main/develop.

Options:
  -t, --target BRANCH     Target branch to check merges against (default: main,develop)
  -d, --days N            Minimum days since merge before deletion (default: 7)
  -f, --force             Skip confirmation prompt
  -n, --dry-run           Preview what would be deleted without actually deleting (default)
  --no-db                 Skip database logging
  --no-notify             Skip sending notifications
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message

Safety Features:
  - Protected branches (main, develop, release/*) are never deleted
  - Confirmation prompt required unless --force is used
  - All deletions are logged to the database
  - Notification sent with list of deleted branches

Examples:
  # Preview which branches would be deleted
  $0 --dry-run

  # Delete merged branches older than 14 days with confirmation
  $0 --days 14

  # Force delete without confirmation (USE WITH CAUTION)
  $0 --force

  # Only check branches merged to develop branch
  $0 --target develop

Exit Codes:
  0      Success (branches deleted or no branches to delete)
  1      Error occurred
  2      No branches found
  3      Invalid arguments
  4      Deletion cancelled by user

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
            -t|--target)
                TARGET_BRANCHES="$2"
                shift 2
                ;;
            -d|--days)
                MERGED_RETENTION_DAYS="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                DRY_RUN=false
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                FORCE=false
                shift
                ;;
            --no-db)
                LOG_TO_DB=false
                shift
                ;;
            --no-notify)
                SEND_NOTIFICATION=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unexpected argument: $1"
                ;;
        esac
    done

    # Validate retention days
    if ! [[ "$MERGED_RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
        error "Invalid retention days: $MERGED_RETENTION_DAYS"
    fi
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract retention days from config
        local config_retention
        config_retention=$(grep "merged_retention_days:" "$CONFIG_FILE" | awk '{print $2}' || echo "")
        [[ -n "$config_retention" ]] && MERGED_RETENTION_DAYS="$config_retention"

        # Extract protected branches
        PROTECTED_BRANCHES=$(grep -A 10 "^protected_branches:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")

        # Extract protected patterns
        PROTECTED_PATTERNS=$(grep -A 10 "^protected_patterns:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")
    else
        log "Config file not found: $CONFIG_FILE"
        PROTECTED_BRANCHES="main master develop"
        PROTECTED_PATTERNS="^release/.* ^hotfix/.*"
    fi

    log "Using retention period: $MERGED_RETENTION_DAYS days"
}

# Database query function (with SQL injection protection)
query_db() {
    local query="$1"
    # Query should be escaped by caller
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Log deletion to database
log_deletion_to_db() {
    local branch="$1"
    local target_branch="$2"
    local merge_date="$3"
    local last_commit="$4"
    local deleted="$5"
    local backup_dir="${6:-}"

    if [[ "$LOG_TO_DB" != "true" ]]; then
        return 0
    fi

    # Validate and escape inputs using security functions
    if declare -f validate_branch_name > /dev/null; then
        branch=$(validate_branch_name "$branch") || return 1
        target_branch=$(psql_escape "$target_branch")
        last_commit=$(psql_escape "$last_commit")
        backup_dir=$(psql_escape "$backup_dir")
    else
        # Basic escaping
        branch="${branch//\'/''}"
        target_branch="${target_branch//\'/''}"
        last_commit="${last_commit//\'/''}"
        backup_dir="${backup_dir//\'/''}"
    fi

    local deleted_bool="false"
    [[ "$deleted" == "true" ]] && deleted_bool="true"

    local query="
INSERT INTO branch_history (
  branch_name, status, last_commit_sha, last_commit_date,
  category, detected_at, metadata
) VALUES (
  '$branch', 'deleted', '$last_commit', '$merge_date',
  'merged', NOW(), '{\"backup_location\": \"$backup_dir\"}'::jsonb
);
"

    query_db "$query" >/dev/null

    [[ $VERBOSE -eq 1 ]] && log "  Logged deletion to DB: $branch"
}

# Check if branch is protected
is_protected() {
    local branch="$1"

    # Use centralized security function if available
    if declare -f is_protected_branch > /dev/null; then
        is_protected_branch "$branch" "$PROTECTED_BRANCHES" "$PROTECTED_PATTERNS"
        return $?
    fi

    # Fallback to local implementation
    local protected

    # Check exact matches
    for protected in $PROTECTED_BRANCHES; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done

    # Check pattern matches
    for pattern in $PROTECTED_PATTERNS; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# Check if branch is merged to target
is_merged_to() {
    local branch="$1"
    local target="$2"

    git branch --merged "$target" 2>/dev/null | grep -q "$branch"
}

# Get merge date for a branch
get_merge_date() {
    local branch="$1"
    local target="$2"

    # Get the merge commit date
    local merge_date
    merge_date=$(git log --merges --first-parent "$target" --grep="Merge branch '$branch'" \
        --format='%ct' 2>/dev/null | head -1)

    # If not found by that method, try alternative
    if [[ -z "$merge_date" ]]; then
        merge_date=$(git log --first-parent "$target" --format='%ct' \
            --grep="pull request" --grep="$branch" 2>/dev/null | head -1)
    fi

    echo "$merge_date"
}

# Calculate days since merge
days_since_merge() {
    local merge_timestamp="$1"

    if [[ -z "$merge_timestamp" ]]; then
        echo "9999"
        return
    fi

    local current_timestamp
    current_timestamp=$(date +%s)
    local age_seconds=$((current_timestamp - merge_timestamp))

    echo $((age_seconds / 86400))
}

# Delete a branch (with mandatory backup)
delete_branch() {
    local branch="$1"

    # Check if branch can be deleted
    if declare -f can_delete_branch > /dev/null; then
        if ! can_delete_branch "$branch" "$PROTECTED_BRANCHES" "$PROTECTED_PATTERNS"; then
            log "  ERROR: Cannot delete protected branch: $branch"
            return 1
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "  [DRY RUN] Would delete: $branch (with backup)"
        DELETE_BACKUP_DIR="${PROJECT_ROOT}/.git/branch-backups/dry-run"
        return 0
    fi

    # MANDATORY: Create backup before deletion
    log "  Creating backup for: $branch"

    local backup_dir
    if declare -f create_branch_backup > /dev/null; then
        backup_dir=$(create_branch_backup "$branch" "$PROJECT_ROOT")
        if [[ -z "$backup_dir" ]]; then
            log "  ERROR: Failed to create backup directory for: $branch"
            return 1
        fi
    else
        # Fallback backup mechanism
        backup_dir="${PROJECT_ROOT}/.git/branch-backups/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir" || {
            log "  ERROR: Failed to create backup directory: $backup_dir"
            return 1
        }
    fi

    # Backup branch data
    if declare -f backup_branch_data > /dev/null; then
        if ! backup_branch_data "$branch" "$backup_dir" "$PROJECT_ROOT"; then
            log "  ERROR: Failed to backup branch: $branch"
            return 1
        fi
    else
        # Fallback: save commit SHA
        local commit_sha
        commit_sha=$(git rev-parse "$branch" 2>/dev/null) || {
            log "  ERROR: Failed to get commit SHA for: $branch"
            return 1
        }
        echo "$commit_sha" > "${backup_dir}/${branch}.commit"

        # Archive branch
        git archive "HEAD:$branch" > "${backup_dir}/${branch}.tar" 2>/dev/null || true
    fi

    log "  Branch backed up to: $backup_dir"

    # Log deletion
    if declare -f log_branch_deletion > /dev/null; then
        log_branch_deletion "$branch" "$backup_dir" "$PROJECT_ROOT"
    fi

    # Export backup dir for caller
    DELETE_BACKUP_DIR="$backup_dir"

    # Now delete the branch
    if git branch -d "$branch" 2>/dev/null; then
        log "  Deleted: $branch"
        return 0
    else
        log "  Failed to delete: $branch (backup preserved at: $backup_dir)"
        return 1
    fi
}

# Send notification about deleted branches
send_notification() {
    local deleted_branches="$1"
    local deleted_count="$2"

    if [[ "$SEND_NOTIFICATION" != "true" ]] || [[ $deleted_count -eq 0 ]]; then
        return 0
    fi

    log "Sending notification..."

    # Use send-notification script if available
    if [[ -f "${SCRIPT_DIR}/send-notification.sh" ]]; then
        local notification_data
        notification_data=$(cat << EOF
{
  "title": "Branch Cleanup: Deleted $deleted_count Merged Branches",
  "message": "The following merged branches have been deleted:\n\n$deleted_branches",
  "metadata": {
    "type": "branch_cleanup",
    "deleted_count": $deleted_count,
    "branches": [$deleted_branches]
  },
  "severity": "low"
}
EOF
)
        echo "$notification_data" | "${SCRIPT_DIR}/send-notification.sh" /dev/stdin 2>/dev/null || true
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"
    load_config

    # Change to project root
    cd "$PROJECT_ROOT" || error "Failed to change to project root: $PROJECT_ROOT"

    # Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not a git repository: $PROJECT_ROOT"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN MODE - No branches will be deleted"
    fi

    log "Scanning for merged branches..."

    # Get all branches
    local all_branches
    all_branches=$(git branch | sed 's/^[* ] //')

    if [[ -z "$all_branches" ]]; then
        log "No branches found"
        exit 2
    fi

    # Find merged branches
    local branches_to_delete=""
    local branch_count=0
    local protected_count=0
    local too_recent_count=0

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue

        # Skip protected branches
        if is_protected "$branch"; then
            ((protected_count++))
            [[ $VERBOSE -eq 1 ]] && log "  Skipping protected: $branch"
            continue
        fi

        # Check if merged to any target branch
        local is_merged=false
        local target_branch=""
        local merge_timestamp=""

        for target in $TARGET_BRANCHES; do
            if is_merged_to "$branch" "$target"; then
                is_merged=true
                target_branch="$target"
                merge_timestamp=$(get_merge_date "$branch" "$target")
                break
            fi
        done

        if [[ "$is_merged" != "true" ]]; then
            continue
        fi

        # Check if old enough to delete
        local days_since
        days_since=$(days_since_merge "$merge_timestamp")

        if [[ $days_since -lt $MERGED_RETENTION_DAYS ]]; then
            ((too_recent_count++))
            [[ $VERBOSE -eq 1 ]] && log "  Too recent ($days_since days): $branch"
            continue
        fi

        # Add to deletion list
        local last_commit
        last_commit=$(git rev-parse "$branch" 2>/dev/null | cut -c1-8)

        branches_to_delete+="${branch}|${target_branch}|${merge_timestamp}|${last_commit}\n"
        ((branch_count++))

        [[ $VERBOSE -eq 1 ]] && log "  Found candidate: $branch (merged $days_since days ago to $target_branch)"

    done <<< "$all_branches"

    # Summary
    log "Scan complete!"
    log "Branches to delete: $branch_count"
    log "Protected (skipped): $protected_count"
    log "Too recent (skipped): $too_recent_count"

    if [[ $branch_count -eq 0 ]]; then
        log "No branches to delete"
        exit 0
    fi

    # Show branches to delete
    echo ""
    echo "Branches to be deleted:"
    echo "------------------------"
    echo "$branches_to_delete" | while IFS='|' read -r branch target merge_ts commit; do
        [[ -z "$branch" ]] && continue
        local days_since
        days_since=$(days_since_merge "$merge_ts")
        echo "  - $branch (merged to $target, $days_since days ago)"
    done
    echo ""

    # Confirm deletion
    if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo -n "Delete these $branch_count branches? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "Deletion cancelled by user"
            exit 4
        fi
    fi

    # Delete branches
    local deleted_branches_list=""
    local deleted_count=0
    local failed_count=0

    echo ""
    log "Deleting branches..."

    while IFS='|' read -r branch target merge_ts commit; do
        [[ -z "$branch" ]] && continue

        # Format merge date for database
        local merge_date_formatted
        merge_date_formatted=$(date -d "@$merge_ts" -u +'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "NULL")

        if delete_branch "$branch"; then
            local backup_dir="${DELETE_BACKUP_DIR:-}"
            # Log to database with backup location
            log_deletion_to_db "$branch" "$target" "$merge_date_formatted" "$commit" "true" "$backup_dir"

            # Add to notification list
            deleted_branches_list+="$branch, "
            ((deleted_count++))
        else
            ((failed_count++))
        fi
    done <<< "$branches_to_delete"

    # Remove trailing comma
    deleted_branches_list=$(echo "$deleted_branches_list" | sed 's/, $//')

    # Summary
    echo ""
    log "Deletion complete!"
    log "Deleted: $deleted_count"
    [[ $failed_count -gt 0 ]] && log "Failed: $failed_count"

    # Send notification
    send_notification "$deleted_branches_list" "$deleted_count"

    exit 0
}

# Run main function
main "$@"
