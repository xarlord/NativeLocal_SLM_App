#!/bin/bash
# create-branch.sh
# Create feature branch with naming convention validation
# Usage: ./create-branch.sh feature/update-dependency-name
# Logs to branch_history table

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
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"
GIT_REMOTE="${GIT_REMOTE:-origin}"

# Branch type patterns
declare -A BRANCH_PATTERNS=(
    ["feature"]="feature/*"
    ["bugfix"]="bugfix/*|fix/*"
    ["hotfix"]="hotfix/*"
    ["release"]="release/*"
    ["refactor"]="refactor/*"
)

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

# Validate branch name format (with security)
validate_branch_name() {
    local branch_name="$1"

    log "Validating branch name: ${branch_name}"

    # Check if branch name is empty
    if [[ -z "${branch_name}" ]]; then
        error "Branch name cannot be empty"
    fi

    # Use security validation if available
    if command -v validate_branch_name_strict &>/dev/null; then
        if ! validate_branch_name_strict "${branch_name}"; then
            error "Invalid branch name format. Must match: (feature|bugfix|hotfix|release|refactor|docs|test|experiment|support)/name"
        fi
    else
        # Fallback to basic validation
        # Check for invalid characters
        if [[ "${branch_name}" =~ [^a-zA-Z0-9/_-] ]]; then
            error "Branch name contains invalid characters. Use only letters, numbers, /, _, and -"
        fi

        # Check if branch name starts with /
        if [[ "${branch_name}" =~ ^/ ]]; then
            error "Branch name cannot start with /"
        fi

        # Check if branch name ends with /
        if [[ "${branch_name}" =~ /$ ]]; then
            error "Branch name cannot end with /"
        fi

        # Check for consecutive slashes
        if [[ "${branch_name}" =~ // ]]; then
            error "Branch name cannot contain consecutive slashes"
        fi

        # Check for directory traversal
        if [[ "${branch_name}" =~ \.\. ]]; then
            error "Branch name cannot contain directory traversal patterns (..)"
        fi
    fi

    # Determine branch type
    local branch_type=""
    for type in "${!BRANCH_PATTERNS[@]}"; do
        local pattern="${BRANCH_PATTERNS[$type]}"
        if [[ "${branch_name}" =~ ^${pattern}$ ]]; then
            branch_type="${type}"
            break
        fi
    done

    # If no pattern matched, try to infer from prefix
    if [[ -z "${branch_type}" ]]; then
        local prefix="${branch_name%%/*}"
        if [[ "${prefix}" == "${branch_name}" ]]; then
            branch_type="feature"
        else
            branch_type="${prefix}"
        fi
    fi

    echo "${branch_type}"
}

# Get base branch (main or develop)
get_base_branch() {
    local suggested="$1"

    # Use suggested branch if provided
    if [[ -n "${suggested}" ]]; then
        if git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/${suggested}" 2>/dev/null; then
            echo "${suggested}"
            return
        fi
    fi

    # Default to main, fallback to develop
    if git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/main" 2>/dev/null; then
        echo "main"
    elif git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/develop" 2>/dev/null; then
        echo "develop"
    elif git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/master" 2>/dev/null; then
        echo "master"
    else
        error "Cannot determine base branch. Neither main, develop, nor master found."
    fi
}

# Check if branch already exists
check_branch_exists() {
    local branch_name="$1"

    if git show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
        return 0
    fi

    if git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/${branch_name}" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Create the branch
create_branch() {
    local branch_name="$1"
    local base_branch="$2"

    log "Creating branch from ${base_branch}..."

    # Check if branch already exists (local or remote)
    if git show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
        error "Branch already exists locally: ${branch_name}"
    fi

    if git show-ref --verify --quiet "refs/remotes/${GIT_REMOTE}/${branch_name}" 2>/dev/null; then
        error "Branch already exists remotely: ${branch_name}"
    fi

    # Fetch latest from remote
    log "Fetching latest changes..."
    if ! git fetch "${GIT_REMOTE}" >/dev/null 2>&1; then
        error "Failed to fetch from remote"
    fi

    # Checkout base branch
    log "Checking out ${base_branch}..."
    if ! git checkout "${base_branch}" 2>/dev/null; then
        error "Failed to checkout ${base_branch}"
    fi

    # Pull latest changes
    log "Pulling latest changes..."
    if ! git pull "${GIT_REMOTE}" "${base_branch}" 2>/dev/null; then
        log "Warning: Failed to pull, continuing anyway"
    fi

    # Create and checkout new branch
    log "Creating new branch: ${branch_name}"
    if ! git checkout -b "${branch_name}" 2>/dev/null; then
        error "Failed to create branch"
    fi

    log "Branch created successfully"
    return 0
}

# Log branch creation to database
log_branch_creation() {
    local branch_name="$1"
    local branch_type="$2"
    local base_branch="$3"
    local creator="${4:-${USER}}"
    local created_by_script="${5:-true}"

    log "Logging branch creation to database..."

    local sanitized_name
    local sanitized_creator
    sanitized_name=$(echo "${branch_name}" | sed "s/'/''/g")
    sanitized_creator=$(echo "${creator}" | sed "s/'/''/g")

    local query="
INSERT INTO branch_history (
    branch_name,
    branch_type,
    base_branch,
    creator,
    created_by_script,
    status,
    created_at
) VALUES (
    '${sanitized_name}',
    '${branch_type}',
    '${base_branch}',
    '${sanitized_creator}',
    ${created_by_script},
    'active',
    NOW()
) ON CONFLICT (branch_name) DO UPDATE SET
    status = 'active',
    last_commit_at = NOW()
RETURNING id;
"

    local branch_id
    branch_id=$(query_db "${query}")

    if [[ -n "${branch_id}" ]]; then
        log "Branch logged with ID: ${branch_id}"
    else
        log "Warning: Failed to log branch to database"
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local branch_name="$1"
    local base_branch="${2:-${DEFAULT_BASE_BRANCH}}"

    log "=== Branch Creation Script ==="
    log "Branch name: ${branch_name}"

    # Validate branch name
    local branch_type
    branch_type=$(validate_branch_name "${branch_name}")
    log "Branch type: ${branch_type}"

    # Determine base branch
    base_branch=$(get_base_branch "${base_branch}")
    log "Base branch: ${base_branch}"

    # Check if branch already exists
    if check_branch_exists "${branch_name}"; then
        log "Warning: Branch '${branch_name}' already exists locally or remotely"

        # Log to database anyway
        log_branch_creation "${branch_name}" "${branch_type}" "${base_branch}" "${USER}" "false"

        log "You can checkout the existing branch with: git checkout ${branch_name}"
        exit 0
    fi

    # Create the branch
    create_branch "${branch_name}" "${base_branch}"

    # Log to database
    log_branch_creation "${branch_name}" "${branch_type}" "${base_branch}"

    log "=== Branch Created Successfully ==="
    log "Branch: ${branch_name}"
    log "Type: ${branch_type}"
    log "Base: ${base_branch}"
    echo ""
    log "Next steps:"
    log "1. Make your changes"
    log "2. Commit your changes: git commit -am 'Your message'"
    log "3. Push the branch: git push ${GIT_REMOTE} ${branch_name}"
    log "4. Create a PR: ./create-pr.sh 'Title' 'Body' '${branch_name}' '${base_branch}'"
}

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <branch-name> [base-branch]"
    echo ""
    echo "Examples:"
    echo "  $0 feature/add-new-feature"
    echo "  $0 bugfix/fix-login-error"
    echo "  $0 refactor/rename-user-class"
    echo "  $0 hotfix/critical-security-patch develop"
    echo ""
    echo "Branch naming conventions:"
    echo "  feature/*    - New features"
    echo "  bugfix/*     - Bug fixes"
    echo "  fix/*        - Bug fixes (alternative)"
    echo "  hotfix/*     - Hotfixes for production"
    echo "  release/*    - Release branches"
    echo "  refactor/*   - Refactoring changes"
    exit 1
fi

# Change to project root
cd "${PROJECT_ROOT}" || error "Cannot change to project root"

# Run main function
main "$@"
