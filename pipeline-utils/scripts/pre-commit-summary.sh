#!/bin/bash
# pre-commit-summary.sh
# Generate summary report of all pre-commit checks
 Displays passed/failed counts, total duration, formatted as table

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

# Check types
CHECK_TYPES=("format" "lint" "tests" "secrets")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" >&2
}

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Get check results from database
get_check_results() {
    local query="
SELECT
  check_type,
  status,
  duration_ms,
  exit_code,
  findings
FROM pre_commit_checks
WHERE commit_sha = '${COMMIT_SHA}'
  AND branch = '${BRANCH}'
ORDER BY check_type;
"

    query_db "${query}"
}

# Parse check results
parse_check_results() {
    local results="$1"

    local check_type
    local status
    local duration
    local exit_code
    local findings

    # Parse tab-separated results
    while IFS=$'\t' read -r check_type status duration exit_code findings; do
        if [[ -z "${check_type}" ]]; then
            continue
        fi

        # Store results in associative array
        CHECK_RESULTS["${check_type}"]="${status}|${duration}|${exit_code}|${findings}"
    done <<< "$results"
}

# Format duration
format_duration() {
    local duration_ms="$1"

    if [[ -z "${duration_ms}" || "${duration_ms}" == "0" ]]; then
        echo "N/A"
        return
    fi

    local seconds=$((duration_ms / 1000))
    local ms=$((duration_ms % 1000))

    if [[ ${seconds} -ge 60 ]]; then
        local minutes=$((seconds / 60))
        local secs=$((seconds % 60))
        printf "%dm %ds" ${minutes} ${secs}
    else
        printf "%d.%03ds" ${seconds} ${ms}
    fi
}

# Get status icon
get_status_icon() {
    local status="$1"

    case "${status}" in
        passed)
            echo -e "${GREEN}✓${NC}"
            ;;
        failed)
            echo -e "${RED}✗${NC}"
            ;;
        skipped)
            echo -e "${YELLOW}⊝${NC}"
            ;;
        *)
            echo -e "${YELLOW}?${NC}"
            ;;
    esac
}

# Get status color
get_status_color() {
    local status="$1"

    case "${status}" in
        passed)
            echo -e "${GREEN}"
            ;;
        failed)
            echo -e "${RED}"
            ;;
        skipped)
            echo -e "${YELLOW}"
            ;;
        *)
            echo -e "${YELLOW}"
            ;;
    esac
}

