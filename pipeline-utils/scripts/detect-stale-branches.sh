#!/bin/bash
################################################################################
# Detect Stale Branches Script
# Part of Feature 4: Branch Management Automation
#
# Finds branches not updated in X days (configurable), checks for open PRs,
# categorizes branches (abandoned, stale, active), and logs to database.
#
# Usage:
#   ./detect-stale-branches.sh [options]
#
# Examples:
#   ./detect-stale-branches.sh
#   ./detect-stale-branches.sh --stale-days 30 --abandoned-days 60
#   ./detect-stale-branches.sh --format json --output /tmp/stale-branches.json
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
OUTPUT_FORMAT="text"  # text, json, csv
OUTPUT_FILE=""
LOG_TO_DB=true
VERBOSE=0

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

Find branches not updated in X days and categorize them by status.

Options:
  -s, --stale-days N       Consider branches stale after N days (default: 30)
  -a, --abandoned-days N   Consider branches abandoned after N days (default: 60)
  -f, --format FORMAT      Output format: text, json, csv (default: text)
  -o, --output FILE        Write output to file
  --no-db                  Skip database logging
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message

Categories:
  - Active: Branches with recent commits (< stale_days)
  - Stale: No commits > stale_days, but has an open PR
  - Abandoned: No commits > abandoned_days, no PR

Examples:
  # Detect stale branches with default thresholds
  $0

  # Use custom thresholds
  $0 --stale-days 21 --abandoned-days 45

  # Output to JSON file
  $0 --format json --output /tmp/stale-branches.json

  # Verbose mode without database logging
  $0 --verbose --no-db

Exit Codes:
  0      Success (with stale branches found)
  1      Error occurred
  2      No stale branches found
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
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
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

    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|csv)$ ]]; then
        error "Invalid output format: $OUTPUT_FORMAT"
    fi

    # Validate thresholds
    if ! [[ "$STALE_DAYS" =~ ^[0-9]+$ ]] || ! [[ "$ABANDONED_DAYS" =~ ^[0-9]+$ ]]; then
        error "Invalid threshold values"
    fi

    if [[ $ABANDONED_DAYS -lt $STALE_DAYS ]]; then
        error "Abandoned threshold must be greater than stale threshold"
    fi
}

# Load configuration from YAML
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extract thresholds from config if available
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

    # Use centralized escape function if available
    if declare -f psql_escape > /dev/null; then
        # Query should already be escaped by caller
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
    else
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
    fi
}

# Initialize database table
init_db() {
    if [[ "$LOG_TO_DB" != "true" ]]; then
        return 0
    fi

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
  category VARCHAR(20),
  detected_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT unique_branch_status UNIQUE (branch_name, detected_at)
);
"

    query_db "$query" >/dev/null
    log "Database table initialized"
}

