#!/bin/bash
# assign-unassigned-issues.sh
# Assign all unassigned issues using smart assignment
# Usage: ./assign-unassigned-issues.sh [--limit 20]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default: process up to 20 issues
LIMIT="${1:-20}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Check if gh CLI is available
if ! command -v gh &>/dev/null; then
    error "GitHub CLI (gh) is not installed or not in PATH"
fi

if ! gh auth status &>/dev/null; then
    error "GitHub CLI is not authenticated. Run: gh auth login"
fi

log "Assigning unassigned issues (limit: ${LIMIT})..."

# Get unassigned issues
issues=$(gh issue list --limit "${LIMIT}" --state open --search "no:assignee" --json number --jq '.[].number' || echo "")

if [[ -z "${issues}" ]]; then
    log "No unassigned issues found"
    exit 0
fi

issue_count=$(echo "${issues}" | wc -l)
log "Found ${issue_count} unassigned issues"

# Assign each issue
assigned=0
failed=0

while read -r issue_number; do
    [[ -z "${issue_number}" ]] && continue

    log "Assigning issue #${issue_number}..."

    if "${SCRIPT_DIR}/assign-issue.sh" "${issue_number}" 2>/dev/null; then
        assigned=$((assigned + 1))
    else
        failed=$((failed + 1))
        log "Warning: Failed to assign issue #${issue_number}"
    fi

    # Sleep to avoid rate limiting
    sleep 1
done <<< "${issues}"

log "Assignment complete!"
log "Assigned: ${assigned}"
log "Failed: ${failed}"

if [[ ${failed} -gt 0 ]]; then
    exit 1
fi
