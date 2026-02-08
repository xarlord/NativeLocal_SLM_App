#!/bin/bash
# generate-issue-report.sh
# Weekly issue triage report
# Generate summary of new, closed, and stale issues
# Output as markdown or HTML
# Usage: ./generate-issue-report.sh [--format markdown|html] [--output file]

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
TEMPLATE_DIR="${PROJECT_ROOT}/pipeline-utils/templates"

# Report settings
REPORT_FORMAT="${REPORT_FORMAT:-markdown}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/issue-report-$(date +%Y%m%d).md}"
REPORT_DAYS="${REPORT_DAYS:-7}"  # Last 7 days

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

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

# Check if jq is available
has_jq() {
    command -v jq >/dev/null 2>&1
}

# Get array length with jq fallback
json_array_length() {
    local json="$1"

    if has_jq; then
        echo "${json}" | jq 'length' 2>/dev/null || echo "0"
    else
        # Count array elements by counting commas + 1
        echo "${json}" | grep -o ',' | wc -l | awk '{print $1 + 1}'
    fi
}

# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    if has_jq; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
    else
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    if [[ ${remaining} -lt 100 ]]; then
        log "WARNING: GitHub API rate limit low: ${remaining} remaining"
        sleep 10
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                REPORT_FORMAT="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --days)
                REPORT_DAYS="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Get GitHub repo
get_github_repo() {
    git remote get-url origin 2>/dev/null | sed 's|\.git$||' || echo "unknown/repo"
}

# Get new issues this week
get_new_issues() {
    local days="$1"

    log "Fetching new issues from last ${days} days..."

    local since_date
    since_date=$(date -d "${days} days ago" +%Y-%m-%d)

    gh issue list --limit 100 --state open --search "created:>=${since_date}" --json number,title,author,labels,createdAt --jq '.[]' 2>/dev/null || echo "[]"
}

# Get closed issues this week
get_closed_issues() {
    local days="$1"

    log "Fetching closed issues from last ${days} days..."

    local since_date
    since_date=$(date -d "${days} days ago" +%Y-%m-%d)

    gh issue list --limit 100 --state closed --search "closed:>=${since_date}" --json number,title,author,labels,closedAt --jq '.[]' 2>/dev/null || echo "[]"
}

# Get issues by label
get_issues_by_label() {
    local label="$1"
    local limit="${2:-10}"

    gh issue list --limit "${limit}" --state open --search "label:\"${label}\"" --json number,title,labels --jq '.[]' 2>/dev/null || echo "[]"
}

# Get unassigned issues
get_unassigned_issues() {
    local limit="${1:-20}"

    log "Fetching unassigned issues..."

    gh issue list --limit "${limit}" --state open --search "no:assignee" --json number,title,labels,createdAt --jq '.[]' 2>/dev/null || echo "[]"
}

# Get stale issues (no activity > 7 days)
get_stale_issues() {
    local days="${1:-7}"

    log "Fetching stale issues (no activity > ${days} days)..."

    local since_date
    since_date=$(date -d "${days} days ago" +%Y-%m-%d)

    gh issue list --limit 100 --state open --search "updated:<${since_date}" --json number,title,labels,updatedAt --jq '.[]' 2>/dev/null || echo "[]"
}

# Get duplicate detection results from database
get_duplicate_stats() {
    log "Fetching duplicate detection stats..."

    local query="
SELECT
    COUNT(*) as total_duplicates,
    AVG(similarity_score) as avg_similarity,
    MAX(detected_at) as last_detected
FROM issue_duplicates
WHERE detected_at > NOW() - INTERVAL '7 days';
"

    query_db "${query}"
}

# Get complexity distribution
get_complexity_distribution() {
    log "Fetching complexity distribution..."

    local query="
SELECT
    complexity_score,
    COUNT(*) as count
FROM issue_complexity
WHERE estimated_at > NOW() - INTERVAL '30 days'
GROUP BY complexity_score
ORDER BY complexity_score;
"

    query_db "${query}"
}

