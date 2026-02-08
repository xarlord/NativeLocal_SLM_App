#!/bin/bash
# generate-changelog.sh
# Generates CHANGELOG.md based on commits since last tag
# Categorizes commits and outputs formatted changelog
# Usage: generate-changelog.sh [--output=FILE] [--since=TAG]

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Version file
VERSION_FILE="${PROJECT_ROOT}/.version"
CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"

# Build info
BUILD_ID="${CI_PIPELINE_NUMBER:-}"
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

# Get version from .version file
get_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}" | tr -d '[:space:]'
    else
        log_error ".version file not found"
        return 1
    fi
}

# Get last git tag
get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Get all commits since last tag
get_commits() {
    local last_tag="$1"

    if [[ -n "${last_tag}" ]]; then
        git log "${last_tag}..HEAD" --pretty=format:"%h|%s|%an|%ad" --date=short 2>/dev/null || echo ""
    else
        git log --pretty=format:"%h|%s|%an|%ad" --date=short 2>/dev/null || echo ""
    fi
}

# Categorize commits
categorize_commits() {
    local commits="$1"

    local features=""
    local fixes=""
    local performance=""
    local docs=""
    local breaking=""
    local tests=""
    local chore=""
    local other=""

    while IFS='|' read -r hash subject author date; do
        [[ -z "${hash}" ]] && continue

        # Extract conventional commit type
        local commit_type
        commit_type=$(echo "${subject}" | sed -E 's/^([a-z]+)(\(.+\))?:.*/\1/')

        # Check for breaking change
        if echo "${subject}" | grep -qiE "breaking!|BREAKING CHANGE"; then
            breaking="${breaking}- ${subject} (${hash})\n"
        # Categorize by type
        else
            case "${commit_type}" in
                feat)
                    features="${features}- ${subject} (${hash})\n"
                    ;;
                fix)
                    fixes="${fixes}- ${subject} (${hash})\n"
                    ;;
                perf)
                    performance="${performance}- ${subject} (${hash})\n"
                    ;;
                docs)
                    docs="${docs}- ${subject} (${hash})\n"
                    ;;
                test)
                    tests="${tests}- ${subject} (${hash})\n"
                    ;;
                chore)
                    chore="${chore}- ${subject} (${hash})\n"
                    ;;
                *)
                    # Skip uncategorized commits or add to other
                    if [[ "${commit_type}" != "${subject}" ]]; then
                        other="${other}- ${subject} (${hash})\n"
                    fi
                    ;;
            esac
        fi
    done <<< "${commits}"

    # Output categorized commits
    echo "BREAKING||${breaking}"
    echo "FEATURES||${features}"
    echo "FIXES||${fixes}"
    echo "PERFORMANCE||${performance}"
    echo "DOCS||${docs}"
    echo "TESTS||${tests}"
    echo "CHORE||${chore}"
    echo "OTHER||${other}"
}

# Generate changelog markdown
generate_changelog_md() {
    local version="$1"
    local categorized_commits="$2"
    local previous_tag="$3"

    local release_date
    release_date=$(date -u +'%Y-%m-%d')

    # Start changelog
    local changelog="## [${version}] - ${release_date}"

    # Add section for previous version if provided
    if [[ -n "${previous_tag}" ]]; then
        changelog="${changelog}\n\n_full diff: \`${previous_tag}...v${version}\`_\n"
    fi

    # Parse categorized commits
    local has_content=false

    while IFS='||' read -r category commits; do
        [[ -z "${category}" ]] && continue

        # Skip empty categories
        [[ -z "${commits}" ]] && continue

        # Skip chore and other by default
        [[ "${category}" == "CHORE" ]] && continue
        [[ "${category}" == "OTHER" ]] && continue

        has_content=true

        # Add section header
        case "${category}" in
            BREAKING)
                changelog="${changelog}\n### ⚠️ Breaking Changes\n\n${commits}"
                ;;
            FEATURES)
                changelog="${changelog}\n### ✨ Features\n\n${commits}"
                ;;
            FIXES)
                changelog="${changelog}\n### 🐛 Bug Fixes\n\n${commits}"
                ;;
            PERFORMANCE)
                changelog="${changelog}\n### ⚡ Performance\n\n${commits}"
                ;;
            DOCS)
                changelog="${changelog}\n### 📝 Documentation\n\n${commits}"
                ;;
            TESTS)
                changelog="${changelog}\n### ✅ Tests\n\n${commits}"
                ;;
        esac
    done <<< "${categorized_commits}"

    # Add note if no commits found
    if [[ "${has_content}" == false ]]; then
        changelog="${changelog}\n\nNo changes documented."
    fi

    echo -e "${changelog}"
}

