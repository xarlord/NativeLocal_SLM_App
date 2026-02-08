#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check SQL Injection Fixes
check_sql_injection_fixes() {
    echo "Checking for SQL injection vulnerabilities..."

    local vulnerable_scripts=()
    local scripts=(
        "pipeline-utils/scripts/bump-version.sh"
        "pipeline-utils/scripts/generate-changelog.sh"
        "pipeline-utils/scripts/sign-apk.sh"
        "pipeline-utils/scripts/create-github-release.sh"
        "pipeline-utils/scripts/deploy-play-store.sh"
        "pipeline-utils/scripts/validate-release.sh"
        "pipeline-utils/scripts/create-branch.sh"
        "pipeline-utils/scripts/apply-dependency-update.sh"
        "pipeline-utils/scripts/apply-refactoring.sh"
        "pipeline-utils/scripts/create-pr.sh"
        "pipeline-utils/scripts/request-review.sh"
        "pipeline-utils/scripts/auto-merge-check.sh"
        "pipeline-utils/scripts/list-branches.sh"
        "pipeline-utils/scripts/detect-stale-branches.sh"
        "pipeline-utils/scripts/delete-merged-branches.sh"
        "pipeline-utils/scripts/warn-stale-branches.sh"
        "pipeline-utils/scripts/enforce-branch-strategy.sh"
        "pipeline-utils/scripts/update-branch-status.sh"
        "pipeline-utils/scripts/classify-issue.sh"
        "pipeline-utils/scripts/detect-duplicates.sh"
        "pipeline-utils/scripts/assign-issue.sh"
        "pipeline-utils/scripts/link-issues-to-commits.sh"
        "pipeline-utils/scripts/estimate-complexity.sh"
        "pipeline-utils/scripts/generate-issue-report.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            continue
        fi

        # Check for psql with unescaped variables
        if grep -E 'psql.*\$[a-zA-Z_]+\]' "$script" | grep -v "psql_escape" | grep -v "#" | grep -q "."; then
            vulnerable_scripts+=("$script (possible SQL injection)")
        fi
    done

    if [[ ${#vulnerable_scripts[@]} -gt 0 ]]; then
        echo "[FAIL] Found potential SQL injection in:"
        printf '  - %s\n' "${vulnerable_scripts[@]}"
        return 1
    else
        echo "[PASS] No SQL injection vulnerabilities found"
        return 0
    fi
}

# Check Password Exposure
check_password_exposure() {
    echo "Checking for password exposure..."

    # Check sign-apk.sh
    if [[ -f "pipeline-utils/scripts/sign-apk.sh" ]]; then
        if grep -E '(--ks-pass|--key-pass|-p)' "pipeline-utils/scripts/sign-apk.sh" | grep -q '\$'; then
            echo "[FAIL] Password may be passed as command-line argument in sign-apk.sh"
            return 1
        else
            echo "[PASS] Passwords not exposed in command line"
            return 0
        fi
    else
        echo "[WARN] sign-apk.sh not found, skipping password check"
        return 0
    fi
}

# Check Input Validation
check_input_validation() {
    echo "Checking for input validation..."

    local scripts_missing_validation=()

    # Check if scripts validate file paths
    for script in pipeline-utils/scripts/*.sh; do
        if [[ ! -f "$script" ]]; then
            continue
        fi

        # Skip self
        if [[ "$(basename "$script")" == "validate-security-fixes.sh" ]]; then
            continue
        fi

        # Check if script uses file paths without validation
        if grep -E '(\$[a-z_]+_path|\$\{[a-z_]+_path\})' "$script" | grep -q "validate_file_path"; then
            :  # Has validation
        else
            # Check if file path is used anywhere
            if grep -qE '(_path|_file).*=' "$script"; then
                scripts_missing_validation+=("$script")
            fi
        fi
    done

    if [[ ${#scripts_missing_validation[@]} -gt 0 ]]; then
        echo "[WARN] Scripts without file path validation:"
        printf '  - %s\n' "${scripts_missing_validation[@]}"
        return 0  # Warning, not failure
    else
        echo "[PASS] Input validation present"
        return 0
    fi
}

# Check for Backup Mechanisms
check_backup_mechanisms() {
    echo "Checking for backup mechanisms..."

    # Check delete-merged-branches.sh
    if [[ -f "pipeline-utils/scripts/delete-merged-branches.sh" ]]; then
        if grep -q "backup" "pipeline-utils/scripts/delete-merged-branches.sh"; then
            echo "[PASS] Branch deletion has backup mechanism"
            return 0
        else
            echo "[FAIL] Branch deletion missing backup mechanism"
            return 1
        fi
    else
        echo "[WARN] delete-merged-branches.sh not found, skipping backup check"
        return 0
    fi
}

# Generate Security Report
generate_security_report() {
    echo "=== Security Fix Validation Report ==="
    echo ""
    echo "Date: $(date)"
    echo ""

    echo "## SQL Injection Status"
    check_sql_injection_fixes
    local sql_status=$?
    echo ""

    echo "## Password Exposure Status"
    check_password_exposure
    local password_status=$?
    echo ""

    echo "## Input Validation Status"
    check_input_validation
    local input_status=$?
    echo ""

    echo "## Backup Mechanism Status"
    check_backup_mechanisms
    local backup_status=$?
    echo ""

    # Summary
    local total_checks=3
    local passed=0

    # Count passes (input_validation is warning only)
    [[ $sql_status -eq 0 ]] && ((passed++))
    [[ $password_status -eq 0 ]] && ((passed++))
    [[ $backup_status -eq 0 ]] && ((passed++))

    echo "=== Summary ==="
    echo "Critical Checks Passed: $passed / $total_checks"

    if [[ $passed -eq $total_checks ]]; then
        echo -e "${GREEN}Status: [PASS] All critical checks passed${NC}"
        return 0
    else
        echo -e "${RED}Status: [FAIL] Some checks failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting security fix validation..."
    echo ""

    generate_security_report

    local exit_code=$?
    echo ""

    if [[ $exit_code -eq 0 ]]; then
        log_info "Security validation completed successfully"
    else
        log_error "Security validation found issues"
    fi

    return $exit_code
}

# Run main function
main "$@"