# Generate markdown report
generate_markdown_report() {
    local new_issues="$1"
    local closed_issues="$2"
    local unassigned_issues="$3"
    local stale_issues="$4"
    local duplicate_stats="$5"
    local complexity_dist="$6"

    local repo_name
    repo_name=$(get_github_repo)

    local report_date
    report_date=$(date +'%Y-%m-%d')

    local report_start
    report_start=$(date -d "${REPORT_DAYS} days ago" +%Y-%m-%d)

    cat <<EOF
# Weekly Issue Triage Report

**Repository:** ${repo_name}
**Report Period:** ${report_start} to ${report_date}
**Generated:** $(date +'%Y-%m-%d %H:%M:%S UTC')

---

## Summary

EOF

    # Count statistics
    local new_count
    local closed_count
    local unassigned_count
    local stale_count

    new_count=$(json_array_length "${new_issues}")
    closed_count=$(json_array_length "${closed_issues}")
    unassigned_count=$(json_array_length "${unassigned_issues}")
    stale_count=$(json_array_length "${stale_issues}")

    cat <<EOF
| Metric | Count |
|--------|-------|
| New Issues | ${new_count} |
| Closed Issues | ${closed_count} |
| Unassigned Issues | ${unassigned_count} |
| Stale Issues (${REPORT_DAYS}+ days) | ${stale_count} |

---

## New Issues This Week

EOF

    if [[ ${new_count} -gt 0 ]]; then
        echo "${new_issues}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number)) - @\(.author.login)"' | head -20
    else
        echo "No new issues this week."
    fi

    cat <<EOF

---

## Closed Issues This Week

EOF

    if [[ ${closed_count} -gt 0 ]]; then
        echo "${closed_issues}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number)) - @\(.author.login)"' | head -20
    else
        echo "No issues closed this week."
    fi

    cat <<EOF

---

## Issues by Label

### Bug Reports
EOF

    local bugs
    bugs=$(get_issues_by_label "bug" 10)
    local bug_count
    bug_count=$(echo "${bugs}" | jq 'length')

    if [[ ${bug_count} -gt 0 ]]; then
        echo "${bugs}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number))"' | head -10
    else
        echo "No open bugs."
    fi

    cat <<EOF

### Feature Requests
EOF

    local features
    features=$(get_issues_by_label "feature" 10)
    local feature_count
    feature_count=$(echo "${features}" | jq 'length')

    if [[ ${feature_count} -gt 0 ]]; then
        echo "${features}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number))"' | head -10
    else
        echo "No open feature requests."
    fi

    cat <<EOF

---

## Unassigned Issues

Top ${unassigned_count} issues needing assignment:

EOF

    if [[ ${unassigned_count} -gt 0 ]]; then
        echo "${unassigned_issues}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number)) - Created \(.createdAt)"' | head -15
    else
        echo "All issues are assigned!"
    fi

    cat <<EOF

---

## Stale Issues

Issues with no activity in the past ${REPORT_DAYS} days:

EOF

    if [[ ${stale_count} -gt 0 ]]; then
        echo "${stale_issues}" | jq -r '"- [\(#\(.number)) \(.title)](https://github.com/'"${repo_name}"'/issues/\(.number)) - Updated \(.updatedAt)"' | head -15
    else
        echo "No stale issues. Great job keeping issues active!"
    fi

    cat <<EOF

---

## Duplicate Detection Results

EOF

    if [[ -n "${duplicate_stats}" ]]; then
        IFS='|' read -r total_dups avg_sim last_det <<< "${duplicate_stats}"

        if [[ -n "${total_dups}" && "${total_dups}" != "0" ]]; then
            cat <<EOF
| Metric | Value |
|--------|-------|
| Total Duplicates Found | ${total_dups:-0} |
| Average Similarity Score | ${avg_sim:-N/A} |
| Last Detection | ${last_det:-N/A} |

EOF
        else
            echo "No duplicate detections this week."
        fi
    else
        echo "No duplicate data available."
    fi

    cat <<EOF

---

## Complexity Distribution

Based on recent complexity estimates:

EOF

    if [[ -n "${complexity_dist}" ]]; then
        echo "| Complexity (1-5) | Count |"
        echo "|------------------|-------|"

        echo "${complexity_dist}" | while IFS='|' read -r score count; do
            [[ -z "${score}" ]] && continue
            echo "| ${score} | ${count} |"
        done
    else
        echo "No complexity data available."
    fi

    cat <<EOF

---

## Recommendations

EOF

    # Generate recommendations based on data
    if [[ ${unassigned_count} -gt 10 ]]; then
        echo "- ⚠️  **High unassigned count**: Consider running auto-assignment script"
    fi

    if [[ ${stale_count} -gt 20 ]]; then
        echo "- ⚠️  **Many stale issues**: Review and update old issues or close stale ones"
    fi

    if [[ ${bug_count} -gt 15 ]]; then
        echo "- ⚠️  **High bug count**: Consider focusing on bug fixes before new features"
    fi

    if [[ ${new_count} -gt ${closed_count} ]]; then
        local backlog_growth=$((new_count - closed_count))
        echo "- 📈 **Backlog growing**: ${backlog_growth} more issues opened than closed"
    fi

    cat <<EOF

---

*This report was automatically generated by the issue triage automation system*
EOF
}

