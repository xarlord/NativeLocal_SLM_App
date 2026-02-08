#!/bin/bash
# classify-new-issues.sh
# Classify all new/unclassified issues
# Usage: ./classify-new-issues.sh [--days 7]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default: classify issues from last 7 days
DAYS="${1:-7}"

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

log "Classifying new issues from last ${DAYS} days..."

# Get new issues
since_date=$(date -d "${DAYS} days ago" +%Y-%m-%d)

issues=$(gh issue list --limit 100 --state open --search "created:>=${since_date}" --json number --jq '.[].number' || echo "")

if [[ -z "${issues}" ]]; then
    log "No new issues found"
    exit 0
fi

issue_count=$(echo "${issues}" | wc -l)
log "Found ${issue_count} new issues"

# Classify each issue
classified=0
failed=0

while read -r issue_number; do
    [[ -z "${issue_number}" ]] && continue

    log "Classifying issue #${issue_number}..."

    if "${SCRIPT_DIR}/classify-issue.sh" "${issue_number}" 2>/dev/null; then
        classified=$((classified + 1))
    else
        failed=$((failed + 1))
        log "Warning: Failed to classify issue #${issue_number}"
    fi

    # Sleep to avoid rate limiting
    sleep 1
done <<< "${issues}"

log "Classification complete!"
log "Classified: ${classified}"
log "Failed: ${failed}"

if [[ ${failed} -gt 0 ]]; then
    exit 1
fi
