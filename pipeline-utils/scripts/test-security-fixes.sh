#!/bin/bash
# test-security-fixes.sh
# Quick verification tests for security fixes
# Usage: ./test-security-fixes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

tests_passed=0
tests_failed=0

test_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((tests_passed++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((tests_failed++))
}

test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test 1: Security utils exist and are sourced
test_header "Test 1: Security Utilities"

if [[ -f "${SCRIPT_DIR}/security-utils.sh" ]]; then
    test_pass "security-utils.sh exists"
else
    test_fail "security-utils.sh not found"
    exit 1
fi

# Source security utils
source "${SCRIPT_DIR}/security-utils.sh"

# Test 2: SQL escaping function
test_header "Test 2: SQL Injection Prevention"

# Test normal input
normal_escaped=$(psql_escape "1.2.3")
if [[ "${normal_escaped}" == "1.2.3" ]]; then
    test_pass "Normal version escapes correctly"
else
    test_fail "Normal version escaping failed"
fi

# Test malicious input
malicious_escaped=$(psql_escape "1.2.3'; DROP TABLE users; --")
if [[ "${malicious_escaped}" == "1.2.3''; DROP TABLE users; --" ]]; then
    test_pass "SQL injection attempt escaped correctly"
else
    test_fail "SQL injection escaping failed"
fi

# Test 3: Input validation
test_header "Test 3: Input Validation"

# Valid semver
if validate_semver "1.2.3"; then
    test_pass "Valid semver accepted"
else
    test_fail "Valid semver rejected"
fi

# Invalid semver
if ! validate_semver "invalid"; then
    test_pass "Invalid semver rejected"
else
    test_fail "Invalid semver accepted"
fi

# Valid tag
if validate_git_tag "v1.2.3"; then
    test_pass "Valid git tag accepted"
else
    test_fail "Valid git tag rejected"
fi

# Invalid tag
if ! validate_git_tag "tag with spaces"; then
    test_pass "Invalid git tag rejected"
else
    test_fail "Invalid git tag accepted"
fi

# Valid GitHub repo
if validate_github_repo "owner/repo"; then
    test_pass "Valid GitHub repo accepted"
else
    test_fail "Valid GitHub repo rejected"
fi

# Invalid GitHub repo
if ! validate_github_repo "invalid-repo"; then
    test_pass "Invalid GitHub repo rejected"
else
    test_fail "Invalid GitHub repo accepted"
fi

# Test 4: Path validation
test_header "Test 4: Path Validation (Directory Traversal Prevention)"

# Valid path
if validate_file_path "/path/to/file.apk"; then
    test_pass "Valid path accepted"
else
    test_fail "Valid path rejected"
fi

# Directory traversal attempt
if ! validate_file_path "../../../etc/passwd"; then
    test_pass "Directory traversal blocked"
else
    test_fail "Directory traversal not blocked"
fi

# Null byte attempt
if ! validate_file_path "/path/file\x00.apk"; then
    test_pass "Null byte in path blocked"
else
    test_fail "Null byte in path not blocked"
fi

# Test 5: Password environment validation
test_header "Test 5: Password Security"

# Test with password set
export TEST_PASSWORD="secret123"
if check_password_env "TEST_PASSWORD"; then
    test_pass "Password from environment detected"
else
    test_fail "Password from environment not detected"
fi
unset TEST_PASSWORD

# Test without password
if ! check_password_env "TEST_PASSWORD"; then
    test_pass "Missing password detected"
else
    test_fail "Missing password not detected"
fi

# Test 6: Scripts source security utils
test_header "Test 6: Script Security Integration"

scripts_to_check=(
    "bump-version.sh"
    "generate-changelog.sh"
    "sign-apk.sh"
    "create-github-release.sh"
    "deploy-play-store.sh"
    "validate-release.sh"
)

for script in "${scripts_to_check[@]}"; do
    script_path="${SCRIPT_DIR}/${script}"
    if [[ -f "${script_path}" ]]; then
        if grep -q 'source "${SCRIPT_DIR}/security-utils.sh"' "${script_path}" || \
           grep -q "source \${SCRIPT_DIR}/security-utils.sh" "${script_path}"; then
            test_pass "${script} sources security-utils.sh"
        else
            test_fail "${script} does NOT source security-utils.sh"
        fi
    else
        test_warn "${script} not found (skipping test)"
    fi
done

# Test 7: Check for password exposure in sign-apk.sh
test_header "Test 7: Password Exposure Check (sign-apk.sh)"

sign_apk_path="${SCRIPT_DIR}/sign-apk.sh"
if [[ -f "${sign_apk_path}" ]]; then
    # Check for unsafe password passing
    if grep -q '\-\-ks-pass.*pass:\${KEYSTORE_PASSWORD}' "${sign_apk_path}"; then
        test_fail "sign-apk.sh STILL exposes password in command line"
    else
        test_pass "sign-apk.sh does not expose password in command line"
    fi

    # Check for safe password passing (stdin)
    if grep -q 'pass:-' "${sign_apk_path}" || grep -q ':env KEYSTORE_PASSWORD' "${sign_apk_path}"; then
        test_pass "sign-apk.sh uses safe password passing (stdin/env)"
    else
        test_fail "sign-apk.sh does not use safe password passing"
    fi
else
    test_warn "sign-apk.sh not found (skipping test)"
fi

# Test 8: Check for SQL escaping usage
test_header "Test 8: SQL Escaping Usage Check"

for script in "bump-version.sh" "generate-changelog.sh" "create-github-release.sh" "deploy-play-store.sh" "sign-apk.sh"; do
    script_path="${SCRIPT_DIR}/${script}"
    if [[ -f "${script_path}" ]]; then
        if grep -q 'psql_escape' "${script_path}"; then
            test_pass "${script} uses SQL escaping"
        else
            test_fail "${script} does NOT use SQL escaping"
        fi
    fi
done

# Test 9: Check for silent database failures
test_header "Test 9: Silent Failure Prevention"

for script in "bump-version.sh" "generate-changelog.sh" "create-github-release.sh" "deploy-play-store.sh" "sign-apk.sh"; do
    script_path="${SCRIPT_DIR}/${script}"
    if [[ -f "${script_path}" ]]; then
        # Check if script still has silent failures (2>/dev/null || true)
        if grep -q 'psql.*2>/dev/null.*|| true' "${script_path}"; then
            test_fail "${script} STILL has silent database failures"
        else
            test_pass "${script} does not have silent database failures"
        fi
    fi
done

# Test 10: Check for race condition prevention
test_header "Test 10: Race Condition Prevention"

bump_version_path="${SCRIPT_DIR}/bump-version.sh"
if [[ -f "${bump_version_path}" ]]; then
    if grep -q 'create_git_tag_safe' "${bump_version_path}"; then
        test_pass "bump-version.sh uses safe git tag creation"
    else
        test_fail "bump-version.sh does NOT use safe git tag creation"
    fi
else
    test_warn "bump-version.sh not found (skipping test)"
fi

# Summary
test_header "Test Summary"
echo ""
echo -e "${GREEN}Tests Passed: ${tests_passed}${NC}"
echo -e "${RED}Tests Failed: ${tests_failed}${NC}"
echo ""

if [[ ${tests_failed} -eq 0 ]]; then
    echo -e "${GREEN}All security tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some security tests failed. Please review.${NC}"
    exit 1
fi
