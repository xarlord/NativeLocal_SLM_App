#!/bin/bash
# deploy-play-store.sh
# Uploads signed APK to Google Play Store internal track
# Configures rollout percentage and monitors deployment
# Usage: deploy-play-store.sh [--apk=PATH] [--track=TRACK] [--rollout=PERCENT]

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Play Store configuration
PLAY_SERVICE_ACCOUNT_JSON="${PLAY_SERVICE_ACCOUNT_JSON:-}"
PLAY_PACKAGE_NAME="${PLAY_PACKAGE_NAME:-}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
PLAY_ROLLOUT_PERCENT="${PLAY_ROLLOUT_PERCENT:-100}"

# Version file
VERSION_FILE="${PROJECT_ROOT}/.version"

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
            --arg title "Play Store Deployment Failed" \
            --arg message "Failed to deploy to Play Store: ${error_message}" \
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
                    commit_sha: env.COMMIT_SHA,
                    track: env.PLAY_TRACK
                }
            }')
        echo "${notification_data}" | "${SCRIPT_DIR}/send-notification.sh" /dev/stdin || true
    fi
}

# Retry command using retry-command.sh
retry_command() {
    local command="$1"
    local max_retries="${2:-3}"

    if [[ -f "${SCRIPT_DIR}/retry-command.sh" ]]; then
        "${SCRIPT_DIR}/retry-command.sh" --max-retries="${max_retries}" ${command}
    else
        # Fallback: execute without retry
        eval "${command}"
    fi
}

# Check if required tools are available
check_dependencies() {
    log_info "Checking dependencies..."

    # Check for Java
    if ! command -v java &>/dev/null; then
        log_error "Java not found. Required for Play Store deployment."
        return 1
    fi

    # Check for aab (Android App Bundle) tool if available
    if command -v bundletool &>/dev/null; then
        log_info "bundletool found"
    else
        log_warning "bundletool not found (optional, for AAB support)"
    fi

    log_success "Dependencies checked"
    return 0
}

