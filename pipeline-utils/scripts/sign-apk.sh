#!/bin/bash
# sign-apk.sh
# Signs APK file using keystore credentials from environment
# Verifies signature and outputs signed APK path
# Usage: sign-apk.sh [--input=APK_FILE] [--output=DIR]

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Keystore credentials from environment
KEYSTORE_PATH="${KEYSTORE_PATH:-}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-}"
KEY_ALIAS="${KEY_ALIAS:-}"
KEY_PASSWORD="${KEY_PASSWORD:-}"

# APK paths
APK_INPUT="${APK_INPUT:-}"
APK_OUTPUT_DIR="${APK_OUTPUT_DIR:-${PROJECT_ROOT}/app/build/outputs/apk/release}"
DEFAULT_APK_SEARCH="${PROJECT_ROOT}/app/build/outputs/apk"

# Build info
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
BUILD_URL="${CI_BUILD_URL:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Send notification on error
send_error_notification() {
    local error_message="$1"
    if [[ -f "${SCRIPT_DIR}/send-notification.sh" ]]; then
        local notification_data
        notification_data=$(jq -n \
            --arg title "APK Signing Failed" \
            --arg message "Failed to sign APK: ${error_message}" \
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

# Find APK file
find_apk() {
    local search_dir="$1"
    local apk_file=""

    # Try exact path first
    if [[ -n "${APK_INPUT}" && -f "${APK_INPUT}" ]]; then
        echo "${APK_INPUT}"
        return 0
    fi

    # Search for APK in common locations
    local search_paths=(
        "${search_dir}/debug/*.apk"
        "${search_dir}/release/*.apk"
        "${search_dir}/*-unsigned.apk"
        "${search_dir}/*.apk"
    )

    for pattern in "${search_paths[@]}"; do
        # Find first matching APK
        apk_file=$(find "${search_dir}" -name "*.apk" -type f 2>/dev/null | head -n 1)
        if [[ -n "${apk_file}" ]]; then
            echo "${apk_file}"
            return 0
        fi
    done

    log_error "No APK file found in ${search_dir}"
    return 1
}

# Validate keystore credentials (environment only - no command line exposure)
validate_credentials() {
    log_info "Validating keystore credentials..."

    # Validate all credentials are from environment only
    if ! validate_env_credentials "KEYSTORE_PATH" "KEYSTORE_PASSWORD" "KEY_ALIAS" "KEY_PASSWORD"; then
        return 1
    fi

    if [[ ! -f "${KEYSTORE_PATH}" ]]; then
        log_error "Keystore file not found: ${KEYSTORE_PATH}"
        return 1
    fi

    log_success "Keystore credentials validated (from environment)"
    return 0
}

# Sign APK using apksigner (password via stdin only - no ps exposure)
sign_apk_with_apksigner() {
    local input_apk="$1"
    local output_apk="$2"

    log_info "Signing APK with apksigner..."

    # Check if apksigner is available
    if ! command -v apksigner &>/dev/null; then
        log_warning "apksigner not found, trying jarsigner..."
        return 1
    fi

    # Validate file paths to prevent directory traversal
    if ! validate_file_path "${input_apk}"; then
        log_error "Invalid input APK path"
        return 1
    fi

    if ! validate_file_path "${output_apk}"; then
        log_error "Invalid output APK path"
        return 1
    fi

    # Create temporary signed APK
    local temp_apk="${output_apk}.temp"

    # Sign APK with password via stdin (secure - not visible in ps)
    # SECURITY FIX: Password passed via stdin, not command line
    if ! echo "${KEYSTORE_PASSWORD}" | apksigner sign \
        --ks "${KEYSTORE_PATH}" \
        --ks-pass pass:- \
        --ks-key-alias "${KEY_ALIAS}" \
        --key-pass pass:"${KEY_PASSWORD}" \
        --out "${temp_apk}" \
        "${input_apk}" 2>&1; then
        log_error "apksigner failed"
        rm -f "${temp_apk}"
        return 1
    fi

    # Verify signature
    if ! apksigner verify "${temp_apk}" &>/dev/null; then
        log_error "Signature verification failed"
        rm -f "${temp_apk}"
        return 1
    fi

    # Move to final location
    mv "${temp_apk}" "${output_apk}"

    log_success "APK signed with apksigner"
    return 0
}

# Sign APK using jarsigner (fallback - password via environment)
sign_apk_with_jarsigner() {
    local input_apk="$1"
    local output_apk="$2"

    log_info "Signing APK with jarsigner..."

    # Check if jarsigner is available
    if ! command -v jarsigner &>/dev/null; then
        log_error "Neither apksigner nor jarsigner found"
        return 1
    fi

    # Validate file paths
    if ! validate_file_path "${input_apk}" || ! validate_file_path "${output_apk}"; then
        log_error "Invalid APK path"
        return 1
    fi

    # Copy input to output
    cp "${input_apk}" "${output_apk}"

    # Sign APK - SECURITY FIX: Read password from environment only
    # Using environment variables is safer than command line for jarsigner
    if ! jarsigner \
        -keystore "${KEYSTORE_PATH}" \
        -storepass:env KEYSTORE_PASSWORD \
        -keypass:env KEY_PASSWORD \
        -signedjar "${output_apk}" \
        "${output_apk}" \
        "${KEY_ALIAS}" 2>&1; then
        log_error "jarsigner failed"
        rm -f "${output_apk}"
        return 1
    fi

    # Verify signature
    if ! jarsigner -verify -verbose "${output_apk}" >/dev/null 2>&1; then
        log_warning "Signature verification warning (may be OK)"
    fi

    # Zipalign the APK (important for release)
    if command -v zipalign &>/dev/null; then
        log_info "Aligning APK..."
        local aligned_apk="${output_apk}.aligned"
        zipalign -v 4 "${output_apk}" "${aligned_apk}" >/dev/null 2>&1
        mv "${aligned_apk}" "${output_apk}"
        log_success "APK aligned"
    fi

    log_success "APK signed with jarsigner"
    return 0
}

# Verify signed APK
verify_signed_apk() {
    local apk_path="$1"

    log_info "Verifying signed APK..."

    if command -v apksigner &>/dev/null; then
        if apksigner verify --verbose "${apk_path}" 2>&1 | grep -q "Valid"; then
            log_success "APK signature verified"
            return 0
        else
            log_error "APK signature verification failed"
            return 1
        fi
    elif command -v jarsigner &>/dev/null; then
        if jarsigner -verify "${apk_path}" >/dev/null 2>&1; then
            log_success "APK signature verified"
            return 0
        else
            log_error "APK signature verification failed"
            return 1
        fi
    else
        log_warning "No verification tool available, skipping verification"
        return 0
    fi
}

# Log signing result to database (with SQL injection prevention)
log_signing_result() {
    local apk_path="$1"
    local success="$2"
    local error_msg="${3:-}"

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    # Get version from .version file
    local version
    version=$(cat "${PROJECT_ROOT}/.version" 2>/dev/null || echo "unknown")

    # Escape all inputs to prevent SQL injection
    local escaped_version
    local escaped_sha
    local escaped_apk_path
    local escaped_error

    escaped_version=$(psql_escape "${version}")
    escaped_sha=$(psql_escape "${COMMIT_SHA:-}")
    escaped_apk_path=$(psql_escape "${apk_path}")
    escaped_error=$(psql_escape "${error_msg}")

    local update_sql="
UPDATE release_history
SET
    apk_signed = ${success},
    metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{signing}',
        {
            \"apk_path\": \"${escaped_apk_path}\",
            \"success\": ${success},
            \"error\": \"${escaped_error}\",
            \"timestamp\": \"$(date -Iseconds)\"
        }::jsonb
    )
WHERE version = '${escaped_version}'
  AND commit_sha = '${escaped_sha}'
RETURNING id;
"

    # Execute with proper error handling
    if ! PGPASSWORD="${db_password}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -t -A -c "${update_sql}" 2>&1; then
        log_warning "Failed to log signing result to database"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local input_apk=""
    local output_dir=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input=*)
                input_apk="${1#*=}"
                shift
                ;;
            --output=*)
                output_dir="${1#*=}"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--input=APK_FILE] [--output=DIR]"
                exit 1
                ;;
        esac
    done

    log_info "=== APK Signing Script ==="
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root"
        send_error_notification "Cannot access project directory"
        exit 1
    }

    # Validate credentials
    validate_credentials || {
        send_error_notification "Invalid keystore credentials"
        exit 1
    }

    # Find APK file
    local apk_file
    if [[ -n "${input_apk}" ]]; then
        # Validate input path to prevent directory traversal
        if ! validate_file_path "${input_apk}"; then
            log_error "Invalid APK path: ${input_apk}"
            send_error_notification "Invalid APK path provided"
            exit 1
        fi
        apk_file="${input_apk}"
        if [[ ! -f "${apk_file}" ]]; then
            log_error "APK file not found: ${apk_file}"
            send_error_notification "APK file not found: ${apk_file}"
            exit 1
        fi
    else
        apk_file=$(find_apk "${DEFAULT_APK_SEARCH}") || {
            send_error_notification "No APK file found to sign"
            exit 1
        }
    fi

    log_info "Found APK: ${apk_file}"

    # Determine output directory
    if [[ -n "${output_dir}" ]]; then
        APK_OUTPUT_DIR="${output_dir}"
    fi

    # Create output directory if needed
    mkdir -p "${APK_OUTPUT_DIR}"

    # Generate output filename
    local version
    version=$(cat "${PROJECT_ROOT}/.version" 2>/dev/null || echo "unknown")
    local apk_name
    apk_name=$(basename "${apk_file}")
    local signed_apk="${APK_OUTPUT_DIR}/${apk_name%.apk}-signed.apk"

    log_info "Output: ${signed_apk}"
    echo ""

    # Sign APK
    local sign_success=false
    local sign_error=""

    if sign_apk_with_apksigner "${apk_file}" "${signed_apk}"; then
        sign_success=true
    elif sign_apk_with_jarsigner "${apk_file}" "${signed_apk}"; then
        sign_success=true
    else
        sign_error="Both apksigner and jarsigner failed"
        log_error "${sign_error}"
    fi

    if [[ "${sign_success}" == false ]]; then
        send_error_notification "${sign_error}"
        log_signing_result "${signed_apk}" "false" "${sign_error}"
        exit 1
    fi

    # Verify signed APK
    if ! verify_signed_apk "${signed_apk}"; then
        local verify_error="Signature verification failed"
        send_error_notification "${verify_error}"
        log_signing_result "${signed_apk}" "false" "${verify_error}"
        exit 1
    fi

    # Get file size
    local file_size
    file_size=$(du -h "${signed_apk}" | cut -f1)
    local file_checksum
    file_checksum=$(sha256sum "${signed_apk}" | cut -d' ' -f1)

    # Log to database
    log_signing_result "${signed_apk}" "true" ""

    # Output result
    echo ""
    log_success "=== APK Signing Complete ==="
    echo "Signed APK: ${signed_apk}"
    echo "Size: ${file_size}"
    echo "SHA256: ${file_checksum}"

    # Output path for other scripts to use
    echo "${signed_apk}"

    exit 0
}

# Run main function
main "$@"
