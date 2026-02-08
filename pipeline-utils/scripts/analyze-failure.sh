#!/bin/bash
# analyze-failure.sh
# Analyze build failures and generate detailed notification data
# Stores results in notification_history table

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/pipeline-utils/config"
FAILURE_PATTERNS="${CONFIG_DIR}/failure-patterns.yaml"

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpeeker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Build information from environment
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"
COMMIT_MESSAGE="${CI_COMMIT_MESSAGE:-}"
BRANCH="${CI_BRANCH:-}"
PIPELINE_ID="${CI_PIPELINE_NUMBER:-}"

# Log file to analyze
LOG_FILE="${1:-/tmp/build.log}"
OUTPUT_FILE="${2:-/tmp/failure-analysis.json}"

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

# Extract error message from log
extract_error_message() {
    local log_file="$1"
    local error_msg=""

    # Try to find the most relevant error message
    # Look for common error patterns
    error_msg=$(grep -E "error:|Error:|ERROR:|Exception|Failed|failed" "${log_file}" | tail -1)

    # If no error found, get last 50 lines
    if [[ -z "${error_msg}" ]]; then
        error_msg=$(tail -50 "${log_file}" | head -20)
    fi

    echo "${error_msg}"
}

# Extract stack trace from log
extract_stack_trace() {
    local log_file="$1"
    local stack_trace=""

    # Look for Java/Kotlin stack traces
    stack_trace=$(sed -n '/Exception/,/^$/p' "${log_file}" | head -30)

    # If no stack trace found, look for Python tracebacks
    if [[ -z "${stack_trace}" ]]; then
        stack_trace=$(sed -n '/Traceback/,/^$/p' "${log_file}")
    fi

    echo "${stack_trace}"
}

# Extract file path and line number from error
extract_location() {
    local log_file="$1"
    local location=""

    # Look for file:line patterns (common in compilation errors)
    location=$(grep -oE '[a-zA-Z_][a-zA-Z0-9_./]*\.[a-z]+:[0-9]+' "${log_file}" | head -1)

    # Look for Kotlin/Java patterns
    if [[ -z "${location}" ]]; then
        location=$(grep -oE 'at [a-zA-Z0-9_.]+\(.*\.kt:[0-9]+\)|at [a-zA-Z0-9_.]+\(.*\.java:[0-9]+\)' "${log_file}" | head -1)
    fi

    echo "${location}"
}

# Classify failure using pattern database
classify_failure() {
    local error_msg="$1"
    local pattern_name=""
    local severity=""
    local category=""
    local remediation=""
    local auto_fixable="false"

    # Check if failure-patterns.yaml exists
    if [[ ! -f "${FAILURE_PATTERNS}" ]]; then
        log "Warning: ${FAILURE_PATTERNS} not found, using basic classification"

        # Basic classification
        if echo "${error_msg}" | grep -iqE "outofmemory|oom"; then
            pattern_name="OutOfMemoryError"
            severity="high"
            category="infrastructure"
            auto_fixable="true"
        elif echo "${error_msg}" | grep -iqE "timeout|connection"; then
            pattern_name="NetworkTimeout"
            severity="medium"
            category="infrastructure"
            auto_fixable="true"
        elif echo "${error_msg}" | grep -iqE "test.*failed|assertion"; then
            pattern_name="TestFailure"
            severity="medium"
            category="tests"
            auto_fixable="false"
        elif echo "${error_msg}" | grep -iqE "could not resolve|dependency"; then
            pattern_name="DependencyResolutionFailed"
            severity="medium"
            category="dependencies"
            auto_fixable="true"
        else
            pattern_name="UnknownFailure"
            severity="medium"
            category="unknown"
            auto_fixable="false"
        fi
    else
        # Parse YAML and match patterns
        # This is a simplified implementation
        while IFS= read -r line; do
            if echo "${error_msg}" | grep -qE "$(echo "${line}" | cut -d'|' -f3)"; then
                pattern_name="$(echo "${line}" | cut -d'|' -f1)"
                severity="$(echo "${line}" | cut -d'|' -f2)"
                category="$(echo "${line}" | cut -d'|' -f4)"
                auto_fixable="$(echo "${line}" | cut -d'|' -f5)"
                remediation="$(echo "${line}" | cut -d'|' -f6-)"
                break
            fi
        done < <(grep -E '^  - name:' "${FAILURE_PATTERNS}" -A 10 | \
                 paste -d'|' - - - - - - - - - - | \
                 sed 's/  - name: //; s/severity: "//; s/|  category: "/|/; s/|  regex: "/|/; s/|  auto_fixable: /|/; s/|  remediation: |/|/')

        # Default if no match found
        if [[ -z "${pattern_name}" ]]; then
            pattern_name="UnknownFailure"
            severity="medium"
            category="unknown"
            auto_fixable="false"
        fi
    fi

    echo "${pattern_name}|${severity}|${category}|${auto_fixable}|${remediation}"
}

