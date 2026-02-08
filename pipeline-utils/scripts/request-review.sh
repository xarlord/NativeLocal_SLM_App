#!/bin/bash
# request-review.sh
# Auto-assign reviewers based on code ownership
# Usage: ./request-review.sh <pr-number> [reviewers]
# Queries code_ownership table for changed files

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RETRY_SCRIPT="${SCRIPT_DIR}/retry-command.sh"

# Source security utilities
source "${SCRIPT_DIR}/security-utils.sh" || {
    log "WARNING: security-utils.sh not found, security features limited"
}

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Default reviewers (comma-separated)
DEFAULT_REVIEWERS="${DEFAULT_REVIEWERS:-}"
FALLBACK_REVIEWERS="${FALLBACK_REVIEWERS:-}"

# Team configuration
TEAM_REVIEWERS="${TEAM_REVIEWERS:-}"

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

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Check gh CLI
check_gh_cli() {
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI not found. Please install gh first."
    fi

    if ! gh auth status &>/dev/null; then
        error "GitHub CLI not authenticated. Run: gh auth login"
    fi
}

# Get changed files in PR
get_changed_files() {
    local pr_number="$1"

    log "Fetching changed files for PR #${pr_number}..."

    local files_json
    files_json=$(gh pr diff "${pr_number}" --name-only 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]")

    echo "${files_json}"
}

# Find code owners for files
find_code_owners() {
    local files_json="$1"

    log "Querying code ownership database..."

    local owners_list=""

    # Parse files and query for each
    local file_count
    file_count=$(echo "${files_json}" | jq 'length')

    if [[ "${file_count}" -eq 0 ]]; then
        log "No files found in PR"
        echo "[]"
        return
    fi

    log "Checking ${file_count} file(s) for ownership..."

    # Build SQL query to find owners for all files (with SQL injection protection)
    local query="
SELECT DISTINCT
    github_username,
    owner_name,
    ownership_strength
FROM code_ownership
WHERE "

    local first=true
    for i in $(seq 0 $((file_count - 1))); do
        local file_path
        file_path=$(echo "${files_json}" | jq -r ".[${i}]")

        if [[ -z "${file_path}" ]]; then
            continue
        fi

        # Validate and escape file path to prevent SQL injection
        local escaped_path
        if command -v validate_and_escape_path &>/dev/null; then
            escaped_path=$(validate_and_escape_path "${file_path}") || {
                log "Warning: Invalid file path skipped: ${file_path}"
                continue
            }
        elif command -v psql_escape &>/dev/null; then
            # Validate path first
            if [[ "${file_path}" =~ \.\. ]]; then
                log "Warning: Path contains directory traversal, skipped: ${file_path}"
                continue
            fi
            escaped_path=$(psql_escape "${file_path}")
        else
            # Fallback validation
            if [[ "${file_path}" =~ \.\. ]]; then
                log "Warning: Path contains directory traversal, skipped: ${file_path}"
                continue
            fi
            escaped_path=$(echo "${file_path}" | sed "s/'/''/g")
        fi

        if [[ "${first}" == "true" ]]; then
            query+="'${escaped_path}' LIKE file_pattern"
            first=false
        else
            query+=" OR '${escaped_path}' LIKE file_pattern"
        fi
    done

    query+=" ORDER BY ownership_strength DESC;"

    local results
    results=$(query_db "${query}")

    if [[ -z "${results}" ]]; then
        log "No code owners found in database"
        echo "[]"
        return
    fi

    # Parse results and build unique list
    local seen_users=""

    echo "${results}" | while IFS='|' read -r github_username owner_name strength; do
        if [[ -n "${github_username}" && ! "${seen_users}" =~ "${github_username}" ]]; then
            echo "${github_username}"
            seen_users+="${github_username}|"
        fi
    done | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]"
}

# Get default reviewers if no owners found
get_default_reviewers() {
    log "Using default reviewers..."

    if [[ -n "${DEFAULT_REVIEWERS}" ]]; then
        echo "${DEFAULT_REVIEWERS}" | jq -R -s 'split(",") | map(select(length > 0))'
    elif [[ -n "${FALLBACK_REVIEWERS}" ]]; then
        echo "${FALLBACK_REVIEWERS}" | jq -R -s 'split(",") | map(select(length > 0))'
    else
        echo "[]"
    fi
}

