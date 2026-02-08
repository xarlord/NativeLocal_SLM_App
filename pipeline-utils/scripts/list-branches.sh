#!/bin/bash
################################################################################
# List Branches Script
# Part of Feature 4: Branch Management Automation
#
# Lists all branches with metadata including last commit, author, age,
# and status. Detects merged branches and identifies stale branches.
#
# Usage:
#   ./list-branches.sh [options]
#
# Examples:
#   ./list-branches.sh
#   ./list-branches.sh --format json
#   ./list-branches.sh --merged-only
#   ./list-branches.sh --stale-only --days 30
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

# Default values
OUTPUT_FORMAT="table"  # table, json, csv
MERGED_ONLY=false
STALE_ONLY=false
STALE_DAYS=30
INCLUDE_REMOTE=false
VERBOSE=0

# Colors for table output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
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

List all branches with metadata including last commit, author, age, and status.

Options:
  -f, --format FORMAT    Output format: table, json, csv (default: table)
  -m, --merged-only      Show only merged branches
  -s, --stale-only       Show only stale branches
  -d, --days N           Consider branches stale after N days (default: 30)
  -r, --remote           Include remote branches
  -v, --verbose          Enable verbose output
  -h, --help             Show this help message

Output Columns (table format):
  - Branch Name: Name of the branch
  - Last Commit: Short SHA of last commit
  - Last Author: Author of last commit
  - Age: Age of last commit
  - Status: active, merged, stale, protected
  - Has PR: Whether branch has an open PR

Examples:
  # List all branches in table format
  $0

  # List only stale branches as JSON
  $0 --stale-only --format json

  # List only merged branches
  $0 --merged-only

  # List branches stale for more than 60 days
  $0 --stale-only --days 60

  # Include remote branches
  $0 --remote

Exit Codes:
  0      Success
  1      Error occurred
  2      No branches found
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
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -m|--merged-only)
                MERGED_ONLY=true
                shift
                ;;
            -s|--stale-only)
                STALE_ONLY=true
                shift
                ;;
            -d|--days)
                STALE_DAYS="$2"
                shift 2
                ;;
            -r|--remote)
                INCLUDE_REMOTE=true
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

    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(table|json|csv)$ ]]; then
        error "Invalid output format: $OUTPUT_FORMAT"
    fi

    # Validate stale days
    if ! [[ "$STALE_DAYS" =~ ^[0-9]+$ ]]; then
        error "Invalid days value: $STALE_DAYS"
    fi
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract protected branches from config using grep and sed
        PROTECTED_BRANCHES=$(grep -A 10 "^protected_branches:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")
    else
        log "Config file not found: $CONFIG_FILE"
        PROTECTED_BRANCHES="main master develop"
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

# Get last commit SHA for a branch
get_last_commit() {
    local branch="$1"
    git rev-parse "$branch" 2>/dev/null | cut -c1-8
}

# Get last commit author for a branch
get_last_author() {
    local branch="$1"
    git log -1 --format='%an' "$branch" 2>/dev/null
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
    local age_seconds=$((current_timestamp - commit_timestamp))
    local age_days=$((age_seconds / 86400))

    echo "$age_days"
}

# Format age in human-readable format
format_age() {
    local age_days="$1"

    if [[ $age_days -eq 0 ]]; then
        echo "today"
    elif [[ $age_days -eq 1 ]]; then
        echo "yesterday"
    elif [[ $age_days -lt 7 ]]; then
        echo "${age_days} days ago"
    elif [[ $age_days -lt 30 ]]; then
        local weeks=$((age_days / 7))
        echo "${weeks} week$( [[ $weeks -gt 1 ]] && echo "s" ) ago"
    elif [[ $age_days -lt 365 ]]; then
        local months=$((age_days / 30))
        echo "${months} month$( [[ $months -gt 1 ]] && echo "s" ) ago"
    else
        local years=$((age_days / 365))
        echo "${years} year$( [[ $years -gt 1 ]] && echo "s" ) ago"
    fi
}

# Check if branch is merged to main
is_merged_to() {
    local branch="$1"
    local target_branch="${2:-main}"

    # Check if branch is already merged
    git branch --merged "$target_branch" 2>/dev/null | grep -q "$branch"
}

# Determine branch status
get_branch_status() {
    local branch="$1"
    local age_days="$2"

    # Check if protected
    if is_protected "$branch"; then
        echo "protected"
        return
    fi

    # Check if merged to main or develop
    if is_merged_to "$branch" "main" || is_merged_to "$branch" "develop"; then
        echo "merged"
        return
    fi

    # Check if stale
    if [[ $age_days -ge $STALE_DAYS ]]; then
        echo "stale"
        return
    fi

    echo "active"
}

# Check if branch has an open PR
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

# Get commit count for a branch
get_commit_count() {
    local branch="$1"
    local base_branch="${2:-main}"

    git rev-list --count "$base_branch..$branch" 2>/dev/null || echo "0"
}

# ============================================
# Output Functions
# ============================================