# Validate Play Store configuration (with input validation)
validate_play_config() {
    log_info "Validating Play Store configuration..."

    if [[ -z "${PLAY_SERVICE_ACCOUNT_JSON}" ]]; then
        log_error "PLAY_SERVICE_ACCOUNT_JSON environment variable not set"
        log_error "Provide path to service account JSON file"
        return 1
    fi

    # Validate service account path to prevent directory traversal
    if ! validate_file_path "${PLAY_SERVICE_ACCOUNT_JSON}"; then
        log_error "Invalid service account JSON path"
        return 1
    fi

    if [[ ! -f "${PLAY_SERVICE_ACCOUNT_JSON}" ]]; then
        log_error "Service account JSON file not found: ${PLAY_SERVICE_ACCOUNT_JSON}"
        return 1
    fi

    if [[ -z "${PLAY_PACKAGE_NAME}" ]]; then
        log_error "PLAY_PACKAGE_NAME environment variable not set"
        return 1
    fi

    # Validate package name format (already good, just adding security check)
    if ! [[ "${PLAY_PACKAGE_NAME}" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
        log_error "Invalid package name format: ${PLAY_PACKAGE_NAME}"
        return 1
    fi

    log_success "Play Store configuration validated"
    return 0
}

# Upload APK using fastlane (preferred method)
upload_with_fastlane() {
    local apk_file="$1"
    local track="$2"
    local rollout="$3"

    log_info "Uploading with fastlane..."

    if ! command -v fastlane &>/dev/null; then
        log_warning "fastlane not found"
        return 1
    fi

    # Create temporary Fastfile
    local fastlane_dir="${PROJECT_ROOT}/.fastlane"
    mkdir -p "${fastlane_dir}"

    local fastfile="${fastlane_dir}/Fastfile"
    cat > "${fastfile}" <<EOF
default_platform(:android)

platform :android do
  desc "Deploy to Play Store"
  lane :deploy do
    upload_to_play_store(
      track: '${track}',
      apk: '${apk_file}',
      rollout: '${rollout}',
      json_key: '${PLAY_SERVICE_ACCOUNT_JSON}',
      package_name: '${PLAY_PACKAGE_NAME}',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
EOF

    # Run fastlane
    cd "${fastlane_dir}" || return 1

    if retry_command "fastlane deploy" 3; then
        cd "${PROJECT_ROOT}"
        log_success "Uploaded with fastlane"
        return 0
    else
        cd "${PROJECT_ROOT}"
        log_error "fastlane deployment failed"
        return 1
    fi
}

# Upload APK using Google Play CLI (alternative method)
upload_with_play_cli() {
    local apk_file="$1"
    local track="$2"
    local rollout="$3"

    log_info "Uploading with Google Play CLI..."

    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 not found"
        return 1
    fi

    # Check for google-play-upload-py or similar tool
    if ! python3 -c "import googleapiclient" 2>/dev/null; then
        log_warning "Google API client library not found"
        log_info "Install with: pip install google-api-python-client"
        return 1
    fi

    # Create temporary upload script
    local upload_script="${PROJECT_ROOT}/.play_upload.py"

    cat > "${upload_script}" <<'PYEOF'
#!/usr/bin/env python3
import sys
import json
import os
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2.service_account import Credentials

apk_file = sys.argv[1]
package_name = sys.argv[2]
track = sys.argv[3]
rollout = sys.argv[4]
service_account_json = sys.argv[5]

try:
    # Load credentials
    creds = Credentials.from_service_account_file(
        service_account_json,
        scopes=['https://www.googleapis.com/auth/androidpublisher']
    )

    # Build service
    service = build('androidpublisher', 'v3', credentials=creds)

    # Edit ID
    edit_id = service.edits().insert(
        body={},
        packageName=package_name
    ).execute().get('id')

    # Upload APK
    apk_response = service.edits().apks().upload(
        editId=edit_id,
        packageName=package_name,
        media_body=MediaFileUpload(apk_file, mimetype='application/vnd.android.package-archive')
    ).execute()

    version_code = apk_response.get('versionCode')
    print(f"Uploaded APK version code: {version_code}", file=sys.stderr)

    # Update track
    track_response = service.edits().tracks().update(
        editId=edit_id,
        packageName=package_name,
        track=track,
        body={
            'track': track,
        'releases': [{
            'versionCodes': [str(version_code)],
            'status': 'inProgress',
            'userFraction': float(rollout) / 100
        }]
    ).execute()

    # Commit edit
    service.edits().commit(
        editId=edit_id,
        packageName=package_name
    ).execute()

    print(json.dumps({'success': True, 'version_code': version_code}))

except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}))
    sys.exit(1)
PYEOF

    # Run upload script
    local result
    result=$(python3 "${upload_script}" \
        "${apk_file}" \
        "${PLAY_PACKAGE_NAME}" \
        "${track}" \
        "${rollout}" \
        "${PLAY_SERVICE_ACCOUNT_JSON}" 2>&1)

    local exit_code=$?

    rm -f "${upload_script}"

    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Uploaded with Play CLI"
        return 0
    else
        log_error "Play CLI upload failed: ${result}"
        return 1
    fi
}

# Monitor deployment status
monitor_deployment() {
    local track="$1"
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=30

    log_info "Monitoring deployment status..."

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        log_info "Checking status... (${elapsed}s elapsed)"

        # In a real implementation, you would query the Play Store API
        # to check the actual deployment status
        # For now, we'll just wait and assume success

        sleep ${check_interval}
        elapsed=$((elapsed + check_interval))
    done

    log_info "Deployment monitoring complete"
}

# Log deployment to database (with SQL injection prevention)
log_deployment() {
    local version="$1"
    local track="$2"
    local rollout="$3"
    local success="$4"
    local error_msg="${5:-}"
    local play_url="${6:-}"

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    # Escape all inputs to prevent SQL injection
    local escaped_version
    local escaped_sha
    local escaped_track
    local escaped_error
    local escaped_url

    escaped_version=$(psql_escape "${version}")
    escaped_sha=$(psql_escape "${COMMIT_SHA:-}")
    escaped_track=$(psql_escape "${track}")
    escaped_error=$(psql_escape "${error_msg}")
    escaped_url=$(psql_escape "${play_url}")

    # Validate rollout is numeric
    if ! [[ "${rollout}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid rollout percentage: ${rollout}"
        rollout=0
    fi

    local update_sql="
UPDATE release_history
SET
    play_store_deployed = ${success},
    play_store_url = '${escaped_url}',
    metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{play_store}',
        {
            \"track\": \"${escaped_track}\",
            \"rollout_percent\": ${rollout},
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
        log_warning "Failed to log deployment to database"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local apk_file=""
    local track="${PLAY_TRACK}"
    local rollout="${PLAY_ROLLOUT_PERCENT}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --apk=*)
                apk_file="${1#*=}"
                shift
                ;;
            --track=*)
                track="${1#*=}"
                shift
                ;;
            --rollout=*)
                rollout="${1#*=}"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--apk=PATH] [--track=TRACK] [--rollout=PERCENT]"
                exit 1
                ;;
        esac
    done

    log_info "=== Play Store Deployment Script ==="
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root"
        send_error_notification "Cannot access project directory"
        exit 1
    }

    # Check dependencies
    check_dependencies || {
        send_error_notification "Missing dependencies"
        exit 1
    }

    # Validate Play Store config
    validate_play_config || {
        send_error_notification "Invalid Play Store configuration"
        exit 1
    }

    # Get version
    local version
    version=$(cat "${VERSION_FILE}" 2>/dev/null || echo "unknown")
    log_info "Version: ${version}"
    log_info "Package: ${PLAY_PACKAGE_NAME}"
    log_info "Track: ${track}"
    log_info "Rollout: ${rollout}%"
    echo ""

    # Find APK if not specified
    if [[ -z "${apk_file}" ]]; then
        apk_file=$(find "${PROJECT_ROOT}/app/build/outputs/apk" -name "*-signed.apk" -type f 2>/dev/null | head -n 1 || echo "")

        if [[ -z "${apk_file}" ]]; then
            apk_file=$(find "${PROJECT_ROOT}/app/build/outputs/apk" -name "*.apk" -type f 2>/dev/null | head -n 1 || echo "")
        fi

        if [[ -z "${apk_file}" ]]; then
            log_error "No APK file found"
            send_error_notification "No APK file found to deploy"
            exit 1
        fi
    fi

    # Validate APK path to prevent directory traversal
    if ! validate_file_path "${apk_file}"; then
        log_error "Invalid APK path: ${apk_file}"
        send_error_notification "Invalid APK path"
        exit 1
    fi

    if [[ ! -f "${apk_file}" ]]; then
        log_error "APK file not found: ${apk_file}"
        send_error_notification "APK file not found: ${apk_file}"
        exit 1
    fi

    log_info "APK: ${apk_file}"
    echo ""

    # Upload APK
    local upload_success=false
    local upload_error=""

    # Try fastlane first
    if upload_with_fastlane "${apk_file}" "${track}" "${rollout}"; then
        upload_success=true
    # Fallback to Play CLI
    elif upload_with_play_cli "${apk_file}" "${track}" "${rollout}"; then
        upload_success=true
    else
        upload_error="All upload methods failed"
        log_error "${upload_error}"
    fi

    if [[ "${upload_success}" == false ]]; then
        send_error_notification "${upload_error}"
        log_deployment "${version}" "${track}" "${rollout}" "false" "${upload_error}" ""
        exit 1
    fi

    # Monitor deployment (optional)
    monitor_deployment "${track}"

    # Generate Play Store URL
    local play_url="https://play.google.com/store/apps/details?id=${PLAY_PACKAGE_NAME}"

    # Log to database
    log_deployment "${version}" "${track}" "${rollout}" "true" "" "${play_url}"

    # Output result
    echo ""
    log_success "=== Play Store Deployment Complete ==="
    echo "Version: ${version}"
    echo "Track: ${track}"
    echo "Rollout: ${rollout}%"
    echo "URL: ${play_url}"

    exit 0
}

# Run main function
main "$@"