# Log branch to database
log_branch_to_db() {
    local branch="$1"
    local status="$2"
    local last_commit="$3"
    local last_commit_date="$4"
    local last_author="$5"
    local age_days="$6"
    local has_pr="$7"
    local pr_number="$8"
    local category="$9"

    if [[ "$LOG_TO_DB" != "true" ]]; then
        return 0
    fi

    # Validate and escape inputs using security functions
    if declare -f validate_branch_name > /dev/null; then
        branch=$(validate_branch_name "$branch") || return 1
        status=$(psql_escape "$status")
        last_commit=$(psql_escape "$last_commit")
        last_author=$(psql_escape "$last_author")
        category=$(psql_escape "$category")
    else
        # Basic escaping
        branch="${branch//\'/''}"
        status="${status//\'/''}"
        last_commit="${last_commit//\'/''}"
        last_author="${last_author//\'/''}"
        category="${category//\'/''}"
    fi

    # Convert has_pr string to boolean
    local has_pr_bool="false"
    [[ "$has_pr" == "true" ]] && has_pr_bool="true"

    # Format commit date for PostgreSQL
    local commit_date_formatted
    commit_date_formatted=$(date -d "@$last_commit_date" -u +'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "NULL")

    local query="
INSERT INTO branch_history (
  branch_name, status, last_commit_sha, last_commit_date, last_author,
  age_days, has_open_pr, pr_number, category
) VALUES (
  '$branch', '$status', '$last_commit', '$commit_date_formatted', '$last_author',
  $age_days, $has_pr_bool, ${pr_number:-NULL}, '$category'
)
ON CONFLICT (branch_name, detected_at) DO UPDATE SET
  status = EXCLUDED.status,
  last_commit_sha = EXCLUDED.last_commit_sha,
  last_commit_date = EXCLUDED.last_commit_date,
  last_author = EXCLUDED.last_author,
  age_days = EXCLUDED.age_days,
  has_open_pr = EXCLUDED.has_open_pr,
  pr_number = EXCLUDED.pr_number,
  category = EXCLUDED.category,
  updated_at = NOW();
"

    query_db "$query" >/dev/null

    [[ $VERBOSE -eq 1 ]] && log "  Logged to DB: $branch ($category)"
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

# Get last commit metadata
get_last_commit_info() {
    local branch="$1"

    local commit_sha
    local commit_date
    local commit_author

    commit_sha=$(git rev-parse "$branch" 2>/dev/null)
    commit_date=$(git log -1 --format='%ct' "$branch" 2>/dev/null)
    commit_author=$(git log -1 --format='%an' "$branch" 2>/dev/null)

    echo "$commit_sha|$commit_date|$commit_author"
}

# Calculate age in days
calculate_age() {
    local commit_timestamp="$1"
    local current_timestamp
    current_timestamp=$(date +%s)
    local age_seconds=$((current_timestamp - commit_timestamp))

    echo $((age_seconds / 86400))
}

# Check if branch has an open PR and get PR number
get_pr_info() {
    local branch="$1"

    if command -v gh &>/dev/null; then
        local pr_data
        pr_data=$(gh pr list --head "$branch" --state open --json number,title --jq '.[0] // empty' 2>/dev/null || echo "")

        if [[ -n "$pr_data" ]]; then
            local pr_number
            pr_number=$(echo "$pr_data" | jq -r '.number // empty')
            echo "true|${pr_number}"
        else
            echo "false|"
        fi
    else
        echo "false|"
    fi
}

# Categorize branch based on age and PR status
categorize_branch() {
    local age_days="$1"
    local has_pr="$2"

    if [[ $age_days -ge $ABANDONED_DAYS ]] && [[ "$has_pr" == "false" ]]; then
        echo "abandoned"
    elif [[ $age_days -ge $STALE_DAYS ]]; then
        echo "stale"
    else
        echo "active"
    fi
}

# ============================================
# Output Functions
# ============================================

output_text() {
    local active="$1"
    local stale="$2"
    local abandoned="$3"

    echo ""
    echo "=========================================="
    echo "Stale Branch Detection Report"
    echo "=========================================="
    echo "Stale Threshold: $STALE_DAYS days"
    echo "Abandoned Threshold: $ABANDONED_DAYS days"
    echo "Generated: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    # Active branches
    if [[ -n "$active" ]]; then
        echo -e "${GREEN}Active Branches${NC} (< $STALE_DAYS days):"
        echo "$active" | while IFS='|' read -r branch age author has_pr; do
            echo "  ✓ $branch (${age} days old, author: $author)"
        done
        echo ""
    fi

    # Stale branches
    if [[ -n "$stale" ]]; then
        echo -e "${YELLOW}Stale Branches${NC} (>= $STALE_DAYS days, has PR):"
        echo "$stale" | while IFS='|' read -r branch age author has_pr pr_num; do
            local pr_info=""
            [[ "$has_pr" == "true" ]] && pr_info=" [PR: #$pr_num]"
            echo "  ⚠ $branch (${age} days old, author: $author)${pr_info}"
        done
        echo ""
    fi

    # Abandoned branches
    if [[ -n "$abandoned" ]]; then
        echo -e "${RED}Abandoned Branches${NC} (>= $ABANDONED_DAYS days, no PR):"
        echo "$abandoned" | while IFS='|' read -r branch age author has_pr; do
            echo "  ✗ $branch (${age} days old, author: $author)"
        done
        echo ""
    fi
}

output_json() {
    local active="$1"
    local stale="$2"
    local abandoned="$3"

    cat << EOF
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "stale_threshold_days": $STALE_DAYS,
  "abandoned_threshold_days": $ABANDONED_DAYS,
  "summary": {
    "active_count": $(echo "$active" | wc -l),
    "stale_count": $(echo "$stale" | wc -l),
    "abandoned_count": $(echo "$abandoned" | wc -l)
  },
  "branches": {
    "active": [
$(echo "$active" | while IFS='|' read -r branch age author has_pr; do
    [[ -z "$branch" ]] && continue
    cat << BRANCH
      {
        "name": "$branch",
        "age_days": $age,
        "last_author": "$author",
        "has_open_pr": $has_pr
      },
BRANCH
done | sed '$ s/,$//')
    ],
    "stale": [
$(echo "$stale" | while IFS='|' read -r branch age author has_pr pr_num; do
    [[ -z "$branch" ]] && continue
    cat << BRANCH
      {
        "name": "$branch",
        "age_days": $age,
        "last_author": "$author",
        "has_open_pr": $has_pr,
        "pr_number": ${pr_num:-null}
      },
BRANCH
done | sed '$ s/,$//')
    ],
    "abandoned": [
$(echo "$abandoned" | while IFS='|' read -r branch age author has_pr; do
    [[ -z "$branch" ]] && continue
    cat << BRANCH
      {
        "name": "$branch",
        "age_days": $age,
        "last_author": "$author",
        "has_open_pr": $has_pr
      },
BRANCH
done | sed '$ s/,$//')
    ]
  }
}
EOF
}

output_csv() {
    local active="$1"
    local stale="$2"
    local abandoned="$3"

    echo "Category,Branch Name,Age Days,Last Author,Has Open PR"

    echo "$active" | while IFS='|' read -r branch age author has_pr; do
        [[ -z "$branch" ]] || echo "active,$branch,$age,$author,$has_pr"
    done

    echo "$stale" | while IFS='|' read -r branch age author has_pr pr_num; do
        [[ -z "$branch" ]] || echo "stale,$branch,$age,$author,$has_pr"
    done

    echo "$abandoned" | while IFS='|' read -r branch age author has_pr; do
        [[ -z "$branch" ]] || echo "abandoned,$branch,$age,$author,$has_pr"
    done
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

    # Initialize database
    init_db

    log "Detecting stale branches..."
    log "Thresholds: stale=$STALE_DAYS days, abandoned=$ABANDONED_DAYS days"

    # Get all branches
    local branches
    branches=$(git branch | sed 's/^[* ] //')

    if [[ -z "$branches" ]]; then
        log "No branches found"
        exit 2
    fi

    # Categorize branches
    local active_branches=""
    local stale_branches=""
    local abandoned_branches=""

    local active_count=0
    local stale_count=0
    local abandoned_count=0
    local protected_count=0

    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue

        # Skip protected branches
        if is_protected "$branch"; then
            ((protected_count++))
            [[ $VERBOSE -eq 1 ]] && log "  Skipping protected branch: $branch"
            continue
        fi

        # Get branch metadata
        local commit_info
        commit_info=$(get_last_commit_info "$branch")
        IFS='|' read -r commit_sha commit_date commit_author <<< "$commit_info"

        # Calculate age
        local age_days
        age_days=$(calculate_age "$commit_date")

        # Get PR info
        local pr_info
        pr_info=$(get_pr_info "$branch")
        IFS='|' read -r has_pr pr_number <<< "$pr_info"

        # Categorize
        local category
        category=$(categorize_branch "$age_days" "$has_pr")

        # Add to appropriate list
        case "$category" in
            active)
                active_branches+="${branch}|${age_days}|${commit_author}|${has_pr}\n"
                ((active_count++))
                ;;
            stale)
                stale_branches+="${branch}|${age_days}|${commit_author}|${has_pr}|${pr_number}\n"
                ((stale_count++))
                ;;
            abandoned)
                abandoned_branches+="${branch}|${age_days}|${commit_author}|${has_pr}\n"
                ((abandoned_count++))
                ;;
        esac

        # Log to database
        log_branch_to_db "$branch" "detected" "$commit_sha" "$commit_date" \
            "$commit_author" "$age_days" "$has_pr" "$pr_number" "$category"

        [[ $VERBOSE -eq 1 ]] && log "  Analyzed: $branch (${category}, ${age_days} days)"

    done <<< "$branches"

    # Generate output
    local output
    case "$OUTPUT_FORMAT" in
        text)
            output=$(output_text "$active_branches" "$stale_branches" "$abandoned_branches")
            ;;
        json)
            output=$(output_json "$active_branches" "$stale_branches" "$abandoned_branches")
            ;;
        csv)
            output=$(output_csv "$active_branches" "$stale_branches" "$abandoned_branches")
            ;;
    esac

    # Write to file or stdout
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$output" > "$OUTPUT_FILE"
        log "Output written to: $OUTPUT_FILE"
    else
        echo "$output"
    fi

    # Print summary
    log "Detection complete!"
    log "Active: $active_count, Stale: $stale_count, Abandoned: $abandoned_count, Protected: $protected_count"

    # Exit with appropriate code
    if [[ $stale_count -gt 0 ]] || [[ $abandoned_count -gt 0 ]]; then
        exit 0
    else
        log "No stale or abandoned branches found"
        exit 2
    fi
}

# Run main function
main "$@"
