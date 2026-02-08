#!/bin/bash
# pre-commit-lint.sh
# Run Android lint checks
# Stores results in pre_commit_checks table

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

# Git information
COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"

# Lint report paths
LINT_REPORT_DIR="${PROJECT_ROOT}/app/build/reports"
LINT_XML_REPORT="${LINT_REPORT_DIR}/lint-results.xml"
LINT_JSON_REPORT="${LINT_REPORT_DIR}/lint-results.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result tracking
LINT_ERRORS=0
LINT_WARNINGS=0
LINT_ISSUES=()

# ============================================
# Helper Functions
# ============================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Detect OS for path handling
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# Check if Android project
check_android_project() {
    log "Checking for Android project..."

    if [[ ! -f "${PROJECT_ROOT}/build.gradle" ]] && \
       [[ ! -f "${PROJECT_ROOT}/build.gradle.kts" ]] && \
       [[ ! -f "${PROJECT_ROOT}/app/build.gradle" ]] && \
       [[ ! -f "${PROJECT_ROOT}/app/build.gradle.kts" ]]; then
        log_warning "No Android build.gradle found, skipping lint check"
        return 1
    fi

    log_success "Android project detected"
    return 0
}

# Run Android lint
run_android_lint() {
    log "Running Android lint..."

    # Check if Gradle wrapper exists (handle both gradlew and gradlew.bat)
    if [[ ! -f "${PROJECT_ROOT}/gradlew" ]] && [[ ! -f "${PROJECT_ROOT}/gradlew.bat" ]]; then
        log_error "Gradle wrapper not found"
        return 1
    fi

    cd "${PROJECT_ROOT}"

    # Use platform-appropriate command
    local gradle_cmd="./gradlew"
    if [[ "$(detect_os)" == "windows" ]]; then
        gradle_cmd="gradlew.bat"
    fi

    # Make gradlew executable on Unix-like systems (skip on Windows)
    if [[ "$(detect_os)" != "windows" ]]; then
        chmod +x "${PROJECT_ROOT}/gradlew" 2>/dev/null || true
    fi

    # Configure timeout (60 seconds for pre-commit, down from 300)
    local lint_timeout=${LINT_TIMEOUT:-60}

    # Run lint with timeout (if available)
    local lint_output
    local lint_exit_code

    if command -v timeout >/dev/null 2>&1; then
        lint_output=$(timeout "${lint_timeout}" "${gradle_cmd}" lint 2>&1) || lint_exit_code=$?
    else
        # No timeout command (Windows Git Bash)
        lint_output=$("${gradle_cmd}" lint 2>&1) || lint_exit_code=$?
    fi

    if [[ ${lint_exit_code} -eq 124 ]]; then
        log_error "Lint check timed out after ${lint_timeout} seconds"
        return 1
    fi

    # Parse lint report
    if [[ -f "${LINT_XML_REPORT}" ]]; then
        parse_lint_xml_report
    elif [[ -f "${LINT_JSON_REPORT}" ]]; then
        parse_lint_json_report
    else
        log_warning "Lint report not found, parsing output..."
        parse_lint_output "$lint_output"
    fi

    return 0
}

# Parse lint XML report
parse_lint_xml_report() {
    log "Parsing lint XML report..."

    if ! command -v xmllint &>/dev/null; then
        log_warning "xmllint not available, trying basic parsing"
        return 1
    fi

    # Get issue count
    local issue_count
    issue_count=$(xmllint --xpath "count(/issues/issue)" "${LINT_XML_REPORT}" 2>/dev/null || echo "0")

    if [[ ${issue_count} -eq 0 ]]; then
        log_success "No lint issues found"
        return 0
    fi

    # Parse issues
    local index=1
    while [[ $index -le ${issue_count} ]]; do
        local issue_xpath="/issues/issue[${index}]"
        local severity
        local message
        local file_path
        local line

        severity=$(xmllint --xpath "string(${issue_xpath}/@severity)" "${LINT_XML_REPORT}" 2>/dev/null || echo "unknown")
        message=$(xmllint --xpath "string(${issue_xpath}/@message)" "${LINT_XML_REPORT}" 2>/dev/null || echo "unknown")
        file_path=$(xmllint --xpath "string(${issue_xpath}/location/@file)" "${LINT_XML_REPORT}" 2>/dev/null || echo "unknown")
        line=$(xmllint --xpath "string(${issue_xpath}/location/@line)" "${LINT_XML_REPORT}" 2>/dev/null || echo "?")

        # Count by severity
        case "${severity}" in
            Error)
                ((LINT_ERRORS++))
                ;;
            Warning)
                ((LINT_WARNINGS++))
                ;;
        esac

        # Store issue
        LINT_ISSUES+=("${severity}: ${file_path}:${line} - ${message}")

        ((index++))
    done

    log "Found ${LINT_ERRORS} error(s) and ${LINT_WARNINGS} warning(s)"
}