# Assign reviewers to PR
assign_reviewers() {
    local pr_number="$1"
    local reviewers_json="$2"
    local team_reviewers="${3:-}"

    log "Assigning reviewers to PR #${pr_number}..."

    # Extract reviewer list
    local reviewers
    reviewers=$(echo "${reviewers_json}" | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

    if [[ -z "${reviewers}" ]] && [[ -z "${team_reviewers}" ]]; then
        log "No reviewers to assign"
        return 1
    fi

    # Build gh command
    local cmd=("gh" "pr" "edit" "${pr_number}")

    if [[ -n "${reviewers}" ]]; then
        cmd+=("--add-reviewer" "${reviewers}")
    fi

    if [[ -n "${team_reviewers}" ]]; then
        cmd+=("--add-team-reviewer" "${team_reviewers}")
    fi

    # Execute with retry
    local output
    output=$("${RETRY_SCRIPT}" --max-retries=3 --delay=10 "${cmd[@]}" 2>&1)

    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        # Check if it's just a warning (reviewers might not exist)
        if [[ "${output}" =~ "could not be found" ]] || [[ "${output}" =~ "does not exist" ]]; then
            log "Warning: Some reviewers could not be found"
            log "Output: ${output}"
            return 0
        else
            log "Failed to assign reviewers: ${output}"
            return 1
        fi
    fi

    log "Reviewers assigned successfully"
    return 0
}

# Get current reviewers from PR
get_current_reviewers() {
    local pr_number="$1"

    log "Getting current reviewers for PR #${pr_number}..."

    local reviewers_json
    reviewers_json=$(gh pr view "${pr_number}" --json reviews -q '.reviews[].author.login' 2>/dev/null | jq -s 'unique' || echo "[]")

    echo "${reviewers_json}"
}

# Check if PR already has required approvals
check_approvals() {
    local pr_number="$1"
    local required_reviewers="${2:-1}"

    log "Checking PR approvals..."

    local approval_count
    approval_count=$(gh pr view "${pr_number}" --json reviews -q '[.reviews[] | select(.state == "APPROVED")] | length' 2>/dev/null || echo "0")

    log "Current approvals: ${approval_count}"

    if [[ "${approval_count}" -ge "${required_reviewers}" ]]; then
        log "PR already has required approvals"
        return 0
    else
        log "PR needs more approvals (${approval_count}/${required_reviewers})"
        return 1
    fi
}

# Update database with reviewer assignments
update_database() {
    local pr_number="$1"
    local reviewers_json="$2"

    log "Updating database with reviewer assignments..."

    local query="
UPDATE automated_prs
SET
    reviewers = '${reviewers_json}'::jsonb,
    approval_count = (
        SELECT COUNT(*)
        FROM (
            SELECT 1
            WHERE EXISTS (
                SELECT 1
                FROM (
                    SELECT jsonb_array_elements_text(reviewers) as reviewer
                ) reviewers
                WHERE reviewers.review reviewer IN (
                    SELECT jsonb_array_elements_text('${reviewers_json}'::jsonb)
                )
            )
        ) AS approved
    ),
    updated_at = NOW()
WHERE pr_number = ${pr_number};
"

    query_db "${query}" >/dev/null
}

# ============================================
# Main Execution
# ============================================

main() {
    local pr_number="$1"
    shift
    local specified_reviewers="$*"

    log "=== Auto-Review Request Script ==="
    log "PR Number: ${pr_number}"

    # Check prerequisites
    check_gh_cli

    # Get changed files
    local files_json
    files_json=$(get_changed_files "${pr_number}")

    local file_count
    file_count=$(echo "${files_json}" | jq 'length')
    log "Files changed: ${file_count}"

    # Find reviewers
    local reviewers_json

    # If reviewers explicitly specified, use them
    if [[ -n "${specified_reviewers}" ]]; then
        log "Using explicitly specified reviewers"
        reviewers_json=$(echo "${specified_reviewers}" | jq -R -s 'split(" ") | map(select(length > 0))')
    else
        # Try to find code owners
        reviewers_json=$(find_code_owners "${files_json}")

        # If no owners found, use defaults
        local reviewer_count
        reviewer_count=$(echo "${reviewers_json}" | jq 'length')

        if [[ "${reviewer_count}" -eq 0 ]]; then
            log "No code owners found, using default reviewers"
            reviewers_json=$(get_default_reviewers)
        fi
    fi

    local reviewer_count
    reviewer_count=$(echo "${reviewers_json}" | jq 'length')

    if [[ "${reviewer_count}" -eq 0 ]]; then
        error "No reviewers found and no default reviewers configured"
    fi

    log "Reviewers to assign:"
    echo "${reviewers_json}" | jq -r '.[]' | while read -r reviewer; do
        log "  - ${reviewer}"
    done

    # Get current reviewers to avoid duplicates
    local current_reviewers
    current_reviewers=$(get_current_reviewers "${pr_number}")

    # Filter out already assigned reviewers
    local new_reviewers_json
    new_reviewers_json=$(echo "${reviewers_json}" | jq --argjson current "${current_reviewers}" '. - $current')

    local new_reviewer_count
    new_reviewer_count=$(echo "${new_reviewers_json}" | jq 'length')

    if [[ "${new_reviewer_count}" -eq 0 ]]; then
        log "All specified reviewers are already assigned"
        log "Current approvals:"
        check_approvals "${pr_number}" 1 || true
        return 0
    fi

    log "New reviewers to assign: ${new_reviewer_count}"

    # Assign reviewers
    if assign_reviewers "${pr_number}" "${new_reviewers_json}" "${TEAM_REVIEWERS}"; then
        log "Reviewers assigned successfully"

        # Update database
        update_database "${pr_number}" "${reviewers_json}"

        log "=== Review Assignment Complete ==="
        log "PR: ${pr_number}"
        log "Total reviewers: ${reviewer_count}"
        log "Newly assigned: ${new_reviewer_count}"
    else
        log "Failed to assign some reviewers"
        exit 1
    fi
}

# Show usage
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <pr-number> [reviewers...]"
    echo ""
    echo "Arguments:"
    echo "  pr-number  GitHub PR number"
    echo "  reviewers  Optional: specific reviewers to assign"
    echo ""
    echo "The script will:"
    echo "  1. Get changed files from the PR"
    echo "  2. Query code_ownership table for owners"
    echo "  3. Fall back to DEFAULT_REVIEWERS if no owners found"
    echo "  4. Assign reviewers using gh CLI"
    echo "  5. Update automated_prs table"
    echo ""
    echo "Environment variables:"
    echo "  DEFAULT_REVIEWERS   Comma-separated default reviewers"
    echo "  FALLBACK_REVIEWERS  Fallback reviewers if defaults not set"
    echo "  TEAM_REVIEWERS      Team names to assign (comma-separated)"
    echo ""
    echo "Examples:"
    echo "  $0 123"
    echo "  $0 123 user1 user2"
    echo "  DEFAULT_REVIEWERS=user1,user2 $0 123"
    echo ""
    echo "Database requirements:"
    echo "  code_ownership table must be populated with file patterns"
    echo "  and corresponding GitHub usernames"
    exit 1
fi

# Run main function
main "$@"
