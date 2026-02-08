#!/bin/bash
# validate-release.sh
# Pre-release validation checks
# Validates version format, changelog, APK, tests, and git state
# Usage: validate-release.sh [--skip-tests] [--strict]

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Version file
VERSION_FILE="${PROJECT_ROOT}/.version"
CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"

# APK search paths
APK_SEARCH_PATHS=(
    "${PROJECT_ROOT}/app/build/outputs/apk/release/*-signed.apk"
    "${PROJECT_ROOT}/app/build/outputs/apk/debug/*.apk"
    "${PROJECT_ROOT}/app/build/outputs/apk/*.apk"
)

# Test command
TEST_COMMAND="${TEST_COMMAND:-./gradlew test}"

# Build info
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation state
VALIDATION_FAILED=0
STRICT_MODE=false
SKIP_TESTS=false

# ============================================
# Security Utilities
# ============================================

# Source security utilities for input validation and SQL escaping
if [[ -f "${SCRIPT_DIR}/security-utils.sh" ]]; then
    source "${SCRIPT_DIR}/security-utils.sh"
else
    log_error "security-utils.sh not found"
    exit 1
fi

# ============================================
# Helper Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1..."
}

# Send notification on error
send_error_notification() {
    local error_message="$1"
    if [[ -f "${SCRIPT_DIR}/send-notification.sh" ]]; then
        local notification_data
        notification_data=$(jq -n \
            --arg title "Release Validation Failed" \
            --arg message "Pre-release validation failed: ${error_message}" \
            --arg severity "high" \
            --arg category "release" \
            --arg error_message "${error_message}" \
            '{
                title: $title,
                message: $message,
                severity: $severity,
                category: $category,
                error_message: $error_message,
                metadata: {
                    build_id: env.BUILD_ID,
                    commit_sha: env.COMMIT_SHA
                }
            }')
        echo "${notification_data}" | "${SCRIPT_DIR}/send-notification.sh" /dev/stdin || true
    fi
}

# Check if .version file exists
check_version_file() {
    log_check "Version file exists"

    if [[ ! -f "${VERSION_FILE}" ]]; then
        log_error ".version file not found at ${VERSION_FILE}"
        return 1
    fi

    log_success "Version file found"
    return 0
}

# Validate semver format (using security utils)
validate_version_format() {
    log_check "Version format (semver)"

    if [[ ! -f "${VERSION_FILE}" ]]; then
        log_error "Cannot validate version: file not found"
        return 1
    fi

    local version
    version=$(cat "${VERSION_FILE}" | tr -d '[:space:]')

    # Use security utility for validation
    if ! validate_semver "${version}"; then
        log_error "Invalid semver format: ${version}"
        log_error "Expected format: X.Y.Z (e.g., 1.0.0)"
        return 1
    fi

    log_success "Version format valid: ${version}"
    return 0
}

# Check git tag exists (with validation)
check_git_tag() {
    log_check "Git tag exists"

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi

    local version
    version=$(cat "${VERSION_FILE}" | tr -d '[:space:]')
    local tag_name="v${version}"

    # Validate tag format using security utils
    if ! validate_git_tag "${tag_name}"; then
        log_error "Invalid git tag format: ${tag_name}"
        return 1
    fi

    if ! git rev-parse "${tag_name}" >/dev/null 2>&1; then
        log_warning "Git tag ${tag_name} does not exist"
        if [[ "${STRICT_MODE}" == true ]]; then
            return 1
        fi
        return 0
    fi

    log_success "Git tag exists: ${tag_name}"
    return 0
}

# Check for uncommitted changes
check_git_state() {
    log_check "No uncommitted changes"

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warning "Not in a git repository, skipping git state check"
        return 0
    fi

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        log_error "Uncommitted changes detected"
        git status --short
        return 1
    fi

    log_success "No uncommitted changes"
    return 0
}

# Check if changelog exists
check_changelog_exists() {
    log_check "CHANGELOG.md exists"

    if [[ ! -f "${CHANGELOG_FILE}" ]]; then
        log_error "CHANGELOG.md not found at ${CHANGELOG_FILE}"
        return 1
    fi

    log_success "CHANGELOG.md found"
    return 0
}

# Validate changelog has current version
validate_changelog() {
    log_check "CHANGELOG.md has current version entry"

    if [[ ! -f "${CHANGELOG_FILE}" ]]; then
        log_error "Cannot validate changelog: file not found"
        return 1
    fi

    local version
    version=$(cat "${VERSION_FILE}" | tr -d '[:space:]')

    if ! grep -q "## \[${version}\]" "${CHANGELOG_FILE}"; then
        log_error "No entry found for version ${version} in CHANGELOG.md"
        return 1
    fi

    log_success "CHANGELOG.md has entry for ${version}"
    return 0
}