# Send notification with report
send_report_notification() {
    local report_file="$1"

    log "Sending report notification..."

    if [[ -f "${SCRIPT_DIR}/send-notification.sh" ]]; then
        # Create notification data
        local notification_data
        notification_data=$(cat <<EOF
{
  "title": "Weekly Issue Triage Report",
  "message": "Issue triage report for $(date +'%Y-%m-%d')",
  "category": "issue-triage",
  "severity": "low",
  "emoji": "📊"
}
EOF
)

        # Save to temp file
        echo "${notification_data}" > /tmp/notification.json

        # Send notification
        "${SCRIPT_DIR}/send-notification.sh" "" /tmp/notification.json 2>/dev/null || {
            log "Warning: Failed to send notification"
        }

        rm -f /tmp/notification.json
    else
        log "send-notification.sh not found, skipping notification"
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    # Parse arguments
    parse_args "$@"

    log "Generating weekly issue triage report..."
    log "Format: ${REPORT_FORMAT}"
    log "Report period: Last ${REPORT_DAYS} days"

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI (gh) is not installed or not in PATH"
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
    fi

    # Gather data
    log "Gathering issue data..."

    local new_issues
    local closed_issues
    local unassigned_issues
    local stale_issues
    local duplicate_stats
    local complexity_dist

    new_issues=$(get_new_issues "${REPORT_DAYS}")
    closed_issues=$(get_closed_issues "${REPORT_DAYS}")
    unassigned_issues=$(get_unassigned_issues)
    stale_issues=$(get_stale_issues "${REPORT_DAYS}")
    duplicate_stats=$(get_duplicate_stats)
    complexity_dist=$(get_complexity_distribution)

    # Generate report
    log "Generating report..."

    if [[ "${REPORT_FORMAT}" == "markdown" ]]; then
        generate_markdown_report \
            "${new_issues}" \
            "${closed_issues}" \
            "${unassigned_issues}" \
            "${stale_issues}" \
            "${duplicate_stats}" \
            "${complexity_dist}" > "${OUTPUT_FILE}"
    else
        error "HTML format not yet implemented. Use markdown format."
    fi

    log "Report saved to: ${OUTPUT_FILE}"

    # Send notification
    send_report_notification "${OUTPUT_FILE}"

    log "Report generation complete!"

    # Output to stdout
    cat "${OUTPUT_FILE}"
}

# Run main function
main "$@"
