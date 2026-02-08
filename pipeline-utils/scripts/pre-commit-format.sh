#!/bin/bash
# pre-commit-format.sh
# Check code formatting with ktlint
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result tracking
VIOLATIONS_FOUND=0
VIOLATION_FILES=()
VIOLATION_COUNT=0

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

# Convert Windows paths if needed
convert_path() {
    local path="$1"
    local os_type
    os_type=$(detect_os)

    if [[ "$os_type" == "windows" ]]; then
        # Convert Git Bash paths to Windows paths if needed
        # /c/Users/... -> C:/Users/...
        if [[ "$path" =~ ^/[a-z]/ ]]; then
            path="$(echo "$path" | sed 's|^\([a-z]\)|\1|' | sed 's|^/||' | sed 's|/|\\|g')"
            path="${path^}"
        fi
    fi

    echo "$path"
}

# Check if ktlint is available
check_ktlint() {
    log "Checking for ktlint..."

    # Check if Gradle wrapper exists (handle both gradlew and gradlew.bat)
    if [[ ! -f "${PROJECT_ROOT}/gradlew" ]] && [[ ! -f "${PROJECT_ROOT}/gradlew.bat" ]]; then
        log_warning "Gradle wrapper not found, skipping format check"
        return 1
    fi

    # Make gradlew executable on Unix-like systems (skip on Windows)
    if [[ "$(detect_os)" != "windows" ]]; then
        chmod +x "${PROJECT_ROOT}/gradlew" 2>/dev/null || true
    fi

    log_success "ktlint available via Gradle"
    return 0
}

# Run ktlint check
run_ktlint_check() {
    log "Running ktlint check..."

    local ktlint_output
    local ktlint_exit_code

    # Run ktlintCheck and capture output
    cd "${PROJECT_ROOT}"

    # Use platform-appropriate command
    local gradle_cmd="./gradlew"
    if [[ "$(detect_os)" == "windows" ]]; then
        gradle_cmd="gradlew.bat"
    fi

    # Configure timeout (30 seconds for pre-commit, down from 180)
    local format_timeout=${FORMAT_TIMEOUT:-30}

    # Run ktlint check with timeout (if available)
    if command -v timeout >/dev/null 2>&1; then
        ktlint_output=$(timeout "${format_timeout}" "${gradle_cmd}" ktlintCheck 2>&1) || ktlint_exit_code=$?
    else
        # No timeout command (Windows Git Bash)
        ktlint_output=$("${gradle_cmd}" ktlintCheck 2>&1) || ktlint_exit_code=$?
    fi

    if [[ ${ktlint_exit_code} -eq 0 ]]; then
        log_success "No formatting violations found"
        return 0
    elif [[ ${ktlint_exit_code} -eq 124 ]]; then
        log_error "ktlint check timed out after ${format_timeout} seconds"
        return 1
    fi

    # Parse output for violations
    parse_ktlint_output "$ktlint_output"

    return 1
}

# Parse ktlint output
parse_ktlint_output() {
    local output="$1"

    log "Parsing ktlint output..."

    # Look for violation patterns
    # Format: file:line:column: message
    while IFS= read -r line; do
        if [[ "$line" =~ \.(kt|kts):[0-9]+:[0-9]+: ]]; then
            ((VIOLATION_COUNT++))

            # Extract file path
            local file_path
            file_path=$(echo "$line" | grep -oP '^[^:]+\.(kt|kts)' || echo "unknown")

            VIOLATION_FILES+=("$file_path")
        fi
    done <<< "$output"

    if [[ ${VIOLATION_COUNT} -gt 0 ]]; then
        log_error "Found ${VIOLATION_COUNT} formatting violation(s)"
        VIOLATIONS_FOUND=1
    else
        log_warning "ktlint reported failures but no violations parsed"
        VIOLATIONS_FOUND=1
    fi
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

    # Get changed files count
    local changed_files
    changed_files=$(git diff --cached --name-only 2>/dev/null | wc -l || echo "0")

    # Build findings JSON
    local findings_json
    if command -v jq &>/dev/null; then
        findings_json=$(jq -n \
            --argjson files "$(printf '%s\n' "${VIOLATION_FILES[@]}" | jq -R . | jq -s .)" \
            --arg count "${VIOLATION_COUNT}" \
            '{
              violation_count: ($count | tonumber),
              files_with_violations: $files
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
  'format',
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

# Generate fix command
generate_fix_command() {
    echo ""
    log "To fix formatting issues automatically:"
    echo ""
    echo "  cd ${PROJECT_ROOT}"
    echo "  ./gradlew ktlintFormat"
    echo ""
    echo "Then commit again:"
    echo "  git add ."
    echo "  git commit -m 'Fix formatting'"
    echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    log "=== Pre-commit Format Check ==="
    echo ""

    # Check if ktlint is available
    if ! check_ktlint; then
        log_warning "Skipping format check"
        exit 0
    fi

    echo ""

    # Run ktlint check
    local exit_code=0
    if run_ktlint_check; then
        exit_code=0
    else
        exit_code=1
    fi

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - start_time) * 1000 ))

    # Build details string
    local details
    if [[ ${exit_code} -eq 0 ]]; then
        details="No formatting violations found"
    else
        details="Found ${VIOLATION_COUNT} formatting violation(s) in ${#VIOLATION_FILES[@]} file(s)"
    fi

    # Store result in database
    local status="passed"
    if [[ ${exit_code} -ne 0 ]]; then
        status="failed"
    fi

    store_result "$status" "$details" "$duration"

    echo ""
    log "Format check complete (${duration}ms)"

    # Display results
    if [[ ${exit_code} -eq 0 ]]; then
        echo ""
        log_success "Format check passed"
        exit 0
    else
        echo ""
        log_error "Format check failed"

        # Show files with violations
        if [[ ${#VIOLATION_FILES[@]} -gt 0 ]]; then
            echo ""
            log "Files with violations:"
            printf "  - %s\n" "${VIOLATION_FILES[@]}" | sort -u
        fi

        generate_fix_command
        exit 1
    fi
}

# Run main function
main "$@"
