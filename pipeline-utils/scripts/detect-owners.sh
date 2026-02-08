#!/bin/bash
# detect-owners.sh
# Detect code owners based on Git history and CODEOWNERS file
# Maps changed files to their owners for notification routing

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Git configuration
GIT_REPO="${PROJECT_ROOT}"
COMMIT_SHA="${CI_COMMIT_SHA:-HEAD}"
BASE_COMMIT="${CI_COMMIT_PARENT:-HEAD~1}"

# Output file
OUTPUT_FILE="${1:-/tmp/code-owners.json}"

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

# Get list of changed files in this commit
get_changed_files() {
    local commit="$1"

    git -C "${GIT_REPO}" diff --name-only "${BASE_COMMIT}...${commit}" 2>/dev/null || \
    git -C "${GIT_REPO}" ls-tree -r --name-only "${commit}" 2>/dev/null || echo ""
}

# Parse CODEOWNERS file
parse_codeowners() {
    local codeowners_file="${GIT_REPO}/.github/CODEOWNERS"
    local codeowners_doc="${GIT_REPO}/docs/CODEOWNERS"

    # Check for CODEOWNERS file in common locations
    if [[ -f "${codeowners_file}" ]]; then
        parse_codeowners_file "${codeowners_file}"
    elif [[ -f "${codeowners_doc}" ]]; then
        parse_codeowners_file "${codeowners_doc}"
    elif [[ -f "${GIT_REPO}/CODEOWNERS" ]]; then
        parse_codeowners_file "${GIT_REPO}/CODEOWNERS"
    else
        log "No CODEOWNERS file found, will use Git history only"
        return 1
    fi
}