# Parse lint JSON report
parse_lint_json_report() {
    log "Parsing lint JSON report..."

    if ! command -v jq &>/dev/null; then
        log_warning "jq not available, cannot parse JSON report"
        return 1
    fi

    # Parse issues
    local issues
    issues=$(jq -r '.issues[]? | select(. != null)' "${LINT_JSON_REPORT}" 2>/dev/null || echo "")

    if [[ -z "${issues}" ]]; then
        log_success "No lint issues found"
        return 0
    fi

    # Count issues by severity
    LINT_ERRORS=$(jq '[.issues[]? | select(.severity == "Error")] | length' "${LINT_JSON_REPORT}" 2>/dev/null || echo "0")
    LINT_WARNINGS=$(jq '[.issues[]? | select(.severity == "Warning")] | length' "${LINT_JSON_REPORT}" 2>/dev/null || echo "0")

    # Extract issue messages
    while IFS= read -r issue; do
        if [[ -n "${issue}" ]]; then
            local severity
            local message
            local file_path
            local line

            severity=$(echo "${issue}" | jq -r '.severity // "unknown"' 2>/dev/null || echo "unknown")
            message=$(echo "${issue}" | jq -r '.message // "unknown"' 2>/dev/null || echo "unknown")
            file_path=$(echo "${issue}" | jq -r '.file // "unknown"' 2>/dev/null || echo "unknown")
            line=$(echo "${issue}" | jq -r '.line // "?"' 2>/dev/null || echo "?")

            LINT_ISSUES+=("${severity}: ${file_path}:${line} - ${message}")
        fi
    done <<< "$(jq -c '.issues[]?' "${LINT_JSON_REPORT}" 2>/dev/null || echo "")"

    log "Found ${LINT_ERRORS} error(s) and ${LINT_WARNINGS} warning(s)"
}

# Parse lint output (fallback)
parse_lint_output() {
    local output="$1"

    log "Parsing lint output..."

    # Look for error/warning patterns
    # Format: file:line: severity: message
    while IFS= read -r line; do
        if [[ "$line" =~ [Ee]rror|error: ]] || [[ "$line" =~ \[ERROR\] ]]; then
            ((LINT_ERRORS++))
            LINT_ISSUES+=("Error: ${line}")
        elif [[ "$line" =~ [Ww]arning|warning: ]] || [[ "$line" =~ \[WARNING\] ]]; then
            ((LINT_WARNINGS++))
            LINT_ISSUES+=("Warning: ${line}")
        fi
    done <<< "$output"

    log "Found ${LINT_ERRORS} error(s) and ${LINT_WARNINGS} warning(s)"
}

# Store result in database
store_result() {
    local status="$1"
    local details="$2"
    local duration="$3"

    log "Storing result in database..."

    # Sanitize details for SQL
    local sanitized_details
    sanitized_details=$(echo "${details}" | sed "s/'/''/g")

    # Build findings JSON
    local findings_json
    if command -v jq &>/dev/null; then
        findings_json=$(jq -n \
            --argjson errors "${LINT_ERRORS}" \
            --argjson warnings "${LINT_WARNINGS}" \
            --argjson total_issues "${#LINT_ISSUES[@]}" \
            '{
              error_count: $errors,
              warning_count: $warnings,
              total_issues: $total_issues
            }' 2>/dev/null || echo '{}')
    else
        findings_json='{}'
    fi

    local query="
INSERT INTO pre_commit_checks (
  commit_sha,
  branch,
  check_type,
  status,
  duration_ms,
  exit_code,
  output,
  findings,
  timestamp
) VALUES (
  '${COMMIT_SHA}',
  '${BRANCH}',
  'lint',
  '${status}',
  ${duration},
  ${status},
  E'${sanitized_details}',
  '${findings_json}'::jsonb,
  NOW()
)
ON CONFLICT (commit_sha, branch, check_type)
DO UPDATE SET
  status = EXCLUDED.status,
  duration_ms = EXCLUDED.duration_ms,
  exit_code = EXCLUDED.exit_code,
  output = EXCLUDED.output,
  findings = EXCLUDED.findings,
  timestamp = NOW();
"

    query_db "$query" >/dev/null

    log_success "Result stored in database"
}

# Display issues
display_issues() {
    if [[ ${#LINT_ISSUES[@]} -eq 0 ]]; then
        return
    fi

    echo ""
    log "Lint Issues:"
    echo ""

    # Show up to 20 issues
    local count=0
    for issue in "${LINT_ISSUES[@]}"; do
        if [[ $count -lt 20 ]]; then
            echo "  ${issue}"
            ((count++))
        fi
    done

    if [[ ${#LINT_ISSUES[@]} -gt 20 ]]; then
        echo "  ... and $(( ${#LINT_ISSUES[@]} - 20 )) more"
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    log "=== Pre-commit Lint Check ==="
    echo ""

    # Check if Android project
    if ! check_android_project; then
        log_warning "Skipping lint check"
        exit 0
    fi

    echo ""

    # Run lint
    local exit_code=0
    if run_android_lint; then
        # Determine exit code based on errors
        if [[ ${LINT_ERRORS} -gt 0 ]]; then
            exit_code=1
        else
            exit_code=0
        fi
    else
        exit_code=1
    fi

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - start_time) * 1000 ))

    # Build details string
    local details
    if [[ ${LINT_ERRORS} -eq 0 && ${LINT_WARNINGS} -eq 0 ]]; then
        details="No lint issues found"
    else
        details="Found ${LINT_ERRORS} error(s) and ${LINT_WARNINGS} warning(s)"
    fi

    # Store result in database
    local status="passed"
    if [[ ${exit_code} -ne 0 ]]; then
        status="failed"
    fi

    store_result "$status" "$details" "$duration"

    echo ""
    log "Lint check complete (${duration}ms)"

    # Display issues
    display_issues

    # Final result
    if [[ ${exit_code} -eq 0 ]]; then
        echo ""
        log_success "Lint check passed"
        exit 0
    else
        echo ""
        log_error "Lint check failed (${LINT_ERRORS} errors, ${LINT_WARNINGS} warnings)"
        exit 1
    fi
}

# Run main function
main "$@"
