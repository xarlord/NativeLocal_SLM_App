#!/bin/bash
# link-issues-to-commits.sh
# Scan commit messages for issue references
# Pattern: #{number} or closes #{number}
# Link commits to issues via gh CLI
# Track which issues are addressed by commits
# Usage: ./link-issues-to-commits.sh [commit_range]

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

# Commit range (default: last 100 commits)
COMMIT_RANGE="${1:-HEAD~100..HEAD}"

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

# Extract issue references from commit message
extract_issue_references() {
    local commit_message="$1"

    # Pattern: #123, closes #123, fixes #123, resolves #123
    # Also supports: #123, close #123, fix #123, resolve #123

    local issues
    issues=$(echo "${commit_message}" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | sort -u || echo "")

    echo "${issues}"
}

# Get commits in range
get_commits() {
    local range="$1"

    log "Fetching commits in range: ${range}"

    git log "${range}" --pretty=format:"%H|%s|%b" 2>/dev/null || {
        error "Failed to fetch commits. Check the commit range."
    }
}

# Get commit details
get_commit_details() {
    local commit_hash="$1"

    local author
    local date
    local url

    author=$(git log -1 --format="%an" "${commit_hash}" 2>/dev/null)
    date=$(git log -1 --format="%ci" "${commit_hash}" 2>/dev/null)

    # Get GitHub repo for URL
    local repo_url
    repo_url=$(git remote get-url origin 2>/dev/null | sed 's|\.git$||' || echo "")

    if [[ -n "${repo_url}" ]]; then
        url="${repo_url}/commit/${commit_hash}"
    else
        url=""
    fi

    echo "${author}|${date}|${url}"
}

# Check if commit closes/fixes issue
check_closing_keyword() {
    local commit_message="$1"
    local message_lower
    message_lower=$(echo "${commit_message}" | tr '[:upper:]' '[:lower:]')

    if echo "${message_lower}" | grep -qE "(closes?|fixes?|resolves?)\s*#"; then
        echo "true"
    else
        echo "false"
    fi
}

# Add commit reference to issue
add_commit_reference() {
    local issue_number="$1"
    local commit_hash="$2"
    local commit_url="$3"
    local closes="$4"

    local comment

    if [[ "${closes}" == "true" ]]; then
        comment="**Commit referenced:** \`${commit_hash:0:8}\`

This commit addresses this issue.

View: [${commit_hash:0:8}](${commit_url})

---
*Automatically linked from commit message*"
    else
        comment="**Related commit:** \`${commit_hash:0:8}\`

View: [${commit_hash:0:8}](${commit_url})

---
*Automatically linked from commit message*"
    fi

    log "Adding commit reference to issue #${issue_number}"

    gh issue comment "${issue_number}" --body "${comment}" 2>/dev/null || {
        log "Warning: Failed to add comment to issue #${issue_number}"
        return 1
    }

    log "Commit reference added successfully"
    return 0
}

# Ensure issue_commits table exists
ensure_issue_commits_table() {
    local query="
CREATE TABLE IF NOT EXISTS issue_commits (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    commit_hash VARCHAR(40) NOT NULL,
    commit_url TEXT,
    commit_message TEXT,
    commit_author VARCHAR(200),
    commit_date TIMESTAMP,
    closes_issue BOOLEAN DEFAULT FALSE,
    linked_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(issue_number, commit_hash)
);
"

    query_db "${query}" >/dev/null
}

# Log issue-commit link to database
log_issue_commit_link() {
    local issue_number="$1"
    local commit_hash="$2"
    local commit_url="$3"
    local commit_message="$4"
    local commit_author="$5"
    local commit_date="$6"
    local closes="$7"

    log "Logging issue-commit link to database..."

    local message_sanitized
    message_sanitized=$(echo "${commit_message}" | sed "s/'/''/g" | head -c 1000)

    local query="
INSERT INTO issue_commits (issue_number, commit_hash, commit_url, commit_message, commit_author, commit_date, closes_issue)
VALUES (${issue_number}, '${commit_hash}', '${commit_url}', '${message_sanitized}', '${commit_author}', '${commit_date}', ${closes})
ON CONFLICT (issue_number, commit_hash) DO UPDATE SET
    commit_url = EXCLUDED.commit_url,
    closes_issue = EXCLUDED.closes_issue,
    linked_at = NOW();
"

    query_db "${query}" >/dev/null

    log "Issue-commit link logged successfully"
}

