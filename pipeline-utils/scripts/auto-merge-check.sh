#!/bin/bash
# auto-merge-check.sh
# Check if PR is auto-mergeable
# Usage: ./auto-merge-check.sh <pr-number>
# Returns exit code 0 if auto-mergeable, 1 otherwise
# Logs check results to database

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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

# Merge requirements
REQUIRED_APPROVALS="${REQUIRED_APPROVALS:-1}"
REQUIRED_STATUS_CHECKS="${REQUIRED_STATUS_CHECKS:-}"
ALLOW_STALE_REVIEW="${ALLOW_STALE_REVIEW:-false}"
MAX_CONVERSATION_AGE_DAYS="${MAX_CONVERSATION_AGE_DAYS:-7}"
MIN_PR_AGE_SECONDS="${MIN_PR_AGE_SECONDS:-3600}"  # Minimum 1 hour before auto-merge

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

# Get PR details
get_pr_details() {
    local pr_number="$1"

    gh pr view "${pr_number}" --json title,state,mergeable,mergeStateStatus,headRefName,baseRefName,reviewDecision,commits 2>/dev/null
}

# Check if all status checks are passing
check_status_checks() {
    local pr_number="$1"

    log "Checking status checks..."

    # Get all check runs and status statuses
    local checks_json
    checks_json=$(gh pr view "${pr_number}" --json statusCheckRollup --jq '.statusCheckRollup[] | {name: .name, status: .status, conclusion: .conclusion}' 2>/dev/null || echo "[]")

    if [[ "${checks_json}" == "[]" ]]; then
        log "No status checks found"
        return 0
    fi

    local failed_checks=0
    local pending_checks=0
    local total_checks=0

    echo "${checks_json}" | jq -c '.[]' | while read -r check; do
        local name
        local status
        local conclusion
        name=$(echo "${check}" | jq -r '.name')
        status=$(echo "${check}" | jq -r '.status')
        conclusion=$(echo "${check}" | jq -r '.conclusion // empty')

        ((total_checks++)) || true

        case "${status}" in
            COMPLETED)
                if [[ "${conclusion}" != "success" ]] && [[ "${conclusion}" != "neutral" ]]; then
                    log "  ✗ ${name}: ${conclusion}"
                    ((failed_checks++)) || true
                else
                    log "  ✓ ${name}: ${conclusion}"
                fi
                ;;
            PENDING|QUEUED|IN_PROGRESS)
                log "  ⏳ ${name}: ${status}"
                ((pending_checks++)) || true
                ;;
            *)
                log "  ? ${name}: ${status}"
                ;;
        esac
    done

    if [[ ${failed_checks} -gt 0 ]]; then
        log "Status check failed: ${failed_checks} check(s) failed"
        return 1
    fi

    if [[ ${pending_checks} -gt 0 ]]; then
        log "Status check pending: ${pending_checks} check(s) still running"
        return 1
    fi

    log "All status checks passing (${total_checks} checks)"
    return 0
}

# Check if required status checks are present (if specified)
check_required_checks() {
    local pr_number="$1"

    if [[ -z "${REQUIRED_STATUS_CHECKS}" ]]; then
        return 0
    fi

    log "Checking required status checks..."

    IFS=',' read -ra required_checks <<< "${REQUIRED_STATUS_CHECKS}"

    local checks_json
    checks_json=$(gh pr view "${pr_number}" --json statusCheckRollup --jq '.statusCheckRollup[].name' 2>/dev/null || echo "[]")

    for required_check in "${required_checks[@]}"; do
        required_check=$(echo "${required_check}" | xargs) # trim whitespace

        if ! echo "${checks_json}" | grep -q "\"${required_check}\""; then
            log "Required check missing: ${required_check}"
            return 1
        fi
    done

    log "All required checks present"
    return 0
}

# Check if PR has required approvals
check_approvals() {
    local pr_number="$1"

    log "Checking approvals (required: ${REQUIRED_APPROVALS})..."

    local approval_count
    approval_count=$(gh pr view "${pr_number}" --json reviews -q '[.reviews[] | select(.state == "APPROVED")] | length' 2>/dev/null || echo "0")

    log "Current approvals: ${approval_count}"

    if [[ "${approval_count}" -lt "${REQUIRED_APPROVALS}" ]]; then
        log "Insufficient approvals (${approval_count}/${REQUIRED_APPROVALS})"
        return 1
    fi

    log "Required approvals met (${approval_count}/${REQUIRED_APPROVALS})"
    return 0
}

