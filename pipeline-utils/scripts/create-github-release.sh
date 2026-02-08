#!/bin/bash
# create-github-release.sh
# Creates GitHub release with changelog and APK attachment
# Uses gh CLI with retry logic for API calls
# Usage: create-github-release.sh [--draft] [--pre-release] [--apk=PATH]

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Version file
VERSION_FILE="${PROJECT_ROOT}/.version"
CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"

# GitHub configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPO="${CI_REPO:-}"
GITHUB_REMOTE="${GITHUB_REMOTE:-origin}"

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
            --arg title "GitHub Release Failed" \
            --arg message "Failed to create GitHub release: ${error_message}" \
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

# Get version from .version file (with validation)
get_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        local version
        version=$(cat "${VERSION_FILE}" | tr -d '[:space:]')

        # Validate version format
        if ! validate_semver "${version}"; then
            log_error "Invalid version format in .version file: ${version}"
            return 1
        fi

        echo "${version}"
    else
        log_error ".version file not found"
        return 1
    fi
}

# Get or detect GitHub repo (with validation)
get_github_repo() {
    if [[ -n "${GITHUB_REPO}" ]]; then
        # Validate GitHub repo format
        if ! validate_github_repo "${GITHUB_REPO}"; then
            log_error "Invalid GitHub repository format: ${GITHUB_REPO}"
            return 1
        fi
        echo "${GITHUB_REPO}"
        return 0
    fi

    # Try to get from git remote
    local remote_url
    remote_url=$(git remote get-url "${GITHUB_REMOTE}" 2>/dev/null || echo "")

    if [[ -z "${remote_url}" ]]; then
        log_error "Could not determine GitHub repository"
        return 1
    fi

    # Parse repo from URL
    # Supports: https://github.com/owner/repo.git or git@github.com:owner/repo.git
    local repo
    repo=$(echo "${remote_url}" | sed -E 's|.*github.com[/:]([^/]+/[^/]+).*|\1|' | sed 's|\.git$||')

    if [[ -z "${repo}" ]]; then
        log_error "Could not parse repository from remote URL"
        return 1
    fi

    # Validate parsed repo
    if ! validate_github_repo "${repo}"; then
        log_error "Invalid GitHub repository format: ${repo}"
        return 1
    fi

    echo "${repo}"
}

# Check if gh CLI is available and authenticated
check_gh_cli() {
    log_info "Checking gh CLI..."

    if ! command -v gh &>/dev/null; then
        log_error "gh CLI not found. Install from https://cli.github.com/"
        return 1
    fi

    if [[ -z "${GITHUB_TOKEN}" ]]; then
        log_error "GITHUB_TOKEN environment variable not set"
        return 1
    fi

    # Verify authentication
    if ! gh auth status &>/dev/null; then
        log_error "gh CLI not authenticated. Run: gh auth login"
        return 1
    fi

    log_success "gh CLI ready"
    return 0
}

# Extract release notes from changelog
extract_release_notes() {
    local version="$1"

    if [[ ! -f "${CHANGELOG_FILE}" ]]; then
        log_warning "CHANGELOG.md not found, using generic release notes"
        echo "Release ${version}"
        return 0
    fi

    # Extract section for this version
    local notes
    notes=$(sed -n "/## \[${version}\]/,/## \[/p" "${CHANGELOG_FILE}" | head -n -1)

    if [[ -z "${notes}" ]]; then
        # Try alternative format
        notes=$(sed -n "/## \[${version}\]/,/## \[v/p" "${CHANGELOG_FILE}" | head -n -1)
    fi

    if [[ -z "${notes}" ]]; then
        log_warning "No changelog entry found for version ${version}"
        echo "Release ${version}"
        return 0
    fi

    echo "${notes}"
}

# Create GitHub release
create_release() {
    local version="$1"
    local title="$2"
    local notes_file="$3"
    local apk_file="$4"
    local is_draft="$5"
    local is_pre_release="$6"

    local tag_name="v${version}"
    local target_commit="${COMMIT_SHA:-HEAD}"

    log_info "Creating GitHub release..."
    log_info "Tag: ${tag_name}"
    log_info "Target: ${target_commit}"

    # Build release command
    local release_cmd="gh release create '${tag_name}' \
        --title '${title}' \
        --notes-file '${notes_file}' \
        --target '${target_commit}'"

    # Add flags
    if [[ "${is_draft}" == true ]]; then
        release_cmd="${release_cmd} --draft"
    fi

    if [[ "${is_pre_release}" == true ]]; then
        release_cmd="${release_cmd} --pre-release"
    fi

    # Add APK file if provided
    if [[ -n "${apk_file}" && -f "${apk_file}" ]]; then
        release_cmd="${release_cmd} '${apk_file}'"
        log_info "Including APK: ${apk_file}"
    fi

    # Execute with retry
    local release_url
    release_url=$(retry_command "${release_cmd}" 3) || {
        log_error "Failed to create GitHub release"
        return 1
    }

    log_success "GitHub release created"
    echo "${release_url}"
}

