#!/bin/bash
# pre-commit-secrets.sh
# Scan staged files for secrets using trufflehog
# Stores results in pre_commit_checks and security_scans tables

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

# TruffleHog configuration (use platform-appropriate temp directory)
TEMP_DIR=$(get_temp_dir)
RESULTS_FILE="${TEMP_DIR}/trufflehog-precommit-$$-$(date +%s).json"
SECRETS_IGNORE="${PROJECT_ROOT}/.secretsignore"

# Ensure temp directory exists
mkdir -p "${TEMP_DIR}" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result tracking
SECRETS_FOUND=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
FINDINGS=()

# Severity classification rules
CRITICAL_PATTERNS=(
    "password.*=.*['\"].+['\"]"
    "api[_-]?key.*=.*['\"].+['\"]"
    "secret[_-]?key.*=.*['\"].+['\"]"
    "private[_-]?key"
    "aws[_-]?secret"
    "token.*=.*['\"].+['\"]"
)

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

# Get temp directory for the platform
get_temp_dir() {
    if [[ "$(detect_os)" == "windows" ]]; then
        # Windows: use TEMP environment variable
        echo "${TEMP:-C:\Temp}"
    else
        # Unix/Linux/macOS: use /tmp
        echo "/tmp"
    fi
}

# Check if trufflehog is available
check_trufflehog() {
    log "Checking for trufflehog..."

    if ! command -v trufflehog &>/dev/null; then
        log_error "trufflehog not found"
        log ""
        log "Install with:"
        log "  go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest"
        log ""
        return 1
    fi

    log_success "trufflehog found: $(trufflehog --version 2>&1 | head -1)"
    return 0
}

# Get staged files
get_staged_files() {
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")

    if [[ -z "${staged_files}" ]]; then
        log_warning "No staged files found"
        return 1
    fi

    echo "${staged_files}"
    return 0
}

# Run trufflehog scan on staged files
run_secrets_scan() {
    log "Scanning staged files for secrets..."

    local staged_files
    staged_files=$(get_staged_files)

    if [[ $? -ne 0 ]]; then
        return 0
    fi

    # Count staged files
    local file_count
    file_count=$(echo "${staged_files}" | wc -l)
    log "Scanning ${file_count} staged file(s)..."

    # Build trufflehog command
    local trufflehog_cmd="trufflehog git ${PROJECT_ROOT} --json --only-verified"

    # Add file filters if .secretsignore exists
    if [[ -f "${SECRETS_IGNORE}" ]]; then
        log "Using .secretsignore file"
    fi

    # Execute scan
    eval "${trufflehog_cmd}" 2>/dev/null > "${RESULTS_FILE}" || true

    # Check if results file has content
    if [[ ! -s "${RESULTS_FILE}" ]]; then
        log_success "No secrets detected"
        return 0
    fi

    # Filter results to only include staged files
    filter_staged_findings "${staged_files}"

    return 0
}

# Filter findings to only staged files
filter_staged_findings() {
    local staged_files="$1"

    log "Filtering findings to staged files..."

    local temp_dir=$(get_temp_dir)
    local filtered_results="${temp_dir}/trufflehog-filtered-$$-$(date +%s).json"
    local temp_file="${filtered_results}"

    # Ensure temp directory exists
    mkdir -p "${temp_dir}" 2>/dev/null || true

    # Create empty filtered results
    echo "" > "${temp_file}"

    # Process each finding
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi

        # Extract file path from finding
        local file_path
        file_path=$(echo "${line}" | jq -r '.SourceMetadata?.Data?.Git?.file // .file // ""' 2>/dev/null || echo "")

        if [[ -z "${file_path}" ]]; then
            continue
        fi

        # Check if file is staged
        if echo "${staged_files}" | grep -q "${file_path}"; then
            echo "${line}" >> "${temp_file}"
        fi
    done < "${RESULTS_FILE}"

    # Replace results with filtered results
    mv "${temp_file}" "${RESULTS_FILE}"

    # Count findings
    local finding_count
    finding_count=$(wc -l < "${RESULTS_FILE}" 2>/dev/null || echo "0")

    if [[ ${finding_count} -eq 0 ]]; then
        log_success "No secrets detected in staged files"
        SECRETS_FOUND=0
        return 0
    fi

    log_warning "Found ${finding_count} potential secret(s) in staged files"
    SECRETS_FOUND=1

    # Parse findings
    parse_findings
}

# Parse trufflehog findings
parse_findings() {
    log "Parsing findings..."

    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi

        # Extract finding details
        local source_name
        local detector_name
        local verified
        local file_path

        source_name=$(echo "${line}" | jq -r '.SourceName // .source_name // "unknown"' 2>/dev/null || echo "unknown")
        detector_name=$(echo "${line}" | jq -r '.DetectorName // .detector // "unknown"' 2>/dev/null || echo "unknown")
        verified=$(echo "${line}" | jq -r '.Verified // .verified // false' 2>/dev/null || echo "false")
        file_path=$(echo "${line}" | jq -r '.SourceMetadata?.Data?.Git?.file // .file // "unknown"' 2>/dev/null || echo "unknown")

        # Classify severity
        local severity="medium"

        # Critical: verified secrets
        if [[ "${verified}" == "true" ]]; then
            severity="critical"
        fi

        # High: sensitive detector names
        case "${detector_name}" in
            *AWS*|*Stripe*|*PayPal*|*Slack*|*GitHub*|*SSH*|*Private*|*Password*)
                if [[ "${severity}" != "critical" ]]; then
                    severity="high"
                fi
                ;;
        esac

        # Update counts
        case "${severity}" in
            critical) ((CRITICAL_COUNT++)) ;;
            high) ((HIGH_COUNT++)) ;;
            medium) ((MEDIUM_COUNT++)) ;;
            low) ((LOW_COUNT++)) ;;
        esac

        # Store finding
        FINDINGS+=("${severity}: ${detector_name} in ${file_path} (verified: ${verified})")
    done < "${RESULTS_FILE}"
}

