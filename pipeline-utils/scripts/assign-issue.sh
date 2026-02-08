#!/bin/bash
# assign-issue.sh
# Smart assignment based on code ownership
# Parse issue for file paths or module references
# Query code_ownership table for owners
# Assign to GitHub username via gh CLI
# Usage: ./assign-issue.sh {issue_number}

set -euo pipefail

# Error handling trap
trap cleanup EXIT

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log "Script failed with exit code: $exit_code"
    fi
}

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
CONFIG_FILE="${PROJECT_ROOT}/pipeline-utils/config/issue-triage.yaml"

# Source security utilities
source "${SCRIPT_DIR}/security-utils.sh"

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Default assignee from config or environment
DEFAULT_ASSIGNEE="${DEFAULT_ASSIGNEE:-}"

# Module discovery (read from config or discover automatically)
MODULES=()
if [[ -f "${PROJECT_ROOT}/config/modules.txt" ]]; then
    mapfile -t MODULES < "${PROJECT_ROOT}/config/modules.txt"
else
    # Discover modules by finding build.gradle.kts files
    mapfile -t MODULES < <(find "${PROJECT_ROOT}" -name "build.gradle.kts" -not -path "*/build/*" 2>/dev/null | sed "s|${PROJECT_ROOT}/||" | sed 's|/build.gradle.kts||' | grep -v '^$')
fi

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

# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    if command -v jq >/dev/null 2>&1; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
    else
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    if [[ ${remaining} -lt 100 ]]; then
        log "WARNING: GitHub API rate limit low: ${remaining} remaining"
        sleep 10
    fi
}

# Get default assignee from config
get_default_assignee() {
    if [[ -n "${DEFAULT_ASSIGNEE}" ]]; then
        echo "${DEFAULT_ASSIGNEE}"
        return
    fi

    if [[ -f "${CONFIG_FILE}" ]]; then
        local assignee
        assignee=$(grep "^default_assignee:" "${CONFIG_FILE}" | awk '{print $2}' | sed 's/#.*//;s/"//g')

        if [[ -n "${assignee}" ]]; then
            echo "${assignee}"
            return
        fi
    fi

    echo ""
}

# Get issue data
get_issue_data() {
    local issue_number="$1"

    log "Fetching issue #${issue_number} from GitHub..."

    check_github_rate_limit
    gh issue view "${issue_number}" --json title,body,labels,assignees 2>/dev/null || {
        error "Failed to fetch issue #${issue_number}"
    }
}

# Extract file paths from issue text
extract_file_paths() {
    local text="$1"

    # Look for file path patterns:
    # - src/main/kotlin/...
    # - app/src/...
    # - File: path/to/file
    # - In file: path/to/file
    # - `path/to/file`
    # - references to .kt, .java, .xml files

    local paths
    paths=$(echo "${text}" | grep -oE '\b[a-zA-Z0-9_/-]+\.[a-z]{2,4}\b|\b[src/app]/[a-zA-Z0-9_/-]+\b' | sort -u || echo "")

    echo "${paths}"
}

# Extract module references from issue text
extract_modules() {
    local text="$1"
    local text_lower
    text_lower=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

    # Common Android modules
    local modules="app core data domain ui presentation network database"

    local found_modules=()

    for module in ${modules}; do
        if echo "${text_lower}" | grep -qF "${module}"; then
            found_modules+=("${module}")
        fi
    done

    echo "${found_modules[@]}"
}

# Query code_ownership table for owners (with SQL injection protection)
get_owners_for_file() {
    local file_path="$1"

    log "Querying ownership for: ${file_path}"

    # Escape file path for SQL
    local escaped_path
    escaped_path=$(psql_escape "${file_path}")

    local query="
SELECT DISTINCT github_username, owner_name, ownership_strength
FROM code_ownership
WHERE '${escaped_path}' ~ file_pattern
ORDER BY ownership_strength DESC
LIMIT 5;
"

    query_db "${query}"
}

# Query code_ownership table for module owners (with SQL injection protection)
get_owners_for_module() {
    local module="$1"

    log "Querying ownership for module: ${module}"

    # Escape module name for SQL
    local escaped_module
    escaped_module=$(psql_escape "${module}")

    local query="
SELECT DISTINCT github_username, owner_name, ownership_strength
FROM code_ownership
WHERE module = '${escaped_module}' OR '${escaped_module}/' ~ file_pattern
ORDER BY ownership_strength DESC
LIMIT 5;
"

    query_db "${query}"
}

