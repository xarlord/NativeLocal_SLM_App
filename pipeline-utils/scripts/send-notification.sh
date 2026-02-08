#!/bin/bash
# send-notification.sh
# Send notifications to multiple channels (Slack, GitHub, Email)
# Tracks delivery status in notification_history table

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE_DIR="${PROJECT_ROOT}/pipeline-utils/templates"

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Notification channels (comma-separated)
CHANNELS="${NOTIFY_CHANNELS:-slack,github}"

# Channel-specific configuration
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPO="${CI_REPO:-}"
GITHUB_PR_NUMBER="${CI_PR_NUMBER:-}"

# Email configuration
SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
EMAIL_FROM="${EMAIL_FROM:-ci@example.com}"

# Build information from environment
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
BUILD_URL="${CI_BUILD_URL:-}"
LOGS_URL="${CI_BUILD_URL:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"
COMMIT_SHORT="${CI_COMMIT_SHA:0:8}"
COMMIT_MESSAGE="${CI_COMMIT_MESSAGE:-}"
BRANCH="${CI_BRANCH:-}"
AUTHOR="${CI_COMMIT_AUTHOR:-}"

# Project information
PROJECT_NAME="${CI_REPO_OWNER}/${CI_REPO_NAME}"

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

# Load notification data from database or file
load_notification_data() {
    local notification_id="${1:-}"
    local data_file="${2:-}"

    if [[ -n "${notification_id}" ]]; then
        # Load from database
        local query="
SELECT json_build_object(
  'notification_id', id,
  'title', title,
  'message', message,
  'metadata', metadata,
  'build_id', build_id
)
FROM notification_history
WHERE id = ${notification_id};
"
        query_db "${query}"
    elif [[ -n "${data_file}" && -f "${data_file}" ]]; then
        # Load from file
        cat "${data_file}"
    else
        error "No notification data source provided"
    fi
}

# Render template with variables
render_template() {
    local template_file="$1"
    local data="$2"

    # Load template
    local template
    template=$(cat "${template_file}")

    # Extract fields from data JSON
    local pattern_name severity category emoji title
    pattern_name=$(echo "${data}" | jq -r '.pattern_name // .metadata.pattern // "Unknown"')
    severity=$(echo "${data}" | jq -r '.severity // .metadata.severity // "medium"')
    category=$(echo "${data}" | jq -r '.category // .metadata.category // "unknown"')
    emoji=$(echo "${data}" | jq -r '.emoji // "⚠️"')
    title=$(echo "${data}" | jq -r '.title // .message // "Build Failed"')
    local error_message
    error_message=$(echo "${data}" | jq -r '.error_message // .metadata.error_message // "Unknown error"')
    local stack_trace
    stack_trace=$(echo "${data}" | jq -r '.stack_trace // .metadata.stack_trace // ""')
    local location
    location=$(echo "${data}" | jq -r '.location // .metadata.file_path // "Unknown"')
    local remediation
    remediation=$(echo "${data}" | jq -r '.remediation // .metadata.remediation // "No remediation available"')
    local auto_fixable
    auto_fixable=$(echo "${data}" | jq -r '.auto_fixable // .metadata.auto_fixable // "false"')
    local notification_id
    notification_id=$(echo "${data}" | jq -r '.notification_id // .id // ""')

    # Set emoji based on severity
    case "${severity}" in
        critical) emoji="🚨" ;;
        high) emoji="❌" ;;
        medium) emoji="⚠️" ;;
        low) emoji="ℹ️" ;;
    esac

    # Build owners list
    local owners_list owners_mentions
    owners_list=$(echo "${data}" | jq -r '.owners // [] | join(", ")')
    owners_mentions=$(echo "${data}" | jq -r '.owners // [] | map("@" + .) | join(" ")')

    # Set title if not provided
    if [[ "${title}" == "null" || -z "${title}" ]]; then
        title="${emoji} Build Failed - ${pattern_name}"
    fi

    # Replace template variables
    template=$(echo "${template}" | sed "s|{{EMOJI}}|${emoji}|g")
    template=$(echo "${template}" | sed "s|{{TITLE}}|${title}|g")
    template=$(echo "${template}" | sed "s|{{PATTERN_NAME}}|${pattern_name}|g")
    template=$(echo "${template}" | sed "s|{{SEVERITY}}|${severity}|g")
    template=$(echo "${template}" | sed "s|{{CATEGORY}}|${category}|g")
    template=$(echo "${template}" | sed "s|{{ERROR_MESSAGE}}|${error_message}|g")
    template=$(echo "${template}" | sed "s|{{STACK_TRACE}}|${stack_trace}|g")
    template=$(echo "${template}" | sed "s|{{LOCATION}}|${location}|g")
    template=$(echo "${template}" | sed "s|{{REMEDIATION}}|${remediation}|g")
    template=$(echo "${template}" | sed "s|{{AUTO_FIXABLE}}|${auto_fixable}|g")
    template=$(echo "${template}" | sed "s|{{BUILD_ID}}|${BUILD_ID}|g")
    template=$(echo "${template}" | sed "s|{{BUILD_URL}}|${BUILD_URL}|g")
    template=$(echo "${template}" | sed "s|{{LOGS_URL}}|${LOGS_URL}|g")
    template=$(echo "${template}" | sed "s|{{COMMIT_SHA}}|${COMMIT_SHA}|g")
    template=$(echo "${template}" | sed "s|{{COMMIT_SHORT}}|${COMMIT_SHORT}|g")
    template=$(echo "${template}" | sed "s|{{COMMIT_URL}}|https://github.com/${GITHUB_REPO}/commit/${COMMIT_SHA}|g")
    template=$(echo "${template}" | sed "s|{{BRANCH}}|${BRANCH}|g")
    template=$(echo "${template}" | sed "s|{{AUTHOR}}|${AUTHOR}|g")
    template=$(echo "${template}" | sed "s|{{COMMIT_MESSAGE}}|${COMMIT_MESSAGE}|g")
    template=$(echo "${template}" | sed "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g")
    template=$(echo "${template}" | sed "s|{{OWNERS_LIST}}|${owners_list}|g")
    template=$(echo "${template}" | sed "s|{{OWNERS_MENTIONS}}|${owners_mentions}|g")
    template=$(echo "${template}" | sed "s|{{NOTIFICATION_ID}}|${notification_id}|g")
    template=$(echo "${template}" | sed "s|{{TIMESTAMP}}|$(date -u +'%Y-%m-%d %H:%M:%S UTC')|g")
    template=$(echo "${template}" | sed "s|{{SEVERITY_BADGE}}|![](https://img.shields.io/badge/severity-${severity}-$(echo "${severity}" | sed 's/critical/red/g;s/high/orange/g;s/medium/yellow/g;s/low/green/g'))|g")

    # Handle conditional blocks
    if [[ "${auto_fixable}" != "true" ]]; then
        template=$(echo "${template}" | sed '/{% if AUTO_FIXABLE %}/,/{% endif %}/d')
    fi

    if [[ -z "${stack_trace}" ]]; then
        template=$(echo "${template}" | sed '/{% if STACK_TRACE %}/,/{% endif %}/d')
    fi

    echo "${template}"
}