output_table() {
    local branches_data="$1"

    echo ""
    echo "=========================================="
    echo "Branch Report"
    echo "=========================================="
    echo ""

    # Print header
    printf "${CYAN}%-30s${NC} %-10s %-20s %-15s %-12s %s\n" \
        "Branch Name" "Last Commit" "Last Author" "Age" "Status" "Has PR"
    printf "%s\n" "$(printf '%.0s-' {1..100})"

    # Print each branch
    while IFS='|' read -r branch commit author age_days status has_pr commits_ahead; do
        [[ -z "$branch" ]] && continue

        # Format age
        local age_formatted
        age_formatted=$(format_age "$age_days")

        # Color coding
        local branch_color="$NC"
        case "$status" in
            protected) branch_color="$GREEN" ;;
            merged) branch_color="$GRAY" ;;
            stale) branch_color="$RED" ;;
            active) branch_color="$CYAN" ;;
        esac

        # Print row
        printf "${branch_color}%-30s${NC} %-10s %-20s %-15s %-12s %s\n" \
            "$branch" \
            "$commit" \
            "$author" \
            "$age_formatted" \
            "$status" \
            "$has_pr"

        [[ $VERBOSE -eq 1 ]] && echo "  (commits ahead: $commits_ahead)"
    done <<< "$branches_data"

    echo ""
}

output_json() {
    local branches_data="$1"

    echo "{"
    echo "  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\","
    echo "  \"stale_threshold_days\": $STALE_DAYS,"
    echo "  \"branches\": ["

    local first=1
    while IFS='|' read -r branch commit author age_days status has_pr commits_ahead; do
        [[ -z "$branch" ]] && continue

        if [[ $first -eq 0 ]]; then
            echo ","
        fi
        first=0

        cat << BRANCH
    {
      "name": "$branch",
      "last_commit": "$commit",
      "last_author": "$author",
      "age_days": $age_days,
      "age_formatted": "$(format_age "$age_days")",
      "status": "$status",
      "has_open_pr": $has_pr,
      "commits_ahead": $commits_ahead
    }
BRANCH
    done <<< "$branches_data"

    echo ""
    echo "  ]"
    echo "}"
}

output_csv() {
    local branches_data="$1"

    # Header
    echo "Branch Name,Last Commit,Last Author,Age Days,Age Formatted,Status,Has PR,Commits Ahead"

    # Data rows
    while IFS='|' read -r branch commit author age_days status has_pr commits_ahead; do
        [[ -z "$branch" ]] && continue

        echo "$branch,$commit,$author,$age_days,\"$(format_age "$age_days")\",$status,$has_pr,$commits_ahead"
    done <<< "$branches_data"
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

    log "Scanning branches..."

    # Get list of branches
    local branches
    if [[ "$INCLUDE_REMOTE" == "true" ]]; then
        branches=$(git branch -r | sed 's/origin\///' | grep -v HEAD | sort -u)
    else
        branches=$(git branch | sed 's/^[* ] //')
    fi

    if [[ -z "$branches" ]]; then
        log "No branches found"
        exit 2
    fi

    # Collect branch data
    local branches_data=""
    local branch_count=0
    local stale_count=0
    local merged_count=0
    local protected_count=0

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue

        # Get branch metadata
        local last_commit
        local last_author
        local last_commit_date
        local age_days
        local status
        local has_pr
        local commits_ahead

        last_commit=$(get_last_commit "$branch")
        last_author=$(get_last_author "$branch")
        last_commit_date=$(get_last_commit_date "$branch")
        age_days=$(calculate_age "$last_commit_date")
        status=$(get_branch_status "$branch" "$age_days")
        has_pr=$(has_open_pr "$branch")
        commits_ahead=$(get_commit_count "$branch")

        # Apply filters
        if [[ "$MERGED_ONLY" == "true" && "$status" != "merged" ]]; then
            continue
        fi

        if [[ "$STALE_ONLY" == "true" && "$status" != "stale" ]]; then
            continue
        fi

        # Append to data
        branches_data+="${branch}|${last_commit}|${last_author}|${age_days}|${status}|${has_pr}|${commits_ahead}\n"

        # Update counters
        ((branch_count++))
        [[ "$status" == "stale" ]] && ((stale_count++))
        [[ "$status" == "merged" ]] && ((merged_count++))
        [[ "$status" == "protected" ]] && ((protected_count++))

        [[ $VERBOSE -eq 1 ]] && log "  Analyzed: $branch ($status)"

    done <<< "$branches"

    if [[ $branch_count -eq 0 ]]; then
        log "No branches match the specified filters"
        exit 2
    fi

    # Output results
    case "$OUTPUT_FORMAT" in
        table)
            output_table "$branches_data"
            ;;
        json)
            output_json "$branches_data"
            ;;
        csv)
            output_csv "$branches_data"
            ;;
    esac

    # Print summary
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        echo "Summary:"
        echo "  Total branches: $branch_count"
        echo "  Active: $((branch_count - stale_count - merged_count - protected_count))"
        echo "  Stale: $stale_count"
        echo "  Merged: $merged_count"
        echo "  Protected: $protected_count"
        echo ""
    fi

    log "Branch listing complete!"
}

# Run main function
main "$@"
