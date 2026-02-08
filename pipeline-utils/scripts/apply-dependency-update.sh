#!/bin/bash
# apply-dependency-update.sh
# Apply dependency updates to build.gradle.kts files
# Usage: ./apply-dependency-update.sh <dependency-name> <old-version> <new-version> [update-type]
# Logs to dependency_updates table

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RETRY_SCRIPT="${SCRIPT_DIR}/retry-command.sh"

# Source security utilities
source "${SCRIPT_DIR}/security-utils.sh" || {
    log "WARNING: security-utils.sh not found, security features limited"
}

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Git configuration
GIT_REMOTE="${GIT_REMOTE:-origin}"
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"

# ============================================
# Helper Functions
# ============================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Detect update type from versions
detect_update_type() {
    local old_version="$1"
    local new_version="$2"

    if [[ ! "${old_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || [[ ! "${new_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "unknown"
        return
    fi

    local old_major old_minor old_patch
    local new_major new_minor new_patch

    IFS='.' read -r old_major old_minor old_patch <<< "${old_version}"
    IFS='.' read -r new_major new_minor new_patch <<< "${new_version}"

    if [[ "${new_major}" -gt "${old_major}" ]]; then
        echo "major"
    elif [[ "${new_minor}" -gt "${old_minor}" ]]; then
        echo "minor"
    elif [[ "${new_patch}" -gt "${old_patch}" ]]; then
        echo "patch"
    else
        echo "unknown"
    fi
}

# Find build.gradle.kts files
find_build_files() {
    find "${PROJECT_ROOT}" -name "build.gradle.kts" -type f 2>/dev/null
}

# Update dependency in build file
update_dependency_in_file() {
    local file="$1"
    local dependency_name="$2"
    local old_version="$3"
    local new_version="$4"

    log "Processing: ${file}"

    # Validate file path to prevent directory traversal
    if command -v validate_file_path &>/dev/null; then
        if ! validate_file_path "${file}"; then
            log "  ERROR: Invalid file path: ${file}"
            return 1
        fi
    fi

    # Check if file exists
    if [[ ! -f "${file}" ]]; then
        log "  ERROR: File not found: ${file}"
        return 1
    fi

    # Check if file contains the dependency
    if ! grep -q "${dependency_name}" "${file}"; then
        log "  Skipped: ${dependency_name} not found in ${file}"
        return 1
    fi

    # Check if old version is present
    if ! grep -q "${old_version}" "${file}"; then
        log "  Warning: Old version ${old_version} not found in ${file}"
        return 1
    fi

    # Create backup
    cp "${file}" "${file}.backup"

    # Update version (handles multiple formats) - use more precise patterns
    # Format: implementation("group:name:version")
    sed -i "s|${dependency_name}:${old_version}|${dependency_name}:${new_version}|g" "${file}"
    # Format: implementation(group: ID, name: ID, version: ID)
    sed -i "s|version = \"${old_version}\"|version = \"${new_version}\"|g" "${file}"
    # Format: const val VERSION = "..."
    sed -i "s|${dependency_name}.*\"${old_version}\"|${dependency_name}\"${new_version}\"|g" "${file}"

    # Check if changes were made
    if ! diff -q "${file}" "${file}.backup" >/dev/null 2>&1; then
        log "  Updated: ${dependency_name} ${old_version} -> ${new_version}"
        rm -f "${file}.backup"
        return 0
    else
        log "  No changes needed in ${file}"
        mv "${file}.backup" "${file}"
        return 1
    fi
}

# Run gradle dependencies to refresh
run_gradle_dependencies() {
    log "Running gradle dependencies to refresh..."

    local gradle_cmd="./gradlew"
    if [[ ! -f "${gradle_cmd}" ]]; then
        # Try in subdirectories
        if [[ -f "simpleGame/gradlew" ]]; then
            gradle_cmd="./simpleGame/gradlew"
        else
            log "Warning: gradlew not found, skipping dependency refresh"
            return 0
        fi
    fi

    # Run with timeout
    timeout 300 "${gradle_cmd}" dependencies --no-daemon --quiet 2>&1 || {
        local exit_code=$?
        if [[ ${exit_code} -eq 124 ]]; then
            log "Warning: gradle dependencies timed out after 300s"
        else
            log "Warning: gradle dependencies failed with exit code ${exit_code}"
        fi
        return 1
    }

    log "Dependency refresh complete"
    return 0
}

# Commit changes
commit_changes() {
    local dependency_name="$1"
    local old_version="$2"
    local new_version="$3"

    log "Committing changes..."

    # Check if there are changes
    if git diff --quiet; then
        log "No changes to commit"
        return 1
    fi

    # Stage changes
    git add -A

    # Create commit message
    local commit_message
    commit_message="Update ${dependency_name} from ${old_version} to ${new_version}

- Dependency: ${dependency_name}
- Old version: ${old_version}
- New version: ${new_version}

Automated by apply-dependency-update.sh"

    # Commit
    if git commit -m "${commit_message}"; then
        log "Changes committed successfully"
        return 0
    else
        log "Failed to commit changes"
        return 1
    fi
}

# Log to database
log_to_database() {
    local dependency_name="$1"
    local old_version="$2"
    local new_version="$3"
    local update_type="$4"
    local status="${5:-pending}"

    log "Logging to database..."

    # Use security function if available, otherwise fallback
    local sanitized_dep
    if command -v psql_escape &>/dev/null; then
        sanitized_dep=$(psql_escape "${dependency_name}")
    else
        sanitized_dep=$(echo "${dependency_name}" | sed "s/'/''/g")
    fi

    local query="
INSERT INTO dependency_updates (
    dependency_name,
    old_version,
    new_version,
    update_type,
    status,
    created_at
) VALUES (
    '${sanitized_dep}',
    '${old_version}',
    '${new_version}',
    '${update_type}',
    '${status}',
    NOW()
) RETURNING id;
"

    local update_id
    update_id=$(query_db "${query}")

    if [[ -n "${update_id}" ]]; then
        log "Database entry created with ID: ${update_id}"
        echo "${update_id}"
    else
        log "Warning: Failed to log to database"
        echo ""
    fi
}

# Update database with PR info
update_database_with_pr() {
    local update_id="$1"
    local pr_number="$2"
    local pr_url="$3"

    if [[ -z "${update_id}" ]]; then
        return
    fi

    log "Updating database with PR information..."

    local query="
UPDATE dependency_updates
SET
    pr_number = ${pr_number},
    pr_url = '${pr_url}'
WHERE id = ${update_id};
"

    query_db "${query}" >/dev/null
}

# ============================================
# Main Execution
# ============================================

main() {
    local dependency_name="$1"
    local old_version="$2"
    local new_version="$3"
    local update_type="${4:-}"

    log "=== Dependency Update Script ==="
    log "Dependency: ${dependency_name}"
    log "Update: ${old_version} -> ${new_version}"

    # Auto-detect update type if not provided
    if [[ -z "${update_type}" ]]; then
        update_type=$(detect_update_type "${old_version}" "${new_version}")
        log "Auto-detected update type: ${update_type}"
    fi

    # Validate inputs
    if [[ -z "${dependency_name}" ]] || [[ -z "${old_version}" ]] || [[ -z "${new_version}" ]]; then
        error "Missing required arguments"
    fi

    # Change to project root
    cd "${PROJECT_ROOT}" || error "Cannot change to project root"

    # Find and update build files
    local build_files
    build_files=$(find_build_files)

    if [[ -z "${build_files}" ]]; then
        error "No build.gradle.kts files found"
    fi

    log "Found build files:"
    echo "${build_files}" | while read -r file; do
        log "  - ${file}"
    done

    local updated_count=0
    while IFS= read -r file; do
        if update_dependency_in_file "${file}" "${dependency_name}" "${old_version}" "${new_version}"; then
            ((updated_count++))
        fi
    done <<< "${build_files}"

    if [[ ${updated_count} -eq 0 ]]; then
        error "No files were updated. Check if dependency name and version are correct."
    fi

    log "Updated ${updated_count} file(s)"

    # Run gradle dependencies
    run_gradle_dependencies || log "Warning: gradle dependencies failed, continuing anyway"

    # Commit changes
    if ! commit_changes "${dependency_name}" "${old_version}" "${new_version}"; then
        log "Warning: Failed to commit changes"
    fi

    # Log to database
    local update_id
    update_id=$(log_to_database "${dependency_name}" "${old_version}" "${new_version}" "${update_type}" "pending")

    log "=== Dependency Update Complete ==="
    log "Files updated: ${updated_count}"
    log "Update ID: ${update_id}"
    echo ""
    log "Next steps:"
    log "1. Build the project: ./gradlew build"
    log "2. Run tests: ./gradlew test"
    log "3. Push changes: git push ${GIT_REMOTE} \$(git branch --show-current)"
    log "4. Create PR: ./create-pr.sh 'Update ${dependency_name}' 'Body' '\$(git branch --show-current)' '${DEFAULT_BASE_BRANCH}'"
}

# Show usage
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <dependency-name> <old-version> <new-version> [update-type]"
    echo ""
    echo "Arguments:"
    echo "  dependency-name  Name of the dependency (e.g., com.google.code.gson:gson)"
    echo "  old-version      Current version (e.g., 2.8.9)"
    echo "  new-version      New version (e.g., 2.10.1)"
    echo "  update-type      Type: major, minor, patch (optional, auto-detected)"
    echo ""
    echo "Examples:"
    echo "  $0 com.google.code.gson:gson 2.8.9 2.10.1"
    echo "  $0 org.junit.jupiter:junit-jupiter 5.8.2 5.9.0 minor"
    echo ""
    echo "The script will:"
    echo "  1. Find all build.gradle.kts files"
    echo "  2. Update the dependency version"
    echo "  3. Run ./gradlew dependencies"
    echo "  4. Commit changes with formatted message"
    echo "  5. Log to dependency_updates table"
    exit 1
fi

# Run main function
main "$@"