# Check if reviews are stale
check_review_staleness() {
    local pr_number="$1"

    if [[ "${ALLOW_STALE_REVIEW}" == "true" ]]; then
        log "Stale reviews allowed"
        return 0
    fi

    log "Checking review staleness..."

    # Get latest approved review date
    local latest_approval
    latest_approval=$(gh api "repos/:owner/:repo/pulls/${pr_number}/reviews" --jq '[.[] | select(.state == "APPROVED") | .submitted_at] | max' 2>/dev/null || echo "")

    if [[ -z "${latest_approval}" ]]; then
        log "No approvals found"
        return 1
    fi

    # Calculate age in days
    local approval_epoch
    local current_epoch
    approval_epoch=$(date -d "${latest_approval}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${latest_approval}" +%s 2>/dev/null || echo "0")
    current_epoch=$(date +%s)
    local age_days=$(( (current_epoch - approval_epoch) / 86400 ))

    if [[ ${age_days} -gt ${MAX_CONVERSATION_AGE_DAYS} ]]; then
        log "Review is stale (${age_days} days old, max ${MAX_CONVERSATION_AGE_DAYS} days)"
        return 1
    fi

    log "Review is fresh (${age_days} days old)"
    return 0
}

# Check for unresolved conversations
check_conversations() {
    local pr_number="$1"

    log "Checking for unresolved conversations..."

    local comments_json
    comments_json=$(gh pr view "${pr_number}" --json comments,reviews --jq '
        {
            comments: [.comments[] | select(.authorAssociation != "OWNER") | {author: .author.login, body: .body}],
            review_comments: [.reviews[] | .comments[]? | select(.authorAssociation != "OWNER") | {author: .author.login, body: .body}]
        }
    ' 2>/dev/null || echo '{}')

    local unresolved_count=0

    # Check for unresolved comments (simplified check)
    local has_comments
    has_comments=$(echo "${comments_json}" | jq '.comments | length' 2>/dev/null || echo "0")

    if [[ "${has_comments}" -gt 0 ]]; then
        log "Warning: PR has ${has_comments} comment(s)"
        # In a real implementation, you'd check if these are resolved
        # For now, we'll warn but not fail
    fi

    log "Conversation check complete"
    return 0
}

# Check if PR is up to date with target branch
check_up_to_date() {
    local pr_number="$1"

    log "Checking if PR is up to date..."

    local mergeable_status
    mergeable_status=$(gh pr view "${pr_number}" --json mergeable --jq '.mergeable' 2>/dev/null || echo "UNKNOWN")

    case "${mergeable_status}" in
        MERGEABLE)
            log "PR is up to date and mergeable"
            return 0
            ;;
        CONFLICTING)
            log "PR has merge conflicts"
            return 1
            ;;
        UNKNOWN)
            log "Merge status unknown (GitHub is computing)"
            return 1
            ;;
        *)
            log "Unknown merge status: ${mergeable_status}"
            return 1
            ;;
    esac
}

# Check if branch is behind target
check_branch_behind() {
    local pr_number="$1"

    log "Checking if branch is behind target..."

    local behind_by
    behind_by=$(gh pr view "${pr_number}" --json mergeStateStatus --jq '.mergeStateStatus' 2>/dev/null || echo "UNKNOWN")

    case "${behind_by}" in
        BEHIND)
            log "Branch is behind target branch"
            return 1
            ;;
        BLOCKED)
            log "Branch merge is blocked"
            return 1
            ;;
        DIRTY)
            log "Branch has merge conflicts"
            return 1
            ;;
        CLEAN)
            log "Branch is up to date"
            return 0
            ;;
        *)
            log "Merge state: ${behind_by}"
            return 0
            ;;
    esac
}

# Check if PR is old enough for auto-merge
check_pr_age() {
    local pr_number="$1"

    log "Checking PR age (minimum: ${MIN_PR_AGE_SECONDS}s)..."

    # Get PR creation time
    local pr_created_at
    pr_created_at=$(gh pr view "${pr_number}" --json createdAt --jq '.createdAt' 2>/dev/null || echo "")

    if [[ -z "${pr_created_at}" ]]; then
        log "Warning: Could not determine PR creation time"
        return 1
    fi

    # Calculate age in seconds
    local pr_timestamp
    local current_timestamp
    local age_seconds

    # Try GNU date first, then BSD date
    pr_timestamp=$(date -d "${pr_created_at}" +%s 2>/dev/null) || \
    pr_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${pr_created_at}" +%s 2>/dev/null) || \
    {
        log "Error: Cannot parse PR creation time"
        return 1
    }

    current_timestamp=$(date +%s)
    age_seconds=$((current_timestamp - pr_timestamp))

    local age_minutes=$((age_seconds / 60))
    local age_hours=$((age_minutes / 60))

    log "PR age: ${age_hours}h ${age_minutes}m (${age_seconds}s)"

    if [[ ${age_seconds} -lt ${MIN_PR_AGE_SECONDS} ]]; then
        local min_age_minutes=$((MIN_PR_AGE_SECONDS / 60))
        log "PR is too new for auto-merge (${age_minutes}m old, need ${min_age_minutes}m)"
        return 1
    fi

    log "PR is old enough for auto-merge"
    return 0
}