# Generate summary table
generate_summary_table() {
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local skipped_checks=0
    local total_duration=0

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}                  PRE-COMIT CHECKS SUMMARY                     ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Commit:${NC} ${COMMIT_SHA:0:8}"
    echo -e "${BOLD}Branch:${NC} ${BRANCH}"
    echo -e "${BOLD}Time:${NC}   $(date +'%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────${NC}"
    printf "${BOLD}%-15s %-12s %-15s %-12s${NC}\n" "Check" "Status" "Duration" "Details"
    echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────${NC}"

    # Display each check
    for check_type in "${CHECK_TYPES[@]}"; do
        local result="${CHECK_RESULTS[$check_type]:-}"

        if [[ -z "${result}" ]]; then
            # Check not found in database
            local status="skipped"
            local duration="N/A"
            local details="Not run"
            local exit_code=""
        else
            IFS='|' read -r status duration_ms exit_code findings <<< "${result}"

            if [[ -z "${status}" ]]; then
                status="skipped"
            fi

            local duration
            duration=$(format_duration "${duration_ms}")

            # Extract details from findings
            local details
            case "${check_type}" in
                format)
                    if [[ "${status}" == "failed" ]]; then
                        details="Violations found"
                    else
                        details="No violations"
                    fi
                    ;;
                lint)
                    if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                        local errors
                        local warnings
                        errors=$(echo "${findings}" | jq -r '.error_count // 0' 2>/dev/null || echo "0")
                        warnings=$(echo "${findings}" | jq -r '.warning_count // 0' 2>/dev/null || echo "0")
                        details="${errors}E, ${warnings}W"
                    else
                        details="N/A"
                    fi
                    ;;
                tests)
                    if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                        local passed
                        local failed
                        passed=$(echo "${findings}" | jq -r '.passed // 0' 2>/dev/null || echo "0")
                        failed=$(echo "${findings}" | jq -r '.failed // 0' 2>/dev/null || echo "0")
                        details="${passed} passed, ${failed} failed"
                    else
                        details="N/A"
                    fi
                    ;;
                secrets)
                    if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                        local total
                        total=$(echo "${findings}" | jq -r '.total_secrets // 0' 2>/dev/null || echo "0")
                        if [[ ${total} -gt 0 ]]; then
                            details="${total} found"
                        else
                            details="None found"
                        fi
                    else
                        details="N/A"
                    fi
                    ;;
                *)
                    details="N/A"
                    ;;
            esac
        fi

        # Get status icon and color
        local icon
        icon=$(get_status_icon "${status}")
        local color
        color=$(get_status_color "${status}")

        # Display row
        printf "%-15s ${color}%-12s${NC} %-15s %-12s\n" \
            "${check_type^}" \
            "${status}" \
            "${duration}" \
            "${details}"

        # Update counters
        ((total_checks++))
        case "${status}" in
            passed) ((passed_checks++)) ;;
            failed) ((failed_checks++)) ;;
            skipped) ((skipped_checks++)) ;;
        esac

        # Add to total duration (if numeric)
        if [[ -n "${duration_ms}" && "${duration_ms}" =~ ^[0-9]+$ ]]; then
            total_duration=$((total_duration + duration_ms))
        fi
    done

    echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo ""

    # Summary counts
    local total_duration_formatted
    total_duration_formatted=$(format_duration "${total_duration}")

    echo -e "${BOLD}Total Checks:${NC}    ${total_checks}"
    echo -e "${GREEN}${BOLD}Passed:${NC}         ${passed_checks}${NC}"
    echo -e "${RED}${BOLD}Failed:${NC}         ${failed_checks}${NC}"
    if [[ ${skipped_checks} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}Skipped:${NC}        ${skipped_checks}${NC}"
    fi
    echo -e "${BOLD}Total Duration:${NC}  ${total_duration_formatted}"

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Generate detailed report
generate_detailed_report() {
    echo -e "${BOLD}${CYAN}Detailed Findings:${NC}"
    echo ""

    for check_type in "${CHECK_TYPES[@]}"; do
        local result="${CHECK_RESULTS[$check_type]:-}"

        if [[ -z "${result}" ]]; then
            continue
        fi

        IFS='|' read -r status duration_ms exit_code findings <<< "${result}"

        # Only show details for failed checks
        if [[ "${status}" != "failed" ]]; then
            continue
        fi

        echo -e "${BOLD}${check_type^}:${NC}"

        case "${check_type}" in
            format)
                if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                    local files
                    files=$(echo "${findings}" | jq -r '.files_with_violations[]?' 2>/dev/null || echo "")
                    if [[ -n "${files}" ]]; then
                        echo "  Files with violations:"
                        while IFS= read -r file; do
                            echo "    - ${file}"
                        done <<< "${files}"
                    fi
                fi
                ;;

            lint)
                if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                    local errors
                    local warnings
                    errors=$(echo "${findings}" | jq -r '.error_count // 0' 2>/dev/null || echo "0")
                    warnings=$(echo "${findings}" | jq -r '.warning_count // 0' 2>/dev/null || echo "0")
                    echo "  Errors: ${errors}"
                    echo "  Warnings: ${warnings}"
                fi
                ;;

            tests)
                if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                    local failed_tests
                    failed_tests=$(echo "${findings}" | jq -r '.failed_tests[]?' 2>/dev/null || echo "")
                    if [[ -n "${failed_tests}" ]]; then
                        echo "  Failed tests:"
                        while IFS= read -r test; do
                            echo "    - ${test}"
                        done <<< "${failed_tests}"
                    fi
                fi
                ;;

            secrets)
                if command -v jq &>/dev/null && [[ -n "${findings}" && "${findings}" != "null" ]]; then
                    local critical
                    local high
                    critical=$(echo "${findings}" | jq -r '.critical_count // 0' 2>/dev/null || echo "0")
                    high=$(echo "${findings}" | jq -r '.high_count // 0' 2>/dev/null || echo "0")
                    echo "  Critical: ${critical}"
                    echo "  High: ${high}"
                fi
                ;;
        esac

        echo ""
    done
}

# Display final verdict
display_verdict() {
    local passed=0
    local failed=0

    for check_type in "${CHECK_TYPES[@]}"; do
        local result="${CHECK_RESULTS[$check_type]:-}"

        if [[ -z "${result}" ]]; then
            continue
        fi

        IFS='|' read -r status duration_ms exit_code findings <<< "${result}"

        case "${status}" in
            passed) ((passed++)) ;;
            failed) ((failed++)) ;;
        esac
    done

    if [[ ${failed} -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All checks passed!${NC}"
        echo ""
    else
        echo -e "${RED}${BOLD}✗ Some checks failed. Commit blocked.${NC}"
        echo ""
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    # Associative array to store check results
    declare -A CHECK_RESULTS

    echo ""

    # Get check results from database
    local results
    results=$(get_check_results)

    # Parse results
    if [[ -n "${results}" ]]; then
        parse_check_results "${results}"
    fi

    # Generate summary table
    generate_summary_table

    # Generate detailed report (only for failed checks)
    local has_failed=0
    for check_type in "${CHECK_TYPES[@]}"; do
        local result="${CHECK_RESULTS[$check_type]:-}"
        if [[ -n "${result}" ]]; then
            IFS='|' read -r status duration_ms exit_code findings <<< "${result}"
            if [[ "${status}" == "failed" ]]; then
                has_failed=1
                break
            fi
        fi
    done

    if [[ ${has_failed} -eq 1 ]]; then
        generate_detailed_report
    fi

    # Display final verdict
    display_verdict

    return 0
}

# Run main function
main "$@"