# Update database with release URL (with SQL injection prevention)
update_database() {
    local version="$1"
    local release_url="$2"

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    # Escape all inputs to prevent SQL injection
    local escaped_version
    local escaped_sha
    local escaped_url

    escaped_version=$(psql_escape "${version}")
    escaped_sha=$(psql_escape "${COMMIT_SHA:-}")
    escaped_url=$(psql_escape "${release_url}")

    local update_sql="
UPDATE release_history
SET
    github_release_created = TRUE,
    release_url = '${escaped_url}'
WHERE version = '${escaped_version}'
  AND commit_sha = '${escaped_sha}'
RETURNING id;
"

    # Execute with proper error handling
    if ! PGPASSWORD="${db_password}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -t -A -c "${update_sql}" 2>&1; then
        log_warning "Failed to update database with GitHub release URL"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local apk_file=""
    local is_draft=false
    local is_pre_release=false
    local custom_notes=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --draft)
                is_draft=true
                shift
                ;;
            --pre-release)
                is_pre_release=true
                shift
                ;;
            --apk=*)
                apk_file="${1#*=}"
                shift
                ;;
            --notes=*)
                custom_notes="${1#*=}"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--draft] [--pre-release] [--apk=PATH] [--notes=FILE]"
                exit 1
                ;;
        esac
    done

    log_info "=== GitHub Release Creator ==="
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root"
        send_error_notification "Cannot access project directory"
        exit 1
    }

    # Check gh CLI
    check_gh_cli || {
        send_error_notification "gh CLI not available or not authenticated"
        exit 1
    }

    # Get version
    local version
    version=$(get_version) || {
        send_error_notification "Failed to read version"
        exit 1
    }
    log_info "Version: ${version}"

    # Get GitHub repo
    local repo
    repo=$(get_github_repo) || {
        send_error_notification "Could not determine GitHub repository"
        exit 1
    }
    log_info "Repository: ${repo}"
    echo ""

    # Check if tag exists
    local tag_name="v${version}"
    if ! git rev-parse "${tag_name}" >/dev/null 2>&1; then
        log_warning "Tag ${tag_name} does not exist locally"
        log_info "You may need to run bump-version.sh first"
    fi

    # Validate tag format
    if ! validate_git_tag "${tag_name}"; then
        log_error "Invalid tag format: ${tag_name}"
        send_error_notification "Invalid tag format"
        exit 1
    fi

    # Extract or create release notes
    local notes_file="${PROJECT_ROOT}/.release-notes.md"

    if [[ -n "${custom_notes}" ]]; then
        cp "${custom_notes}" "${notes_file}"
    else
        extract_release_notes "${version}" > "${notes_file}"
    fi

    log_info "Release notes prepared"

    # Find APK if not specified
    if [[ -z "${apk_file}" ]]; then
        # Search for signed APK
        apk_file=$(find "${PROJECT_ROOT}/app/build/outputs/apk" -name "*-signed.apk" -type f 2>/dev/null | head -n 1 || echo "")

        if [[ -z "${apk_file}" ]]; then
            # Fallback to any APK
            apk_file=$(find "${PROJECT_ROOT}/app/build/outputs/apk" -name "*.apk" -type f 2>/dev/null | head -n 1 || echo "")
        fi

        if [[ -n "${apk_file}" ]]; then
            log_info "Found APK: ${apk_file}"
        else
            log_warning "No APK file found"
        fi
    fi

    # Create release
    local release_title="v${version}"
    local release_url

    release_url=$(create_release "${version}" "${release_title}" "${notes_file}" "${apk_file}" "${is_draft}" "${is_pre_release}") || {
        local error="Failed to create GitHub release for v${version}"
        send_error_notification "${error}"
        rm -f "${notes_file}"
        exit 1
    }

    # Clean up notes file
    rm -f "${notes_file}"

    # Update database
    update_database "${version}" "${release_url}"

    # Output result
    echo ""
    log_success "=== GitHub Release Complete ==="
    echo "Release: ${release_title}"
    echo "URL: ${release_url}"
    [[ "${is_draft}" == true ]] && echo "Status: Draft"
    [[ "${is_pre_release}" == true ]] && echo "Status: Pre-release"
    [[ -n "${apk_file}" ]] && echo "APK: $(basename "${apk_file}")"

    exit 0
}

# Run main function
main "$@"