# Parse a CODEOWNERS file and return pattern|owner mappings
parse_codeowners_file() {
    local file="$1"
    log "Parsing CODEOWNERS file: ${file}"

    # Parse CODEOWNERS format:
    # pattern @owner1 @owner2
    # *.kt @team
    # /docs/** @username

    grep -vE '^(#|$)' "${file}" | while read -r pattern owners; do
        # Clean up the pattern
        pattern=$(echo "${pattern}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Extract owners (handles @username, @team, or email)
        owners=$(echo "${owners}" | grep -oE '@[a-zA-Z0-9_-]+|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | tr '\n' ',' | sed 's/,$//')

        if [[ -n "${pattern}" && -n "${owners}" ]]; then
            echo "${pattern}|${owners}"
        fi
    done
}

# Convert CODEOWNERS glob pattern to regex
glob_to_regex() {
    local glob="$1"

    # Convert glob to regex
    # * -> .*
    # ** -> .*
    # ? -> .
    # [abc] -> [abc]
    # / (at start) -> ^/

    local regex="${glob}"

    # Escape special regex characters except glob wildcards
    regex=$(echo "${regex}" | sed 's/[\.\^$\()|+]/\\&/g')

    # Convert glob patterns to regex
    regex=$(echo "${regex}" | sed 's/\*\*/\.\*/g')  # ** -> .*
    regex=$(echo "${regex}" | sed 's/^\//^\\//')     # / at start -> ^/
    regex=$(echo "${regex}" | sed 's/\*/[^\/]*/g')  # * -> [^/]*
    regex=$(echo "${regex}" | sed 's/\?/./g')       # ? -> .

    echo "${regex}"
}

# Match file against CODEOWNERS patterns
match_codeowner_pattern() {
    local file="$1"
    local owners_data="$2"

    local matched_owners=""

    # Check each pattern
    while IFS='|' read -r pattern owners; do
        local regex
        regex=$(glob_to_regex "${pattern}")

        if echo "${file}" | grep -qE "${regex}"; then
            if [[ -z "${matched_owners}" ]]; then
                matched_owners="${owners}"
            else
                matched_owners="${matched_owners},${owners}"
            fi
        fi
    done <<< "${owners_data}"

    echo "${matched_owners}"
}

# Get Git history authors for a file
get_git_authors() {
    local file="$1"
    local max_authors="${2:-5}"
    local since="${3:-6 months ago}"

    # Get authors with commit count for this file
    git -C "${GIT_REPO}" log --since="${since}" --pretty=format:"%an" -- "${file}" 2>/dev/null | \
        sort | uniq -c | sort -rn | head -n "${max_authors}" | \
        awk '{print $2}' | tr '\n' ',' | sed 's/,$//'
}

# Map GitHub username from author name
map_github_username() {
    local author="$1"

    # Try to get from .mailmap
    local mailmap_user
    mailmap_user=$(grep -i "^${author}" "${GIT_REPO}/.mailmap" 2>/dev/null | head -1 | awk '{print $NF}')

    if [[ -n "${mailmap_user}" ]]; then
        echo "${mailmap_user}"
        return
    fi

    # Try to extract from email if available
    local email
    email=$(git -C "${GIT_REPO}" log --author="${author}" --format="%ae" -1 2>/dev/null)

    if [[ -n "${email}" ]]; then
        # Extract username from common email patterns
        if echo "${email}" | grep -qE "@users\.noreply\.github\.com$"; then
            echo "${email%@*}"
            return
        fi

        # For other emails, return the author name as-is
        # (In production, you'd query GitHub API here)
        echo "${author}"
        return
    fi

    echo "${author}"
}

# Store code ownership in database
store_code_ownership() {
    local file_pattern="$1"
    local owner_name="$2"
    local github_username="$3"
    local ownership_strength="$4"

    log "Storing ownership: ${file_pattern} -> ${owner_name}"

    local pattern_sanitized=$(echo "${file_pattern}" | sed "s/'/''/g")
    local owner_sanitized=$(echo "${owner_name}" | sed "s/'/''/g")
    local github_sanitized=$(echo "${github_username}" | sed "s/'/''/g")

    local query="
INSERT INTO code_ownership (
    file_pattern,
    owner_type,
    owner_name,
    github_username,
    ownership_strength,
    last_verified
) VALUES (
    '${pattern_sanitized}',
    'user',
    '${owner_sanitized}',
    '${github_sanitized}',
    ${ownership_strength},
    NOW()
) ON CONFLICT (file_pattern, owner_name) DO UPDATE SET
    ownership_strength = EXCLUDED.ownership_strength,
    last_verified = EXCLUDED.last_verified;
"

    query_db "${query}" >/dev/null
}

# Get owners from database
get_owners_from_db() {
    local file="$1"

    # Try to match against database patterns
    local query="
SELECT DISTINCT owner_name, github_username
FROM code_ownership
WHERE '${file}' ~ file_pattern
ORDER BY ownership_strength DESC
LIMIT 5;
"

    query_db "${query}" | while read -r owner; do
        echo "${owner}"
    done
}

# ============================================
# Main Execution
# ============================================

main() {
    log "Starting code ownership detection..."
    log "Repository: ${GIT_REPO}"
    log "Commit: ${COMMIT_SHA}"
    log "Base commit: ${BASE_COMMIT}"

    # Get changed files
    log "Getting changed files..."
    changed_files=$(get_changed_files "${COMMIT_SHA}")

    if [[ -z "${changed_files}" ]]; then
        log "No changed files found"
        echo "[]"
        exit 0
    fi

    local file_count
    file_count=$(echo "${changed_files}" | wc -l)
    log "Found ${file_count} changed files"

    # Parse CODEOWNERS file if it exists
    local codeowners_data=""
    if parse_codeowners; then
        log "CODEOWNERS file parsed successfully"
        codeowners_data=$(parse_codeowners)
    fi

    # Build owners mapping
    local all_owners=()
    declare -A owner_counts
    declare -A owner_files

    while read -r file; do
        [[ -z "${file}" ]] && continue

        log "Processing: ${file}"

        local file_owners=""

        # 1. Check CODEOWNERS first
        if [[ -n "${codeowners_data}" ]]; then
            file_owners=$(match_codeowner_pattern "${file}" "${codeowners_data}")
        fi

        # 2. Fall back to database
        if [[ -z "${file_owners}" ]]; then
            file_owners=$(get_owners_from_db "${file}")
        fi

        # 3. Fall back to Git history
        if [[ -z "${file_owners}" ]]; then
            file_owners=$(get_git_authors "${file}" 3)
        fi

        if [[ -n "${file_owners}" ]]; then
            log "  Owners: ${file_owners}"

            # Parse comma-separated owners
            IFS=',' read -ra OWNERS <<< "${file_owners}"
            for owner in "${OWNERS[@]}"; do
                owner=$(echo "${owner}" | tr -d ' @')

                # Increment count
                owner_counts["${owner}"]=$((${owner_counts["${owner}"]:-0} + 1))

                # Track files
                if [[ -n "${owner_files[${owner}]+x}" ]]; then
                    owner_files["${owner}"]+=",${file}"
                else
                    owner_files["${owner}"]="${file}"
                fi

                # Store in database for future lookups
                local github_user
                github_user=$(map_github_username "${owner}")
                store_code_ownership "${file}" "${owner}" "${github_user}" "1.0"
            done
        else
            log "  No owners found for ${file}"
        fi
    done <<< "${changed_files}"

    # Sort owners by number of files they own
    local sorted_owners=()
    for owner in "${!owner_counts[@]}"; do
        sorted_owners+=("${owner_counts[${owner}]}|${owner}")
    done

    IFS=$'\n' sorted_owners=($(sort -rn <<<"${sorted_owners[*]}"))
    unset IFS

    # Build JSON output
    log "Building owners list..."

    local json_output="["
    local first=true

    for entry in "${sorted_owners[@]}"; do
        IFS='|' read -r count owner <<< "${entry}"

        if [[ "${first}" == "true" ]]; then
            first=false
        else
            json_output+=","
        fi

        local github_user
        github_user=$(map_github_username "${owner}")

        local files_list="${owner_files[${owner}]}"
        local files_json=$(echo "${files_list}" | jq -R -S -s 'split(",") | unique')

        json_output+=$(cat <<EOF
{
  "name": "${owner}",
  "github_username": "${github_user}",
  "files_owned": ${count},
  "files": ${files_json}
}
EOF
)
    done

    json_output+="]"

    # Output JSON
    echo "${json_output}" | jq '.' > "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"

    # Also output comma-separated list for easy use in scripts
    echo "" >&2
    echo "Owners (comma-separated):" >&2
    echo "${json_output}" | jq -r '[.[].github_username] | join(",")' >&2

    log "Code ownership detection complete!"
    log "Total owners: ${#owner_counts[@]}"
    log "Results saved to: ${OUTPUT_FILE}"
}

# Run main function
main "$@"
