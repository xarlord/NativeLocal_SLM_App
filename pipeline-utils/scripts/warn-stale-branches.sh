#!/bin/bash
################################################################################
# Warn Stale Branches Script
# Part of Feature 4: Branch Management Automation
#
# Comments on PRs with stale branches, uses gh CLI to find PRs for stale
# branches, posts warning comments with configurable template, supports
# @mentions, and logs warnings to database.
#
# Usage:
#   ./warn-stale-branches.sh [options]
#
# Examples:
#   ./warn-stale-branches.sh --stale-days 30
#   ./warn-stale-branches.sh --dry-run --verbose
#   ./warn-stale-branches.sh --mention-team --stale-days 21
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
STALE_DAYS=30
ABANDONED_DAYS=60
DRY_RUN=false
LOG_TO_DB=true
MENTION_TEAM=false
MENTION_ASSIGNEES=true
VERBOSE=0

# Comment template
COMMENT_TEMPLATE="⚠️ **This branch has been inactive for {{DAYS}} days**

This branch hasn't been updated in {{DAYS}} days. Please consider:
- Updating the branch with the latest changes from main
- Closing this PR if it's no longer needed
- Responding to any pending review comments

If this branch remains inactive for {{ABANDONED_DAYS}} days, it may be automatically deleted.

{{MENTIONS}}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
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

Comment on PRs with stale branches to warn about inactivity.

Options:
  -s, --stale-days N       Consider branches stale after N days (default: 30)
  -a, --abandoned-days N   Show abandoned threshold in warning (default: 60)
  --mention-team           @mention the team in comments
  --no-mention-assignees   Don't @mention PR assignees
  --dry-run                Preview comments without posting
  --no-db                  Skip database logging
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message

Features:
  - Automatically finds PRs for stale branches
  - Posts warning comments with customizable template
  - Supports @mentions of assignees and teams
  - Logs all warnings to database
  - Dry-run mode for testing

Comment Template Variables:
  {{DAYS}}           Days since last commit
  {{ABANDONED_DAYS}} Abandoned threshold
  {{MENTIONS}}       @mentions of assignees/team
  {{BRANCH}}         Branch name
  {{PR_NUMBER}}      PR number

Examples:
  # Warn on branches stale for 30+ days
  $0

  # Warn with custom threshold and team mentions
  $0 --stale-days 21 --mention-team

  # Preview what would be posted
  $0 --dry-run --verbose

  # Don't mention assignees
  $0 --no-mention-assignees

Exit Codes:
  0      Success
  1      Error occurred
  2      No stale PRs found
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
            -s|--stale-days)
                STALE_DAYS="$2"
                shift 2
                ;;
            -a|--abandoned-days)
                ABANDONED_DAYS="$2"
                shift 2
                ;;
            --mention-team)
                MENTION_TEAM=true
                shift
                ;;
            --no-mention-assignees)
                MENTION_ASSIGNEES=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-db)
                LOG_TO_DB=false
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

    # Validate thresholds
    if ! [[ "$STALE_DAYS" =~ ^[0-9]+$ ]] || ! [[ "$ABANDONED_DAYS" =~ ^[0-9]+$ ]]; then
        error "Invalid threshold values"
    fi
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract thresholds from config
        local config_stale
        local config_abandoned

        config_stale=$(grep "stale_threshold_days:" "$CONFIG_FILE" | awk '{print $2}' || echo "")
        config_abandoned=$(grep "abandoned_threshold_days:" "$CONFIG_FILE" | awk '{print $2}' || echo "")

        [[ -n "$config_stale" ]] && STALE_DAYS="$config_stale"
        [[ -n "$config_abandoned" ]] && ABANDONED_DAYS="$config_abandoned"

        # Extract protected branches
        PROTECTED_BRANCHES=$(grep -A 10 "^protected_branches:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")
    else
        log "Config file not found: $CONFIG_FILE"
        PROTECTED_BRANCHES="main master develop"
    fi

    log "Using thresholds: stale=$STALE_DAYS days, abandoned=$ABANDONED_DAYS days"
}

