#!/bin/bash
# bump-version.sh
# Automatically bumps version based on commit messages since last tag
# Creates git tag and logs release to database
# Usage: bump-version.sh [--dry-run] [--force-major|--force-minor|--force-patch]

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

# Version file
VERSION_FILE="${PROJECT_ROOT}/.version"

# Git configuration
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Build info
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
BUILD_URL="${CI_BUILD_URL:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"
COMMIT_MESSAGE="${CI_COMMIT_MESSAGE:-}"
BRANCH="${CI_BRANCH:-}"

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

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Send notification on error
send_error_notification() {
    local error_message="$1"
    if [[ -f "${SCRIPT_DIR}/send-notification.sh" ]]; then
        local notification_data
        notification_data=$(jq -n \
            --arg title "Version Bump Failed" \
            --arg message "Failed to bump version: ${error_message}" \
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
                    branch: env.BRANCH
                }
            }')
        echo "${notification_data}" | "${SCRIPT_DIR}/send-notification.sh" /dev/stdin || true
    fi
}

# Read current version from .version file
read_current_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

# Get last git tag
get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Parse commit messages to determine bump type
determine_bump_type() {
    local last_tag="$1"
    local bump_type="patch"  # Default to patch
    local commits

    log_info "Analyzing commits since ${last_tag:-beginning}"

    # Get commits since last tag
    if [[ -n "${last_tag}" ]]; then
        commits=$(git log "${last_tag}..HEAD" --pretty=format:"%s" 2>/dev/null || echo "")
    else
        commits=$(git log --pretty=format:"%s" 2>/dev/null || echo "")
    fi

    if [[ -z "${commits}" ]]; then
        log_warning "No commits found since last tag"
        echo "patch"
        return
    fi

    log_info "Found $(echo "${commits}" | wc -l) commits to analyze"

    # Check for breaking changes (major)
    if echo "${commits}" | grep -qiE "breaking!|BREAKING CHANGE|BREAKING-CHANGE"; then
        bump_type="major"
        log_success "Breaking changes detected - will bump MAJOR version"
    # Check for new features (minor)
    elif echo "${commits}" | grep -qiE "^feat"; then
        bump_type="minor"
        log_success "New features detected - will bump MINOR version"
    # Check for fixes or perf improvements (patch)
    elif echo "${commits}" | grep -qiE "^fix|^perf"; then
        bump_type="patch"
        log_success "Bug fixes or performance improvements detected - will bump PATCH version"
    else
        log_info "No conventional commits detected - defaulting to PATCH bump"
    fi

    echo "${bump_type}"
}