# Determine best assignees from issue content
determine_assignees() {
    local title="$1"
    local body="$2"
    local content="${title} ${body}"

    declare -A owner_scores
    declare -A owner_names

    # Extract file paths
    local file_paths
    file_paths=$(extract_file_paths "${content}")

    # Extract modules
    local modules
    modules=$(extract_modules "${content}")

    log "Analyzing issue for ownership..."

    # Check file paths
    while read -r file_path; do
        [[ -z "${file_path}" ]] && continue

        log "  Checking file: ${file_path}"

        local owners
        owners=$(get_owners_for_file "${file_path}")

        while IFS='|' read -r github_user owner_name strength; do
            [[ -z "${github_user}" ]] && continue

            [[ -z "${owner_names[${github_user}]+x}" ]] && owner_names[${github_user}]="${owner_name}"
            # Use integer arithmetic (0-100 scale instead of floating point)
            local strength_int
            strength_int=$(awk "BEGIN {printf \"%d\", ${strength} * 100}")
            owner_scores[${github_user}]=$((${owner_scores[${github_user}]:-0} + strength_int))

            log "    Found owner: ${github_user} (strength: ${strength})"
        done <<< "${owners}"
    done <<< "${file_paths}"

    # Check modules
    for module in ${modules}; do
        [[ -z "${module}" ]] && continue

        log "  Checking module: ${module}"

        local owners
        owners=$(get_owners_for_module "${module}")

        while IFS='|' read -r github_user owner_name strength; do
            [[ -z "${github_user}" ]] && continue

            [[ -z "${owner_names[${github_user}]+x}" ]] && owner_names[${github_user}]="${owner_name}"
            owner_scores[${github_user}]=$((${owner_scores[${github_user}]:-0} + 50))

            log "    Found owner: ${github_user}"
        done <<< "${owners}"
    done

    # Sort owners by score
    local sorted_owners=()
    for owner in "${!owner_scores[@]}"; do
        sorted_owners+=("${owner_scores[${owner}]}|${owner}")
    done

    IFS=$'\n' sorted_owners=($(sort -rn <<<"${sorted_owners[*]}"))
    unset IFS

    # Extract top owners (max 3) with minimum score threshold
    local assignees=()
    local min_score=50  # Minimum threshold for consideration (on 0-100 scale)
    for entry in "${sorted_owners[@]:0:3}"; do
        IFS='|' read -r score owner <<< "${entry}"
        # Only include if score exceeds minimum threshold
        if [[ ${score} -gt ${min_score} ]]; then
            assignees+=("${owner}")
        fi
    done

    # Output as comma-separated list
    echo "${assignees[@]}" | tr ' ' ','
}

# Assign issue to users with validation
assign_issue() {
    local issue_number="$1"
    local assignees="$2"

    if [[ -z "${assignees}" ]]; then
        log "No assignees to add"
        return 1
    fi

    log "Assigning issue #${issue_number} to: ${assignees}"

    # gh CLI expects space-separated list
    local assignee_list
    assignee_list=$(echo "${assignees}" | tr ',' ' ')

    # Assign to each user with validation
    for assignee in ${assignee_list}; do
        # Validate assignee format
        if ! is_valid_github_username "${assignee}"; then
            log "Warning: Invalid GitHub username format: ${assignee}"
            continue
        fi

        # Check if user exists
        if ! github_user_exists "${assignee}"; then
            log "Warning: GitHub user ${assignee} does not exist or is not accessible"
            continue
        fi

        # Attempt assignment
        if gh issue edit "${issue_number}" --add-assignee "${assignee}" 2>/dev/null; then
            log "  Successfully assigned to ${assignee}"
        else
            log "Warning: Failed to assign to ${assignee}"
        fi
    done

    log "Assignment complete"
    return 0
}

# Add assignment comment
add_assignment_comment() {
    local issue_number="$1"
    local assignees="$2"
    local reason="$3"

    local comment="## Issue Assignment

This issue has been automatically assigned to: ${assignees}

**Reason:** ${reason}

The assignment is based on code ownership patterns in the repository. If this assignment is incorrect, please reassign manually.

---
*This comment was automatically generated by the issue assignment system*"

    log "Adding assignment comment to issue #${issue_number}"

    check_github_rate_limit
    gh issue comment "${issue_number}" --body "${comment}" 2>/dev/null || {
        log "Warning: Failed to add comment"
        return 1
    }

    return 0
}