# Send Slack notification
send_slack() {
    local message="$1"
    local webhook_url="${2:-${SLACK_WEBHOOK_URL}}"

    if [[ -z "${webhook_url}" ]]; then
        log "Slack webhook URL not configured, skipping Slack notification"
        return 1
    fi

    log "Sending Slack notification..."

    local response
    response=$(curl -s -X POST "${webhook_url}" \
        -H "Content-Type: application/json" \
        -d "${message}")

    if echo "${response}" | grep -q "ok"; then
        log "Slack notification sent successfully"
        return 0
    else
        log "Failed to send Slack notification: ${response}"
        return 1
    fi
}

# Send GitHub comment/issue
send_github() {
    local message="$1"
    local token="${2:-${GITHUB_TOKEN}}"
    local repo="${3:-${GITHUB_REPO}}"
    local pr_number="${4:-${GITHUB_PR_NUMBER}}"

    if [[ -z "${token}" || -z "${repo}" ]]; then
        log "GitHub token or repo not configured, skipping GitHub notification"
        return 1
    fi

    log "Sending GitHub notification..."

    # Extract comment body from JSON
    local comment_body
    comment_body=$(echo "${message}" | jq -r '.body')

    if [[ -z "${comment_body}" ]]; then
        comment_body="${message}"
    fi

    local response
    if [[ -n "${pr_number}" ]]; then
        # Post as PR comment
        response=$(curl -s -X POST \
            -H "Authorization: Bearer ${token}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${repo}/issues/${pr_number}/comments" \
            -d "{\"body\": $(echo "${comment_body}" | jq -Rs .)}")
    else
        # Create an issue
        local title
        title=$(echo "${comment_body}" | head -1 | sed 's/^#+ //')

        response=$(curl -s -X POST \
            -H "Authorization: Bearer ${token}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${repo}/issues" \
            -d "{\"title\": \"${title}\", \"body\": $(echo "${comment_body}" | jq -Rs .), \"labels\": [\"ci-failure\", \"automated\"]}")
    fi

    if echo "${response}" | jq -e '.id' >/dev/null; then
        log "GitHub notification sent successfully"
        echo "${response}" | jq -r '.html_url'
        return 0
    else
        log "Failed to send GitHub notification: ${response}"
        return 1
    fi
}