# Log check result to database
log_to_database() {
    local pr_number="$1"
    local check_result="$2"
    local failure_reason="$3"

    log "Logging check result to database..."

    local sanitized_reason
    sanitized_reason=$(echo "${failure_reason}" | sed "s/'/''/g")

    local query="
UPDATE automated_prs
SET
    auto_mergeable = ${check_result},
    checks_passed = ${check_result},
    updated_at = NOW()
WHERE pr_number = ${pr_number};
"

    query_db "${query}" >/dev/null

    # Also create a check history record
    local history_query="
INSERT INTO build_metrics (
    commit_sha,
    branch,
    success,
    timestamp,
    created_at
) VALUES (
    'pr-${pr_number}',
    'auto-merge-check',
    ${check_result},
    NOW(),
    NOW()
);
"

    query_db "${history_query}" >/dev/null
}

# ============================================
# Main Execution
# ============================================

main() {
    local pr_number="$1"

    log "=== Auto-Merge Check Script ==="
    log "PR Number: ${pr_number}"

    # Check prerequisites
    check_gh_cli

    # Get PR details
    local pr_details
    pr_details=$(get_pr_details "${pr_number}")

    if [[ -z "${pr_details}" ]]; then
        error "Cannot fetch PR details"
    fi

    local pr_state
    pr_state=$(echo "${pr_details}" | jq -r '.state')

    if [[ "${pr_state}" != "OPEN" ]]; then
        log "PR is not open (state: ${pr_state})"
        log_to_database "${pr_number}" "false" "PR not open"
        exit 1
    fi

    # Run all checks
    local all_passed=true
    local failure_reason=""

    # Check 0: PR age (must be old enough)
    if ! check_pr_age "${pr_number}"; then
        all_passed=false
        failure_reason="PR too new for auto-merge"
    fi

    # Check 1: Up to date
    if ! check_up_to_date "${pr_number}"; then
        all_passed=false
        failure_reason="PR not up to date or has conflicts"
    fi

    # Check 2: Branch behind
    if ! check_branch_behind "${pr_number}"; then
        all_passed=false
        failure_reason="Branch behind target branch"
    fi

    # Check 3: Status checks
    if ! check_status_checks "${pr_number}"; then
        all_passed=false
        failure_reason="Status checks not passing"
    fi

    # Check 4: Required checks
    if ! check_required_checks "${pr_number}"; then
        all_passed=false
        failure_reason="Required status checks missing"
    fi

    # Check 5: Approvals
    if ! check_approvals "${pr_number}"; then
        all_passed=false
        failure_reason="Insufficient approvals"
    fi

    # Check 6: Review staleness
    if ! check_review_staleness "${pr_number}"; then
        all_passed=false
        failure_reason="Stale review"
    fi

    # Check 7: Conversations
    if ! check_conversations "${pr_number}"; then
        # Conversations don't fail the check, just warn
        log "Note: PR has unresolved conversations"
    fi

    # Log result
    if [[ "${all_passed}" == "true" ]]; then
        log "=== Auto-Merge Check: PASSED ==="
        log_to_database "${pr_number}" "true" ""
        exit 0
    else
        log "=== Auto-Merge Check: FAILED ==="
        log "Reason: ${failure_reason}"
        log_to_database "${pr_number}" "false" "${failure_reason}"
        exit 1
    fi
}

# Show usage
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <pr-number>"
    echo ""
    echo "Arguments:"
    echo "  pr-number  GitHub PR number to check"
    echo ""
    echo "The script checks:"
    echo "  ✓ All status checks passing"
    echo "  ✓ Required status checks present (if configured)"
    echo "  ✓ Required approvals granted"
    echo "  ✓ Reviews not stale"
    echo "  ✓ PR is up to date with target branch"
    echo "  ✓ No merge conflicts"
    echo "  ✓ No unresolved conversations (warning only)"
    echo ""
    echo "Exit codes:"
    echo "  0 - All checks passed (auto-mergeable)"
    echo "  1 - One or more checks failed"
    echo ""
    echo "Environment variables:"
    echo "  REQUIRED_APPROVALS         Minimum required approvals (default: 1)"
    echo "  REQUIRED_STATUS_CHECKS     Comma-separated list of required checks"
    echo "  ALLOW_STALE_REVIEW         Allow stale reviews (default: false)"
    echo "  MAX_CONVERSATION_AGE_DAYS  Max review age in days (default: 7)"
    echo ""
    echo "Examples:"
    echo "  $0 123"
    echo "  REQUIRED_APPROVALS=2 $0 123"
    echo "  REQUIRED_STATUS_CHECKS=ci/test,ci/build $0 123"
    exit 1
fi

# Run main function
main "$@"