# Database query function (with SQL injection protection)
query_db() {
    local query="$1"
    # Query should be escaped by caller
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Log warning to database
log_warning_to_db() {
    local branch="$1"
    local pr_number="$2"
    local age_days="$3"
    local posted="$4"

    if [[ "$LOG_TO_DB" != "true" ]]; then
        return 0
    fi

    # Validate and escape inputs using security functions
    if declare -f validate_branch_name > /dev/null; then
        branch=$(validate_branch_name "$branch") || return 1
    else
        # Basic escaping
        branch="${branch//\'/''}"
    fi

    local posted_bool="false"
    [[ "$posted" == "true" ]] && posted_bool="true"

    local query="
INSERT INTO branch_history (
  branch_name, status, category, age_days, pr_number, detected_at
) VALUES (
  '$branch', 'warned', 'stale', $age_days, $pr_number, NOW()
)
ON CONFLICT (branch_name, detected_at) DO UPDATE SET
  status = EXCLUDED.status,
  pr_number = EXCLUDED.pr_number,
  age_days = EXCLUDED.age_days;
"

    query_db "$query" >/dev/null

    [[ $VERBOSE -eq 1 ]] && log "  Logged warning to DB: $branch (PR #$pr_number)"
}

# Check if gh CLI is available
check_gh_cli() {
    if ! command -v gh &>/dev/null; then
        error "gh CLI not found. Please install GitHub CLI: https://cli.github.com/"
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        error "gh CLI not authenticated. Run: gh auth login"
    fi
}

# Check if branch is protected
is_protected() {
    local branch="$1"

    # Use centralized security function if available
    if declare -f is_protected_branch > /dev/null; then
        is_protected_branch "$branch" "$PROTECTED_BRANCHES"
        return $?
    fi

    # Fallback to local implementation
    local protected
    for protected in $PROTECTED_BRANCHES; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done

    return 1
}

# Get last commit date for a branch
get_last_commit_date() {
    local branch="$1"
    git log -1 --format='%ct' "$branch" 2>/dev/null
}

# Calculate age in days
calculate_age() {
    local commit_timestamp="$1"
    local current_timestamp
    current_timestamp=$(date +%s)

    echo $(( (current_timestamp - commit_timestamp) / 86400 ))
}

# Find PRs for a branch
find_prs_for_branch() {
    local branch="$1"

    gh pr list --head "$branch" --state open --json number,title,author,assignees --jq '.[]' 2>/dev/null || echo ""
}

# Get PR assignees for mentions
get_assignee_mentions() {
    local pr_data="$1"

    if [[ "$MENTION_ASSIGNEES" != "true" ]]; then
        echo ""
        return
    fi

    local assignees
    assignees=$(echo "$pr_data" | jq -r '.assignees[]?.login' 2>/dev/null | tr '\n' ' ' || echo "")

    if [[ -n "$assignees" ]]; then
        local mentions=""
        for assignee in $assignees; do
            mentions+="@$assignee "
        done
        echo "$mentions"
    else
        echo ""
    fi
}

# Build comment from template
build_comment() {
    local days="$1"
    local branch="$2"
    local pr_number="$3"
    local mentions="$4"

    local comment="$COMMENT_TEMPLATE"

    # Replace template variables
    comment="${comment//\{\{DAYS\}\}/$days}"
    comment="${comment//\{\{ABANDONED_DAYS\}\}/$ABANDONED_DAYS}"
    comment="${comment//\{\{BRANCH\}\}/$branch}"
    comment="${comment//\{\{PR_NUMBER\}\}/$pr_number}"
    comment="${comment//\{\{MENTIONS\}\}/$mentions}"

    echo "$comment"
}

# Post comment to PR (with duplicate checking)
post_pr_comment() {
    local pr_number="$1"
    local comment="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "  [DRY RUN] Would post comment on PR #$pr_number"
        return 0
    fi

    # Check for existing comment to avoid duplicates
    if declare -f has_existing_comment > /dev/null; then
        # Use a unique pattern to identify our comments
        local search_pattern="This branch hasn't been updated in"
        if has_existing_comment "$pr_number" "$search_pattern"; then
            log "  Already commented on PR #$pr_number recently (skipping duplicate)"
            return 0
        fi
    fi

    if gh pr comment "$pr_number" --body "$comment" 2>/dev/null; then
        log "  Posted comment on PR #$pr_number"
        return 0
    else
        log "  Failed to post comment on PR #$pr_number"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"
    load_config

    # Check for gh CLI
    check_gh_cli

    # Change to project root
    cd "$PROJECT_ROOT" || error "Failed to change to project root: $PROJECT_ROOT"

    # Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not a git repository: $PROJECT_ROOT"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN MODE - No comments will be posted"
    fi

    log "Scanning for stale branches with open PRs..."

    # Get all branches
    local branches
    branches=$(git branch | sed 's/^[* ] //')

    if [[ -z "$branches" ]]; then
        log "No branches found"
        exit 2
    fi

    # Find stale branches with PRs
    local stale_prs_count=0
    local commented_count=0
    local failed_count=0
    local protected_count=0

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue

        # Skip protected branches
        if is_protected "$branch"; then
            ((protected_count++))
            continue
        fi

        # Get branch age
        local last_commit_date
        local age_days

        last_commit_date=$(get_last_commit_date "$branch")
        age_days=$(calculate_age "$last_commit_date")

        # Check if stale
        if [[ $age_days -lt $STALE_DAYS ]]; then
            continue
        fi

        # Find PRs for this branch
        local prs_data
        prs_data=$(find_prs_for_branch "$branch")

        if [[ -z "$prs_data" ]]; then
            [[ $VERBOSE -eq 1 ]] && log "  No PR found for stale branch: $branch"
            continue
        fi

        ((stale_prs_count++))

        # Process each PR (usually there's only one)
        echo "$prs_data" | while IFS= read -r pr_data; do
            [[ -z "$pr_data" ]] && continue

            local pr_number
            local pr_title
            local pr_author

            pr_number=$(echo "$pr_data" | jq -r '.number // empty')
            pr_title=$(echo "$pr_data" | jq -r '.title // empty')
            pr_author=$(echo "$pr_data" | jq -r '.author.login // empty')

            if [[ -z "$pr_number" ]]; then
                continue
            fi

            log "Found stale PR: #$pr_number - $pr_title (branch: $branch, ${age_days} days old)"

            # Get assignee mentions
            local mentions
            mentions=$(get_assignee_mentions "$pr_data")

            # Build comment
            local comment
            comment=$(build_comment "$age_days" "$branch" "$pr_number" "$mentions")

            # Show preview
            if [[ $VERBOSE -eq 1 ]] || [[ "$DRY_RUN" == "true" ]]; then
                echo ""
                echo "Comment preview for PR #$pr_number:"
                echo "-----------------------------------"
                echo "$comment"
                echo "-----------------------------------"
                echo ""
            fi

            # Post comment
            if post_pr_comment "$pr_number" "$comment"; then
                ((commented_count++))

                # Log to database
                log_warning_to_db "$branch" "$pr_number" "$age_days" "true"
            else
                ((failed_count++))
                log_warning_to_db "$branch" "$pr_number" "$age_days" "false"
            fi
        done

    done <<< "$branches"

    # Summary
    log "Warning complete!"
    log "Stale PRs found: $stale_prs_count"
    log "Comments posted: $commented_count"
    [[ $failed_count -gt 0 ]] && log "Failed: $failed_count"
    log "Protected branches skipped: $protected_count"

    if [[ $stale_prs_count -eq 0 ]]; then
        log "No stale PRs found"
        exit 2
    fi

    exit 0
}

# Run main function
main "$@"