# Send email notification
send_email() {
    local message="$1"
    local recipients="${2:-}"

    if [[ -z "${recipients}" ]]; then
        log "No email recipients provided, skipping email notification"
        return 1
    fi

    if ! command -v sendmail &>/dev/null; then
        log "sendmail not available, skipping email notification"
        return 1
    fi

    log "Sending email notification to: ${recipients}"

    # Parse message (subject and body)
    local subject body
    subject=$(echo "${message}" | grep "^Subject:" | cut -d':' -f2- | sed 's/^ *//')
    body=$(echo "${message}" | sed '/^Subject:/d')

    # Send email using sendmail
    echo "${body}" | /usr/sbin/sendmail -t -i 2>/dev/null || {
        log "Failed to send email notification"
        return 1
    }

    log "Email notification sent successfully"
    return 0
}

# Update notification delivery status in database
update_delivery_status() {
    local notification_id="$1"
    local channel="$2"
    local status="$3"
    local error_msg="${4:-}"

    log "Updating delivery status: ${channel} -> ${status}"

    local error_sanitized
    error_sanitized=$(echo "${error_msg}" | sed "s/'/''/g")

    local query="
UPDATE notification_history
SET
    channel = '${channel}',
    sent = ${status},
    sent_at = CASE WHEN ${status} THEN NOW() ELSE sent_at END,
    delivery_status = '${status}',
    error_message = '${error_sanitized}'
WHERE id = ${notification_id};
"

    query_db "${query}" >/dev/null
}

# ============================================
# Main Execution
# ============================================

main() {
    local notification_id="${1:-}"
    local data_file="${2:-}"

    log "Starting notification sender..."
    log "Channels: ${CHANNELS}"

    # Load notification data
    local notification_data
    notification_data=$(load_notification_data "${notification_id}" "${data_file}")

    if [[ -z "${notification_data}" ]]; then
        error "Failed to load notification data"
    fi

    # Extract notification ID
    if [[ -z "${notification_id}" ]]; then
        notification_id=$(echo "${notification_data}" | jq -r '.notification_id // .id // ""')
    fi

    log "Notification ID: ${notification_id}"

    # Detect code owners
    local owners_data
    if [[ -f "${SCRIPT_DIR}/detect-owners.sh" ]]; then
        log "Detecting code owners..."
        owners_data=$("${SCRIPT_DIR}/detect-owners.sh" /tmp/owners.json)
    else
        log "Warning: detect-owners.sh not found"
        owners_data="[]"
    fi

    # Merge owners data
    notification_data=$(echo "${notification_data}" | jq --argjson owners "${owners_data}" '.owners = $owners')

    # Send to each channel
    IFS=',' read -ra channels <<< "${CHANNELS}"
    local success_count=0
    local fail_count=0

    for channel in "${channels[@]}"; do
        channel=$(echo "${channel}" | tr -d ' ')
        log "Processing channel: ${channel}"

        case "${channel}" in
            slack)
                local template_file="${TEMPLATE_DIR}/slack-failure.json"
                if [[ -f "${template_file}" ]]; then
                    local rendered
                    rendered=$(render_template "${template_file}" "${notification_data}")
                    if send_slack "${rendered}"; then
                        update_delivery_status "${notification_id}" "slack" "true"
                        ((success_count++))
                    else
                        update_delivery_status "${notification_id}" "slack" "false" "Failed to send"
                        ((fail_count++))
                    fi
                else
                    log "Template not found: ${template_file}"
                    ((fail_count++))
                fi
                ;;

            github)
                local template_file="${TEMPLATE_DIR}/github-comment.json"
                if [[ -f "${template_file}" ]]; then
                    local rendered
                    rendered=$(render_template "${template_file}" "${notification_data}")
                    if send_github "${rendered}"; then
                        update_delivery_status "${notification_id}" "github" "true"
                        ((success_count++))
                    else
                        update_delivery_status "${notification_id}" "github" "false" "Failed to send"
                        ((fail_count++))
                    fi
                else
                    log "Template not found: ${template_file}"
                    ((fail_count++))
                fi
                ;;

            email)
                local template_file="${TEMPLATE_DIR}/email-template.md"
                if [[ -f "${template_file}" ]]; then
                    local rendered
                    rendered=$(render_template "${template_file}" "${notification_data}")

                    # Extract recipients from owners
                    local recipients
                    recipients=$(echo "${notification_data}" | jq -r '.owners // [] | map(.github_username + "@github.com") | join(",")')

                    if send_email "${rendered}" "${recipients}"; then
                        update_delivery_status "${notification_id}" "email" "true"
                        ((success_count++))
                    else
                        update_delivery_status "${notification_id}" "email" "false" "Failed to send"
                        ((fail_count++))
                    fi
                else
                    log "Template not found: ${template_file}"
                    ((fail_count++))
                fi
                ;;

            *)
                log "Unknown channel: ${channel}"
                ((fail_count++))
                ;;
        esac
    done

    # Summary
    log "Notification delivery complete!"
    log "Successful: ${success_count}"
    log "Failed: ${fail_count}"

    if [[ ${fail_count} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