# Generate actionable notification message
generate_notification() {
    local pattern_name="$1"
    local severity="$2"
    local category="$3"
    local error_msg="$4"
    local stack_trace="$5"
    local location="$6"
    local remediation="$7"

    local emoji=""
    local title=""

    case "${severity}" in
        critical)
            emoji="🚨"
            title="CRITICAL FAILURE"
            ;;
        high)
            emoji="❌"
            title="Build Failed"
            ;;
        medium)
            emoji="⚠️"
            title="Build Warning"
            ;;
        low)
            emoji="ℹ️"
            title="Build Notice"
            ;;
        *)
            emoji="❓"
            title="Build Status"
            ;;
    esac

    cat <<EOF
${emoji} ${title}

**Pattern:** ${pattern_name}
**Severity:** ${severity}
**Category:** ${category}

**Error:**
\`\`\`
${error_msg}
\`\`\`

EOF

    # Add location if available
    if [[ -n "${location}" ]]; then
        echo "**Location:** ${location}"
        echo ""
    fi

    # Add stack trace if available (truncate if too long)
    if [[ -n "${stack_trace}" ]]; then
        if [[ ${#stack_trace} -gt 1000 ]]; then
            echo "**Stack Trace:**"
            echo "\`\`\`"
            echo "${stack_trace}" | head -50
            echo "... (truncated)"
            echo "\`\`\`"
        else
            echo "**Stack Trace:**"
            echo "\`\`\`"
            echo "${stack_trace}"
            echo "\`\`\`"
        fi
        echo ""
    fi

    # Add remediation if available
    if [[ -n "${remediation}" ]]; then
        echo "**Suggested Fix:**"
        echo "${remediation}"
        echo ""
    fi

    # Add build information
    echo "---"
    echo "**Build Details:**"
    echo "- Build: #${BUILD_ID}"
    echo "- Commit: \`${COMMIT_SHA}\`"
    echo "- Branch: ${BRANCH}"
    echo "- Message: ${COMMIT_MESSAGE}"
}

# Store analysis in database
store_notification() {
    local build_id="$1"
    local pattern_name="$2"
    local severity="$3"
    local category="$4"
    local error_msg="$5"
    local stack_trace="$6"
    local location="$7"
    local remediation="$8"
    local notification_text="$9"

    log "Storing failure analysis in database..."

    # Sanitize strings for SQL
    error_msg_sanitized=$(echo "${error_msg}" | sed "s/'/''/g")
    stack_trace_sanitized=$(echo "${stack_trace}" | sed "s/'/''/g")
    remediation_sanitized=$(echo "${remediation}" | sed "s/'/''/g")
    notification_sanitized=$(echo "${notification_text}" | sed "s/'/''/g")

    # Extract file path and line number from location
    file_path=$(echo "${location}" | cut -d':' -f1)
    line_number=$(echo "${location}" | cut -d':' -f2)

    local query="
INSERT INTO notification_history (
    build_id,
    notification_type,
    channel,
    title,
    message,
    metadata,
    delivery_status,
    created_at
) VALUES (
    ${build_id},
    'failure',
    'pending',
    '${pattern_name}',
    '${notification_sanitized}',
    '{\"severity\": \"${severity}\", \"category\": \"${category}\", \"file_path\": \"${file_path}\", \"line_number\": \"${line_number}\", \"error_message\": \"${error_msg_sanitized}\", \"stack_trace\": \"${stack_trace_sanitized}\", \"remediation\": \"${remediation_sanitized}\"}'::jsonb,
    'pending',
    NOW()
) RETURNING id;
"

    local notification_id
    notification_id=$(query_db "${query}")

    if [[ -n "${notification_id}" ]]; then
        log "Notification stored with ID: ${notification_id}"
        echo "${notification_id}"
    else
        log "Warning: Failed to store notification in database"
        echo ""
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    log "Starting failure analysis..."
    log "Build ID: ${BUILD_ID}"
    log "Commit: ${COMMIT_SHA}"
    log "Branch: ${BRANCH}"

    # Check if log file exists
    if [[ ! -f "${LOG_FILE}" ]]; then
        error "Log file not found: ${LOG_FILE}"
    fi

    log "Analyzing log file: ${LOG_FILE}"

    # Extract information from log
    error_msg=$(extract_error_message "${LOG_FILE}")
    stack_trace=$(extract_stack_trace "${LOG_FILE}")
    location=$(extract_location "${LOG_FILE}")

    log "Error found: ${error_msg:0:100}..."
    log "Location: ${location:-Unknown}"

    # Classify the failure
    log "Classifying failure..."
    IFS='|' read -r pattern_name severity category auto_fixable remediation <<< "$(classify_failure "${error_msg}")"

    log "Pattern: ${pattern_name}"
    log "Severity: ${severity}"
    log "Category: ${category}"
    log "Auto-fixable: ${auto_fixable}"

    # Generate notification message
    log "Generating notification..."
    notification=$(generate_notification \
        "${pattern_name}" \
        "${severity}" \
        "${category}" \
        "${error_msg}" \
        "${stack_trace}" \
        "${location}" \
        "${remediation}")

    # Save to output file
    echo "${notification}" > "${OUTPUT_FILE}"
    log "Notification saved to: ${OUTPUT_FILE}"

    # Get build_id from database
    local build_id="${BUILD_ID}"

    if [[ -n "${build_id}" ]]; then
        # Store in database
        notification_id=$(store_notification \
            "${build_id}" \
            "${pattern_name}" \
            "${severity}" \
            "${category}" \
            "${error_msg}" \
            "${stack_trace}" \
            "${location}" \
            "${remediation}" \
            "${notification}")

        if [[ -n "${notification_id}" ]]; then
            # Also store in failure_patterns table for tracking
            log "Storing failure pattern..."
            file_path=$(echo "${location}" | cut -d':' -f1)
            line_number=$(echo "${location}" | cut -d':' -f2)

            # Sanitize strings
            error_msg_sanitized=$(echo "${error_msg}" | sed "s/'/''/g")
            stack_trace_sanitized=$(echo "${stack_trace}" | sed "s/'/''/g")
            remediation_sanitized=$(echo "${remediation}" | sed "s/'/''/g")

            local pattern_query="
INSERT INTO failure_patterns (
    build_id,
    commit_sha,
    branch,
    pattern_type,
    severity,
    stage,
    error_message,
    stack_trace,
    file_path,
    line_number,
    remediation,
    auto_fixable,
    first_seen,
    last_seen,
    occurrence_count
) VALUES (
    ${build_id},
    '${COMMIT_SHA}',
    '${BRANCH}',
    '${pattern_name}',
    '${severity}',
    'build',
    '${error_msg_sanitized}',
    '${stack_trace_sanitized}',
    '${file_path}',
    ${line_number:-NULL},
    '${remediation_sanitized}',
    ${auto_fixable},
    NOW(),
    NOW(),
    1
) ON CONFLICT DO NOTHING;
"
            query_db "${pattern_query}" >/dev/null
            log "Failure pattern stored"
        fi
    else
        log "No build_id available, skipping database storage"
    fi

    # Output JSON for further processing
    cat <<EOF
{
  "pattern_name": "${pattern_name}",
  "severity": "${severity}",
  "category": "${category}",
  "auto_fixable": ${auto_fixable},
  "error_message": $(echo "${error_msg}" | jq -Rs .),
  "stack_trace": $(echo "${stack_trace}" | jq -Rs .),
  "location": "${location}",
  "remediation": $(echo "${remediation}" | jq -Rs .),
  "notification_id": "${notification_id:-}",
  "build_id": "${build_id}",
  "commit_sha": "${COMMIT_SHA}",
  "branch": "${BRANCH}"
}
EOF

    log "Failure analysis complete!"
}

# Run main function
main "$@"
