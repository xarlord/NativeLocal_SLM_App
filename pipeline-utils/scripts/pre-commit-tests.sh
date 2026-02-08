#!/bin/bash
# pre-commit-tests.sh
# Run quick unit tests only (no instrumented tests)
# Target: < 30 seconds
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

# Test timeout (30 seconds)
TEST_TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_TESTS=()

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

# Check if tests are available
check_tests_available() {
    log "Checking for unit tests..."

    # Check if Gradle wrapper exists (handle both gradlew and gradlew.bat)
    if [[ ! -f "${PROJECT_ROOT}/gradlew" ]] && [[ ! -f "${PROJECT_ROOT}/gradlew.bat" ]]; then
        log_warning "Gradle wrapper not found, skipping tests"
        return 1
    fi

    # Check if test directory exists
    if [[ ! -d "${PROJECT_ROOT}/app/src/test" ]] && \
       [[ ! -d "${PROJECT_ROOT}/src/test" ]]; then
        log_warning "No test directory found, skipping tests"
        return 1
    fi

    log_success "Unit tests available"
    return 0
}

# Run unit tests
run_unit_tests() {
    log "Running unit tests (timeout: ${TEST_TIMEOUT}s)..."

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

    # Run unit tests with timeout (if available)
    local test_output
    local test_exit_code

    # Run only unit tests (no instrumented tests)
    if command -v timeout >/dev/null 2>&1; then
        test_output=$(timeout ${TEST_TIMEOUT} "${gradle_cmd}" testDebugUnitTest --no-daemon 2>&1) || test_exit_code=$?
    else
        # No timeout command (Windows Git Bash)
        test_output=$("${gradle_cmd}" testDebugUnitTest --no-daemon 2>&1) || test_exit_code=$?
    fi

    if [[ ${test_exit_code} -eq 124 ]]; then
        log_error "Tests timed out after ${TEST_TIMEOUT} seconds"
        return 1
    fi

    # Parse test results
    parse_test_results "$test_output"

    return ${test_exit_code}
}

# Parse test results from Gradle output
parse_test_results() {
    local output="$1"

    log "Parsing test results..."

    # Look for test result patterns
    # Format: BUILD SUCCESSful or BUILD FAILED
    if echo "$output" | grep -q "BUILD SUCCESSFUL\|BUILD SUCCESS"; then
        log_success "Build successful"
    elif echo "$output" | grep -q "BUILD FAILED"; then
        log_error "Build failed"
    fi

    # Parse test counts from output
    # Look for patterns like: "123 tests completed, 1 failed"
    while IFS= read -r line; do
        if [[ "$line" =~ ([0-9]+)[[:space:]]*test ]]; then
            TESTS_TOTAL=$(echo "$line" | grep -oP '\d+(?= test)' || echo "${TESTS_TOTAL}")
        fi

        if [[ "$line" =~ ([0-9]+)[[:space:]]*failed ]]; then
            TESTS_FAILED=$(echo "$line" | grep -oP '\d+(?= failed)' || echo "${TESTS_FAILED}")
        fi

        if [[ "$line" =~ ([0-9]+)[[:space:]]*passed ]]; then
            TESTS_PASSED=$(echo "$line" | grep -oP '\d+(?= passed)' || echo "${TESTS_PASSED}")
        fi
    done <<< "$output"

    # Also check test result files
    parse_test_result_files

    # Calculate passed if we have total and failed
    if [[ ${TESTS_TOTAL} -gt 0 && ${TESTS_PASSED} -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_TOTAL - TESTS_FAILED - TESTS_SKIPPED))
    fi

    log "Tests: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed, ${TESTS_SKIPPED} skipped (total: ${TESTS_TOTAL})"
}

# Parse test result files
parse_test_result_files() {
    # Common test result directories
    local test_dirs=(
        "${PROJECT_ROOT}/app/build/test-results/testDebugUnitTest"
        "${PROJECT_ROOT}/build/test-results/test"
        "${PROJECT_ROOT}/app/build/test-results/test"
    )

    for test_dir in "${test_dirs[@]}"; do
        if [[ ! -d "${test_dir}" ]]; then
            continue
        fi

        # Look for TEST-*.xml files
        for xml_file in "${test_dir}"/*.xml; do
            if [[ ! -f "${xml_file}" ]]; then
                continue
            fi

            if command -v xmllint &>/dev/null; then
                # Parse XML test results
                local tests
                local failures
                local errors
                local skipped

                tests=$(xmllint --xpath "string(//testsuite/@tests)" "${xml_file}" 2>/dev/null || echo "0")
                failures=$(xmllint --xpath "string(//testsuite/@failures)" "${xml_file}" 2>/dev/null || echo "0")
                errors=$(xmllint --xpath "string(//testsuite/@errors)" "${xml_file}" 2>/dev/null || echo "0")
                skipped=$(xmllint --xpath "string(//testsuite/@skipped)" "${xml_file}" 2>/dev/null || echo "0")

                TESTS_TOTAL=$((TESTS_TOTAL + tests))
                TESTS_FAILED=$((TESTS_FAILED + failures + errors))
                TESTS_SKIPPED=$((TESTS_SKIPPED + skipped))

                # Extract failed test names
                local failed_tests
                failed_tests=$(xmllint --xpath "//testcase[failure or error]/@classname" "${xml_file}" 2>/dev/null || echo "")

                if [[ -n "${failed_tests}" ]]; then
                    while IFS= read -r test_name; do
                        if [[ -n "${test_name}" ]]; then
                            FAILED_TESTS+=("${test_name}")
                        fi
                    done <<< "${failed_tests}"
                fi
            fi
        done
    done
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
            --argjson total "${TESTS_TOTAL}" \
            --argjson passed "${TESTS_PASSED}" \
            --argjson failed "${TESTS_FAILED}" \
            --argjson skipped "${TESTS_SKIPPED}" \
            --argjson failed_tests "$(printf '%s\n' "${FAILED_TESTS[@]}" | jq -R . | jq -s .)" \
            '{
              test_count: $total,
              passed: $passed,
              failed: $failed,
              skipped: $skipped,
              failed_tests: $failed_tests
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
  'tests',
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

# Display failed tests
display_failed_tests() {
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        return
    fi

    echo ""
    log "Failed Tests:"
    echo ""

    # Show up to 10 failed tests
    local count=0
    for test_name in "${FAILED_TESTS[@]}"; do
        if [[ $count -lt 10 ]]; then
            echo "  ✗ ${test_name}"
            ((count++))
        fi
    done

    if [[ ${#FAILED_TESTS[@]} -gt 10 ]]; then
        echo "  ... and $(( ${#FAILED_TESTS[@]} - 10 )) more"
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    log "=== Pre-commit Unit Tests ==="
    echo ""

    # Check if tests are available
    if ! check_tests_available; then
        log_warning "Skipping tests"
        exit 0
    fi

    echo ""

    # Run unit tests
    local exit_code=0
    if run_unit_tests; then
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
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        details="All ${TESTS_TOTAL} tests passed"
    else
        details="${TESTS_FAILED} of ${TESTS_TOTAL} tests failed"
    fi

    # Store result in database
    local status="passed"
    if [[ ${exit_code} -ne 0 ]]; then
        status="failed"
    fi

    store_result "$status" "$details" "$duration"

    echo ""
    log "Tests complete (${duration}ms)"

    # Display failed tests
    display_failed_tests

    # Final result
    if [[ ${exit_code} -eq 0 ]]; then
        echo ""
        log_success "All tests passed"
        exit 0
    else
        echo ""
        log_error "Tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