# Ensure assignment tracking table exists
ensure_assignment_table() {
    local query="
CREATE TABLE IF NOT EXISTS issue_assignments (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    assigned_to VARCHAR(100) NOT NULL,
    assignment_method VARCHAR(50) NOT NULL,
    file_pattern VARCHAR(500),
    assigned_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(issue_number, assigned_to)
);
"

    query_db "${query}" >/dev/null
}

# Log assignment to database with SQL injection protection
log_assignment() {
    local issue_number="$1"
    local assignee="$2"
    local method="${3:-ownership}"
    local pattern="${4:-}"

    log "Logging assignment to database..."

    # Validate inputs
    if ! is_valid_issue_number "${issue_number}"; then
        log_error "Invalid issue number: ${issue_number}"
        return 1
    fi

    if ! is_valid_github_username "${assignee}"; then
        log_error "Invalid assignee username: ${assignee}"
        return 1
    fi

    # Escape all string inputs for SQL
    local assignee_escaped
    local method_escaped
    local pattern_escaped

    assignee_escaped=$(psql_escape "${assignee}")
    method_escaped=$(psql_escape "${method}")
    pattern_escaped=$(psql_escape "${pattern}")

    local query="
INSERT INTO issue_assignments (issue_number, assigned_to, assignment_method, file_pattern)
VALUES (${issue_number}, '${assignee_escaped}', '${method_escaped}', '${pattern_escaped}')
ON CONFLICT (issue_number, assigned_to) DO UPDATE SET
    assignment_method = EXCLUDED.assignment_method,
    file_pattern = EXCLUDED.file_pattern,
    assigned_at = NOW();
"

    query_db "${query}" >/dev/null

    log "Assignment logged successfully"
}

# Check if issue is already assigned
is_already_assigned() {
    local issue_number="$1"

    local assignees
    if command -v jq >/dev/null 2>&1; then
        assignees=$(gh issue view "${issue_number}" --json assignees --jq '.assignees[].login' 2>/dev/null || echo "")
    else
        # Fallback: check if assignees field has data
        assignees=$(gh issue view "${issue_number}" --json assignees 2>/dev/null | grep -o '"login"' || echo "")
    fi

    if [[ -n "${assignees}" ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local issue_number="$1"

    if [[ -z "${issue_number}" ]]; then
        error "Usage: $0 {issue_number}"
    fi

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI (gh) is not installed or not in PATH"
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
    fi

    log "Starting smart assignment for issue #${issue_number}"

    # Ensure database table exists
    ensure_assignment_table

    # Check if already assigned
    if is_already_assigned "${issue_number}"; then
        log "Issue is already assigned, skipping"
        exit 0
    fi

    # Get issue data
    local issue_json
    issue_json=$(get_issue_data "${issue_number}")

    local title
    local body
    if command -v jq >/dev/null 2>&1; then
        title=$(echo "${issue_json}" | jq -r '.title')
        body=$(echo "${issue_json}" | jq -r '.body')
    else
        # Fallback parsing without jq
        title=$(echo "${issue_json}" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        body=$(echo "${issue_json}" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g')
    fi

    log "Issue title: ${title}"

    # Determine assignees
    local assignees
    local method
    assignees=$(determine_assignees "${title}" "${body}")

    if [[ -n "${assignees}" ]]; then
        method="code_ownership"
        log "Assignees determined: ${assignees}"
    else
        # Fall back to default assignee
        assignees=$(get_default_assignee)

        if [[ -n "${assignees}" ]]; then
            method="default"
            log "Using default assignee: ${assignees}"
        else
            log "No suitable assignees found"
            exit 0
        fi
    fi

    # Assign the issue
    assign_issue "${issue_number}" "${assignees}"

    # Add comment
    local comment_text
    if [[ "${method}" == "code_ownership" ]]; then
        comment_text="Based on code ownership patterns from files and modules mentioned in the issue"
    else
        comment_text="Default assignee from configuration"
    fi

    add_assignment_comment "${issue_number}" "${assignees}" "${comment_text}"

    # Log to database
    IFS=',' read -ra ASSIGNEE_ARRAY <<< "${assignees}"
    for assignee in "${ASSIGNEE_ARRAY[@]}"; do
        assignee=$(echo "${assignee}" | tr -d ' ')
        log_assignment "${issue_number}" "${assignee}" "${method}"
    done

    log "Issue assignment complete!"
}

# Run main function
main "$@"