# Check if APK exists (with path validation)
check_apk_exists() {
    log_check "APK file exists"

    local found=false

    for pattern in "${APK_SEARCH_PATHS[@]}"; do
        # Expand glob
        for apk in $pattern; do
            if [[ -f "${apk}" ]]; then
                # Validate APK path to prevent directory traversal
                if validate_file_path "${apk}"; then
                    log_success "APK found: ${apk}"
                    found=true
                    break 2
                else
                    log_warning "Skipping APK with suspicious path: ${apk}"
                fi
            fi
        done
    done

    if [[ "${found}" == false ]]; then
        log_error "No APK file found"
        log_error "Searched paths:"
        for pattern in "${APK_SEARCH_PATHS[@]}"; do
            echo "  - ${pattern}"
        done
        return 1
    fi

    return 0
}

# Validate APK signature
validate_apk_signature() {
    log_check "APK is signed"

    local apk_file=""
    local found=false

    # Find APK file
    for pattern in "${APK_SEARCH_PATHS[@]}"; do
        for apk in $pattern; do
            if [[ -f "${apk}" ]]; then
                apk_file="${apk}"
                found=true
                break 2
            fi
        done
    done

    if [[ "${found}" == false ]]; then
        log_warning "No APK found, skipping signature check"
        return 0
    fi

    # Check if apksigner is available
    if command -v apksigner &>/dev/null; then
        if apksigner verify "${apk_file}" &>/dev/null; then
            log_success "APK signature verified"
            return 0
        else
            log_error "APK signature verification failed"
            return 1
        fi
    # Fallback to jarsigner
    elif command -v jarsigner &>/dev/null; then
        if jarsigner -verify "${apk_file}" >/dev/null 2>&1; then
            log_success "APK signature verified"
            return 0
        else
            log_error "APK signature verification failed"
            return 1
        fi
    else
        log_warning "No signature verification tool available, skipping check"
        return 0
    fi
}

# Run tests
run_tests() {
    if [[ "${SKIP_TESTS}" == true ]]; then
        log_warning "Skipping tests (--skip-tests flag)"
        return 0
    fi

    log_check "Tests pass"

    if [[ -z "${TEST_COMMAND}" ]]; then
        log_warning "No test command configured, skipping"
        return 0
    fi

    log_info "Running: ${TEST_COMMAND}"

    if eval "${TEST_COMMAND}"; then
        log_success "Tests passed"
        return 0
    else
        log_error "Tests failed"
        return 1
    fi
}

# Check for required environment variables
check_environment() {
    log_check "Required environment variables"

    local missing_vars=()
    local required_vars=()

    # Add variables based on what's needed
    if [[ -f "${PROJECT_ROOT}/app/build.gradle" ]] || \
       [[ -f "${PROJECT_ROOT}/app/build.gradle.kts" ]]; then
        # Android project - may need signing keys
        required_vars+=("KEYSTORE_PATH" "KEYSTORE_PASSWORD" "KEY_ALIAS" "KEY_PASSWORD")
    fi

    # Check variables
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warning "Missing environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - ${var}"
        done
        if [[ "${STRICT_MODE}" == true ]]; then
            return 1
        fi
    fi

    log_success "Environment variables checked"
    return 0
}

# Display summary
display_summary() {
    echo ""
    echo "========================================="
    if [[ ${VALIDATION_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All validations passed!${NC}"
    else
        echo -e "${RED}Some validations failed${NC}"
    fi
    echo "========================================="
}

# ============================================
# Main Execution
# ============================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--skip-tests] [--strict]"
                exit 1
                ;;
        esac
    done

    log_info "=== Release Validation ==="
    if [[ "${STRICT_MODE}" == true ]]; then
        log_info "Strict mode enabled"
    fi
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root"
        exit 1
    }

    # Run all validation checks
    # Note: Each check that fails sets VALIDATION_FAILED=1

    # Version checks
    if ! check_version_file; then
        VALIDATION_FAILED=1
    fi

    if ! validate_version_format; then
        VALIDATION_FAILED=1
    fi

    # Git checks
    if ! check_git_tag; then
        VALIDATION_FAILED=1
    fi

    if ! check_git_state; then
        VALIDATION_FAILED=1
    fi

    # Changelog checks
    if ! check_changelog_exists; then
        VALIDATION_FAILED=1
    fi

    if ! validate_changelog; then
        VALIDATION_FAILED=1
    fi

    # APK checks
    if ! check_apk_exists; then
        VALIDATION_FAILED=1
    fi

    if ! validate_apk_signature; then
        VALIDATION_FAILED=1
    fi

    # Environment check
    if ! check_environment; then
        VALIDATION_FAILED=1
    fi

    # Run tests
    if ! run_tests; then
        VALIDATION_FAILED=1
    fi

    # Display summary
    display_summary

    # Send notification if failed
    if [[ ${VALIDATION_FAILED} -ne 0 ]]; then
        send_error_notification "Release validation failed with ${VALIDATION_FAILED} error(s)"
    fi

    # Exit with appropriate code
    if [[ ${VALIDATION_FAILED} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