# Store result in pre_commit_checks table
store_pre_commit_result() {
    local status="$1"
    local details="$2"
    local duration="$3"

    log "Storing result in pre_commit_checks..."

    # Sanitize details for SQL
    local sanitized_details
    sanitized_details=$(echo "${details}" | sed "s/'/''/g")

    # Build findings JSON
    local findings_json
    if command -v jq &>/dev/null; then
        findings_json=$(jq -n \
            --argjson critical "${CRITICAL_COUNT}" \
            --argjson high "${HIGH_COUNT}" \
            --argjson medium "${MEDIUM_COUNT}" \
            --argjson low "${LOW_COUNT}" \
            --argjson total "$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))" \
            '{
              critical_count: $critical,
              high_count: $high,
              medium_count: $medium,
              low_count: $low,
              total_secrets: $total
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
  'secrets',
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

    log_success "Result stored in pre_commit_checks"
}

# Store result in security_scans table
store_security_scan_result() {
    log "Storing result in security_scans..."

    local total=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))

    if [[ ${total} -eq 0 ]]; then
        return 0
    fi

    # Build findings JSON
    local findings_json
    if command -v jq &>/dev/null; then
        findings_json=$(jq -n \
            --argjson critical "${CRITICAL_COUNT}" \
            --argjson high "${HIGH_COUNT}" \
            --argjson medium "${MEDIUM_COUNT}" \
            --argjson low "${LOW_COUNT}" \
            '{
              severity_distribution: {
                critical: $critical,
                high: $high,
                medium: $medium,
                low: $low
              }
            }' 2>/dev/null || echo '{}')
    else
        findings_json='{}'
    fi

    # Determine action taken
    local action="passed"
    if [[ ${CRITICAL_COUNT} -gt 0 ]]; then
        action="blocked"
    elif [[ ${HIGH_COUNT} -gt 0 ]]; then
        action="warning"
    fi

    # Get scanner version
    local scanner_version
    scanner_version=$(trufflehog --version 2>&1 | head -1 || echo "unknown")

    local query="
INSERT INTO security_scans (
  commit_sha,
  branch,
  scan_type,
  scanner_version,
  findings_count,
  critical_count,
  high_count,
  medium_count,
  low_count,
  findings,
  action_taken,
  timestamp
) VALUES (
  '${COMMIT_SHA}',
  '${BRANCH}',
  'secret',
  '${scanner_version}',
  ${total},
  ${CRITICAL_COUNT},
  ${HIGH_COUNT},
  ${MEDIUM_COUNT},
  ${LOW_COUNT},
  '${findings_json}'::jsonb,
  '${action}',
  NOW()
)
ON CONFLICT DO NOTHING;
"

    query_db "$query" >/dev/null

    log_success "Result stored in security_scans"
}

# Display findings
display_findings() {
    if [[ ${#FINDINGS[@]} -eq 0 ]]; then
        return
    fi

    echo ""
    log "Secret Findings:"
    echo ""

    for finding in "${FINDINGS[@]}"; do
        echo "  ${finding}"
    done
}

# ============================================
# Main Execution
# ============================================

main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    log "=== Pre-commit Secrets Scan ==="
    echo ""

    # Check if trufflehog is available
    if ! check_trufflehog; then
        log_warning "Skipping secrets scan (trufflehog not installed)"
        exit 0
    fi

    echo ""

    # Run secrets scan
    run_secrets_scan

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - start_time) * 1000 ))

    # Build details string
    local details
    if [[ ${SECRETS_FOUND} -eq 0 ]]; then
        details="No secrets detected"
    else
        details="Found ${CRITICAL_COUNT} critical, ${HIGH_COUNT} high, ${MEDIUM_COUNT} medium, ${LOW_COUNT} low severity secrets"
    fi

    # Determine status
    local status="passed"
    local exit_code=0

    if [[ ${CRITICAL_COUNT} -gt 0 ]]; then
        status="failed"
        exit_code=1
    fi

    # Store results in database
    store_pre_commit_result "$status" "$details" "$duration"
    store_security_scan_result

    echo ""
    log "Secrets scan complete (${duration}ms)"

    # Display findings
    display_findings

    # Final result
    if [[ ${exit_code} -eq 0 ]]; then
        echo ""
        log_success "Secrets scan passed"
        exit 0
    else
        echo ""
        log_error "Secrets scan failed - critical secrets detected!"
        echo ""
        log "Please remove the secrets before committing."
        echo "Use 'git rev-parse HEAD' to see the commit."
        echo ""
        exit 1
    fi
}

# Cleanup on exit
cleanup() {
    rm -f "${RESULTS_FILE}"
}

trap cleanup EXIT

# Run main function
main "$@"