# Increment version based on bump type
increment_version() {
    local version="$1"
    local bump_type="$2"
    local major minor patch

    # Parse version
    IFS='.' read -r major minor patch <<< "${version}"

    # Remove 'v' prefix if present
    major=${major#v}

    # Ensure numeric values
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    # Increment based on type
    case "${bump_type}" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: ${bump_type}"
            return 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Validate semver format
validate_version() {
    local version="$1"
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid semver format: ${version}"
        return 1
    fi
    return 0
}

# Create git tag (with race condition prevention)
create_git_tag() {
    local version="$1"

    log_info "Creating git tag v${version}"

    # Validate version format first
    if ! validate_semver "${version}"; then
        log_error "Invalid version format for tag: ${version}"
        return 1
    fi

    # Use secure tag creation with race condition check
    if ! create_git_tag_safe "v${version}" "Release v${version}"; then
        log_error "Failed to create git tag or tag already exists"
        return 1
    fi

    log_success "Git tag v${version} created"
}

# Log release to database (with SQL injection prevention)
log_release_to_database() {
    local version="$1"
    local bump_type="$2"
    local previous_version="$3"

    log_info "Logging release to database"

    # Create release_history table if not exists
    local create_table_sql="
CREATE TABLE IF NOT EXISTS release_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER,
  commit_sha VARCHAR(40),

  version VARCHAR(20) NOT NULL,
  previous_version VARCHAR(20),
  bump_type VARCHAR(10) NOT NULL,

  tag_name VARCHAR(50),
  branch VARCHAR(100),

  changelog_generated BOOLEAN DEFAULT FALSE,
  apk_signed BOOLEAN DEFAULT FALSE,
  github_release_created BOOLEAN DEFAULT FALSE,
  play_store_deployed BOOLEAN DEFAULT FALSE,

  release_url TEXT,
  play_store_url TEXT,

  metadata JSONB,

  timestamp TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_release_history_version ON release_history(version);
CREATE INDEX IF NOT EXISTS idx_release_history_timestamp ON release_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_release_history_commit ON release_history(commit_sha);
"

    # Escape all string inputs to prevent SQL injection
    local escaped_version
    local escaped_sha
    local escaped_previous
    local escaped_bump_type
    local escaped_branch
    local escaped_build_url

    escaped_version=$(psql_escape "${version}")
    escaped_sha=$(psql_escape "${COMMIT_SHA:-}")
    escaped_previous=$(psql_escape "${previous_version}")
    escaped_bump_type=$(psql_escape "${bump_type}")
    escaped_branch=$(psql_escape "${BRANCH:-}")
    escaped_build_url=$(psql_escape "${BUILD_URL:-}")

    # Insert release record with escaped values
    local insert_sql="
INSERT INTO release_history (
    build_id, commit_sha, version, previous_version, bump_type,
    tag_name, branch, metadata
) VALUES (
    ${BUILD_ID:-NULL}, '${escaped_sha}', '${escaped_version}', '${escaped_previous}', '${escaped_bump_type}',
    'v${escaped_version}', '${escaped_branch}', '{"build_url": "${escaped_build_url}"}'::jsonb
) RETURNING id;
"

    # Execute SQL with proper error handling
    local release_id

    # Create table first (silently ignore if exists)
    echo "${create_table_sql}" | query_db >/dev/null 2>&1

    # Insert with error handling
    if ! release_id=$(echo "${insert_sql}" | query_db); then
        log_error "Failed to log release to database"
        send_error_notification "Database insert failed for version ${version}"
        echo ""
        return 1
    fi

    if [[ -n "${release_id}" ]]; then
        log_success "Release logged to database (ID: ${release_id})"
        echo "${release_id}"
    else
        log_error "Failed to log release to database"
        send_error_notification "Database returned empty ID for version ${version}"
        echo ""
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local dry_run=false
    local force_bump_type=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force-major)
                force_bump_type="major"
                shift
                ;;
            --force-minor)
                force_bump_type="minor"
                shift
                ;;
            --force-patch)
                force_bump_type="patch"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--dry-run] [--force-major|--force-minor|--force-patch]"
                exit 1
                ;;
        esac
    done

    log_info "=== Version Bump Script ==="
    if [[ "${dry_run}" == true ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root: ${PROJECT_ROOT}"
        send_error_notification "Cannot access project directory"
        exit 1
    }

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        send_error_notification "Not a git repository"
        exit 1
    fi

    # Read current version
    local current_version
    current_version=$(read_current_version)
    log_info "Current version: ${current_version}"

    # Validate current version (using security utils)
    if ! validate_semver "${current_version}"; then
        send_error_notification "Invalid current version format: ${current_version}"
        exit 1
    fi

    # Get last tag
    local last_tag
    last_tag=$(get_last_tag)
    if [[ -n "${last_tag}" ]]; then
        log_info "Last tag: ${last_tag}"
    else
        log_info "No previous tags found"
    fi

    # Determine bump type
    local bump_type
    if [[ -n "${force_bump_type}" ]]; then
        bump_type="${force_bump_type}"
        log_info "Forced bump type: ${bump_type}"
    else
        bump_type=$(determine_bump_type "${last_tag}")
    fi

    # Calculate new version
    local new_version
    new_version=$(increment_version "${current_version}" "${bump_type}")

    # Validate new version (using security utils)
    if ! validate_semver "${new_version}"; then
        send_error_notification "Failed to calculate valid version"
        exit 1
    fi

    log_success "New version: ${new_version}"

    if [[ "${dry_run}" == true ]]; then
        log_info "Dry run complete - would bump ${current_version} -> ${new_version} (${bump_type})"
        exit 0
    fi

    # Write new version to file
    log_info "Writing new version to ${VERSION_FILE}"
    echo "${new_version}" > "${VERSION_FILE}"
    log_success "Version file updated"

    # Create git tag
    create_git_tag "${new_version}" || {
        send_error_notification "Failed to create git tag v${new_version}"
        exit 1
    }

    # Log to database
    local release_id
    release_id=$(log_release_to_database "${new_version}" "${bump_type}" "${current_version}")

    # Output result
    echo ""
    log_success "=== Version Bump Complete ==="
    echo "Version: ${new_version}"
    echo "Bump Type: ${bump_type}"
    echo "Tag: v${new_version}"
    [[ -n "${release_id}" ]] && echo "Release ID: ${release_id}"

    exit 0
}

# Run main function (only if not in test mode)
if [[ "${TEST_MODE:-}" != "true" ]]; then
    main "$@"
fi