# Get GitHub repo
get_github_repo() {
    git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]\(.*\)\.git|\1|' || echo ""
}

# Check if commit already linked
is_commit_linked() {
    local issue_number="$1"
    local commit_hash="$2"

    local query="
SELECT COUNT(*)
FROM issue_commits
WHERE issue_number = ${issue_number} AND commit_hash = '${commit_hash}';
"

    local count
    count=$(query_db "${query}")

    if [[ "${count}" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local commit_range="${COMMIT_RANGE}"

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI (gh) is not installed or not in PATH"
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
    fi

    # Get GitHub repo
    GITHUB_REPO=$(get_github_repo)

    if [[ -z "${GITHUB_REPO}" ]]; then
        log "Warning: Could not determine GitHub repository"
    fi

    log "Starting issue-to-commit linking..."
    log "Commit range: ${commit_range}"

    # Ensure database table exists
    ensure_issue_commits_table

    # Get commits
    local commits
    commits=$(get_commits "${commit_range}")

    local commit_count
    commit_count=$(echo "${commits}" | wc -l)

    if [[ ${commit_count} -eq 0 ]]; then
        log "No commits found in range"
        exit 0
    fi

    log "Processing ${commit_count} commits..."

    local total_links=0
    local total_commits=0

    # Process each commit
    while IFS='|' read -r hash subject body; do
        [[ -z "${hash}" ]] && continue

        total_commits=$((total_commits + 1))

        local full_message="${subject}"$'\n'"${body}"

        log "Processing commit ${hash:0:8}: ${subject}"

        # Extract issue references
        local issues
        issues=$(extract_issue_references "${full_message}")

        if [[ -z "${issues}" ]]; then
            log "  No issue references found"
            continue
        fi

        # Get commit details
        local commit_details
        commit_details=$(get_commit_details "${hash}")

        local author date url
        IFS='|' read -r author date url <<< "${commit_details}"

        # Check if commit closes issues
        local closes
        closes=$(check_closing_keyword "${full_message}")

        # Process each issue reference
        while read -r issue_number; do
            [[ -z "${issue_number}" ]] && continue

            log "  Found reference to issue #${issue_number}"

            # Check if already linked
            if is_commit_linked "${issue_number}" "${hash}"; then
                log "    Already linked, skipping"
                continue
            fi

            # Verify issue exists
            if ! gh issue view "${issue_number}" &>/dev/null; then
                log "    Issue #${issue_number} does not exist or no access"
                continue
            fi

            # Add commit reference to issue
            local commit_url="${url}"
            if [[ -z "${commit_url}" && -n "${GITHUB_REPO}" ]]; then
                commit_url="https://github.com/${GITHUB_REPO}/commit/${hash}"
            fi

            if add_commit_reference "${issue_number}" "${hash}" "${commit_url}" "${closes}"; then
                # Log to database
                log_issue_commit_link "${issue_number}" "${hash}" "${commit_url}" "${subject}" "${author}" "${date}" "${closes}"

                total_links=$((total_links + 1))

                # If commit closes issue, add label
                if [[ "${closes}" == "true" ]]; then
                    log "    Commit closes issue, adding 'in-progress' label"
                    gh issue edit "${issue_number}" --add-label "in-progress" 2>/dev/null || true
                fi
            fi
        done <<< "${issues}"
    done <<< "${commits}"

    log "Issue-to-commit linking complete!"
    log "Processed: ${total_commits} commits"
    log "Created links: ${total_links}"
}

# Run main function
main "$@"
