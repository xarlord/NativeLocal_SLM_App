#!/bin/bash
# verify-windows-compatibility.sh
# Quick verification script for Windows compatibility fixes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

# Track results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check() {
    local description="$1"
    local command="$2"

    ((TOTAL_CHECKS++))
    log "Checking: ${description}"

    if eval "$command" >/dev/null 2>&1; then
        log_success "${description}"
        ((PASSED_CHECKS++))
        return 0
    else
        log_error "${description}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

echo ""
log "=== Windows Compatibility Verification ==="
echo ""

# Detect OS
OS_TYPE=$(case "$(uname -s)" in
    Linux*)     echo "linux" ;;
    Darwin*)    echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)          echo "unknown" ;;
esac)

log "Detected OS: ${OS_TYPE}"
echo ""

# Check 1: Timeout command handling in pre-commit scripts
log "Checking timeout command handling..."
check "pre-commit-format.sh has timeout detection" "grep -q 'command -v timeout' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh has timeout detection" "grep -q 'command -v timeout' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh has timeout detection" "grep -q 'command -v timeout' '${SCRIPT_DIR}/pre-commit-tests.sh'"
echo ""

# Check 2: Reduced timeouts
log "Checking timeout values..."
check "pre-commit-format.sh uses 30s timeout" "grep -q 'format_timeout=.*30' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh uses 60s timeout" "grep -q 'lint_timeout=.*60' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh uses 30s timeout" "grep -q 'TEST_TIMEOUT=30' '${SCRIPT_DIR}/pre-commit-tests.sh'"
echo ""

# Check 3: Temp directory handling
log "Checking temp directory handling..."
check "pre-commit-secrets.sh has get_temp_dir function" "grep -q 'get_temp_dir()' '${SCRIPT_DIR}/pre-commit-secrets.sh'"
check "pre-commit-secrets.sh uses TEMP_DIR variable" "grep -q 'TEMP_DIR=\$(get_temp_dir)' '${SCRIPT_DIR}/pre-commit-secrets.sh'"
check "pre-commit-secrets.sh creates temp directory" "grep -q 'mkdir -p.*TEMP_DIR' '${SCRIPT_DIR}/pre-commit-secrets.sh'"
echo ""

# Check 4: Gradle wrapper detection
log "Checking Gradle wrapper detection..."
check "pre-commit-format.sh checks for gradlew.bat" "grep -q 'gradlew.bat' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh checks for gradlew.bat" "grep -q 'gradlew.bat' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh checks for gradlew.bat" "grep -q 'gradlew.bat' '${SCRIPT_DIR}/pre-commit-tests.sh'"
echo ""

# Check 5: Windows-specific chmod handling
log "Checking Windows-specific chmod handling..."
check "install-hooks.sh skips chmod on Windows" "grep -q 'chmod.*windows' '${SCRIPT_DIR}/install-hooks.sh'"
check "pre-commit-format.sh skips chmod on Windows" "grep -q 'chmod.*windows' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh skips chmod on Windows" "grep -q 'chmod.*windows' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh skips chmod on Windows" "grep -q 'chmod.*windows' '${SCRIPT_DIR}/pre-commit-tests.sh'"
echo ""

# Check 6: Platform-specific gradle commands
log "Checking platform-specific Gradle commands..."
check "pre-commit-format.sh uses gradle_cmd variable" "grep -q 'gradle_cmd=.*gradlew' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh uses gradle_cmd variable" "grep -q 'gradle_cmd=.*gradlew' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh uses gradle_cmd variable" "grep -q 'gradle_cmd=.*gradlew' '${SCRIPT_DIR}/pre-commit-tests.sh'"
echo ""

# Check 7: OS detection functions
log "Checking OS detection functions..."
check "pre-commit-format.sh has detect_os function" "grep -q 'detect_os()' '${SCRIPT_DIR}/pre-commit-format.sh'"
check "pre-commit-lint.sh has detect_os function" "grep -q 'detect_os()' '${SCRIPT_DIR}/pre-commit-lint.sh'"
check "pre-commit-tests.sh has detect_os function" "grep -q 'detect_os()' '${SCRIPT_DIR}/pre-commit-tests.sh'"
check "pre-commit-secrets.sh has detect_os function" "grep -q 'detect_os()' '${SCRIPT_DIR}/pre-commit-secrets.sh'"
check "install-hooks.sh has detect_os function" "grep -q 'detect_os()' '${SCRIPT_DIR}/install-hooks.sh'"
echo ""

# Summary
echo ""
log "=== Verification Summary ==="
echo ""
log "Total Checks: ${TOTAL_CHECKS}"
log_success "Passed: ${PASSED_CHECKS}"
if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    log_error "Failed: ${FAILED_CHECKS}"
else
    log_success "Failed: ${FAILED_CHECKS}"
fi
echo ""

if [[ ${FAILED_CHECKS} -eq 0 ]]; then
    log_success "All Windows compatibility fixes verified!"
    echo ""
    log "The following scripts are ready for Windows Git Bash:"
    echo "  - install-hooks.sh"
    echo "  - pre-commit-format.sh"
    echo "  - pre-commit-lint.sh"
    echo "  - pre-commit-tests.sh"
    echo "  - pre-commit-secrets.sh"
    echo "  - pre-commit-summary.sh"
    echo ""
    exit 0
else
    log_error "Some checks failed. Please review the errors above."
    exit 1
fi