# Update existing CHANGELOG.md
update_changelog_file() {
    local new_content="$1"

    if [[ -f "${CHANGELOG_FILE}" ]]; then
        # Read existing changelog
        local existing_changelog
        existing_changelog=$(cat "${CHANGELOG_FILE}")

        # Check if file has content
        if [[ -n "${existing_changelog}" ]]; then
            # Insert new content at the beginning (after header if present)
            if echo "${existing_changelog}" | grep -q "^# "; then
                # File has a header, insert after first line
                local header
                header=$(echo "${existing_changelog}" | head -n 1)
                local body
                body=$(echo "${existing_changelog}" | tail -n +2)
                new_content="${header}\n\n${new_content}\n\n${body}"
            else
                # No header, prepend
                new_content="${new_content}\n\n${existing_changelog}"
            fi
        fi
    fi

    # Write changelog
    echo -e "${new_content}" > "${CHANGELOG_FILE}"
    log_success "CHANGELOG.md updated"
}

# Update database to mark changelog as generated (with SQL injection prevention)
update_database() {
    local version="$1"

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    # Escape version to prevent SQL injection
    local escaped_version
    local escaped_sha
    escaped_version=$(psql_escape "${version}")
    escaped_sha=$(psql_escape "${COMMIT_SHA:-}")

    local update_sql="
UPDATE release_history
SET changelog_generated = TRUE
WHERE version = '${escaped_version}'
  AND commit_sha = '${escaped_sha}'
RETURNING id;
"

    # Execute with proper error handling (no silent failures)
    if ! PGPASSWORD="${db_password}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -t -A -c "${update_sql}" 2>&1; then
        log_warning "Failed to update database for changelog generation"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local output_file=""
    local since_tag=""
    local append_to_file=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output=*)
                output_file="${1#*=}"
                shift
                ;;
            --since=*)
                since_tag="${1#*=}"
                shift
                ;;
            --append)
                append_to_file=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--output=FILE] [--since=TAG] [--append]"
                exit 1
                ;;
        esac
    done

    log_info "=== Changelog Generator ==="
    echo ""

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root"
        exit 1
    }

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Get version
    local version
    version=$(get_version) || {
        log_error "Failed to read version from ${VERSION_FILE}"
        exit 1
    }

    # Validate version format (using security utils)
    if ! validate_semver "${version}"; then
        log_error "Invalid version format: ${version}"
        exit 1
    fi

    log_info "Version: ${version}"

    # Get last tag (or use provided tag)
    local last_tag
    if [[ -n "${since_tag}" ]]; then
        # Validate tag input
        if ! validate_git_tag "${since_tag}"; then
            log_error "Invalid tag format: ${since_tag}"
            exit 1
        fi
        last_tag="${since_tag}"
    else
        last_tag=$(get_last_tag)
    fi

    if [[ -n "${last_tag}" ]]; then
        log_info "Generating changelog since: ${last_tag}"
    else
        log_info "Generating changelog from all commits"
    fi

    # Get commits
    local commits
    commits=$(get_commits "${last_tag}")

    if [[ -z "${commits}" ]]; then
        log_warning "No commits found since ${last_tag:-beginning}"
        # Still create a minimal changelog
    fi

    # Categorize commits
    log_info "Categorizing commits..."
    local categorized
    categorized=$(categorize_commits "${commits}")

    # Generate changelog markdown
    local changelog_md
    changelog_md=$(generate_changelog_md "${version}" "${categorized}" "${last_tag}")

    # Output changelog
    echo ""
    log_success "=== Generated Changelog ==="
    echo ""
    echo -e "${changelog_md}"
    echo ""

    # Write to file
    if [[ -n "${output_file}" ]]; then
        echo -e "${changelog_md}" > "${output_file}"
        log_success "Changelog written to: ${output_file}"
    elif [[ "${append_to_file}" == true ]]; then
        update_changelog_file "${changelog_md}"
    else
        # Default: write to CHANGELOG.md
        update_changelog_file "${changelog_md}"
    fi

    # Update database
    update_database "${version}"

    # Output changelog for release notes
    log_info "Changelog ready for release notes"

    exit 0
}

# Run main function
main "$@"
