#!/bin/bash
# common.sh - Shared functions for all pipeline-utils scripts
# Source this file in your scripts using: source "${SCRIPT_DIR}/common.sh"

# ============================================
# PROJECT_ROOT Support
# ============================================

# Set PROJECT_ROOT with fallback to current directory
# This should be called early in each script
setup_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${script_dir}/../.." && pwd)}"
    export PROJECT_ROOT
}

# ============================================
# jq Fallback Handling
# ============================================

# Check if jq is available
has_jq() {
    command -v jq >/dev/null 2>&1
}

# Parse JSON field with jq fallback
# Usage: json_extract_field '{"key":"value"}' ".key"
json_extract_field() {
    local json="$1"
    local field="$2"

    if has_jq; then
        echo "${json}" | jq -r "${field}"
    else
        # Fallback: parse with grep/sed
        # Remove quotes from field name for matching
        local field_name="${field#*.}"
        field_name="${field_name//\"/}"

        # Try to match "field":"value" pattern
        echo "${json}" | grep -o "\"${field_name}\":\"[^\"]*\"" | cut -d'"' -f4 || \
        echo "${json}" | grep -o "\"${field_name}\":[^,}]*" | sed 's/.*: //' | tr -d '"'
    fi
}

# Get array length with jq fallback
# Usage: json_array_length '[1,2,3]' or json_array_length '{"items":[]}' ".items"
json_array_length() {
    local json="$1"
    local array_path="${2:-.}"

    if has_jq; then
        echo "${json}" | jq -r "${array_path} | length"
    else
        # Fallback: count occurrences
        local content="${json}"
        if [[ "${array_path}" != "." ]]; then
            # Try to extract array content
            content=$(echo "${json}" | grep -o "\"${array_path#.}\":\[[^]]*\]" | sed 's/.*: //' | tr -d '[]')
        fi

        # Count commas + 1 for array length
        local count=$(echo "${content}" | grep -o "," | wc -l)
        echo $((count + 1))
    fi
}

# Safe jq wrapper that returns empty string on failure
safe_jq() {
    local jq_expr="$1"
    local input="${2:-/dev/stdin}"

    if has_jq; then
        if [[ "${input}" == "/dev/stdin" ]]; then
            jq -r "${jq_expr}" 2>/dev/null || echo ""
        else
            echo "${input}" | jq -r "${jq_expr}" 2>/dev/null || echo ""
        fi
    else
        # Fallback: simple grep/sed extraction
        if [[ "${jq_expr}" =~ \.([a-zA-Z_]+) ]]; then
            local field="${BASH_REMATCH[1]}"
            cat "${input}" | grep -o "\"${field}\":\"[^\"]*\"" | cut -d'"' -f4 || echo ""
        else
            echo ""
        fi
    fi
}

# ============================================
# GitHub API Rate Limit Handling
# ============================================

# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    local reset_time
    local limit

    if has_jq; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
        reset_time=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.reset // 0')
        limit=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.limit // 5000')
    else
        # Fallback: single API call to check rate limit
        local rate_info
        rate_info=$(gh api -X GET /rate_limit 2>/dev/null)
        remaining=$(echo "${rate_info}" | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
        reset_time=$(echo "${rate_info}" | grep -o '"reset":[0-9]*' | cut -d':' -f2 | head -1 || echo "0")
        limit=$(echo "${rate_info}" | grep -o '"limit":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    local threshold="${GITHUB_RATE_LIMIT_THRESHOLD:-100}"

    if [[ ${remaining} -lt ${threshold} ]]; then
        log_warning "GitHub API rate limit low: ${remaining}/${limit} remaining"

        if [[ ${remaining} -lt 10 ]]; then
            local current_time=$(date +%s)
            local wait_time=$((reset_time - current_time + 5))

            if [[ ${wait_time} -gt 0 ]]; then
                log_warning "Rate limit nearly exhausted. Sleeping for ${wait_time} seconds..."
                sleep "${wait_time}"
            fi
        else
            log_warning "Sleeping for 10 seconds to conserve rate limit..."
            sleep 10
        fi
    fi

    return 0
}

# Execute gh command with rate limit checking
gh_with_rate_limit() {
    check_github_rate_limit
    gh "$@"
}

# ============================================
# Error Handling and Cleanup
# ============================================

# Cleanup function to be called on exit
cleanup() {
    local exit_code=$?

    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Script failed with exit code: ${exit_code}"

        # Call custom error notification if available
        if type -t send_error_notification >/dev/null; then
            send_error_notification "Script ${BASH_SOURCE[1]} failed with exit code ${exit_code}"
        fi
    fi

    # Call custom cleanup if available
    if type -t custom_cleanup >/dev/null; then
        custom_cleanup
    fi
}

# Setup error handling trap
setup_error_handling() {
    trap cleanup EXIT
}

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*" >&2
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*" >&2
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

error() {
    log_error "$*"
    exit 1
}

# ============================================
# Configuration Loading
# ============================================

# Load configuration from YAML file (simplified parsing)
load_config() {
    local config_file="${PROJECT_ROOT}/pipeline-utils/config/$(basename "${BASH_SOURCE[1]}" .sh).yaml"

    if [[ -f "${config_file}" ]]; then
        log "Loading configuration from: ${config_file}"

        # Simple YAML parsing (key: value)
        while IFS=': ' read -r key value; do
            # Skip comments and empty lines
            [[ "${key}" =~ ^#.*$ ]] && continue
            [[ -z "${key}" ]] && continue

            # Remove comments from value
            value=$(echo "${value}" | cut -d'#' -f1 | xargs)

            # Set as variable
            declare -g "${key}=${value}"
        done < "${config_file}"
    fi
}

# Load configuration from .env file
load_env_config() {
    local env_file="${PROJECT_ROOT}/.env"

    if [[ -f "${env_file}" ]]; then
        log "Loading environment from: ${env_file}"

        # Source the .env file
        set -a
        source "${env_file}"
        set +a
    fi
}

# ============================================
# Database Connection Helpers
# ============================================

# Standard database connection parameters
setup_db_vars() {
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-woodpecker}"
    DB_USER="${DB_USER:-woodpecker}"
    DB_PASSWORD="${DB_PASSWORD:-woodpecker}"
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
}

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# ============================================
# Git Helpers
# ============================================

# Check if in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
    fi
}

# Get GitHub repository owner/name
get_github_repo() {
    local remote="${GIT_REMOTE:-origin}"
    git remote get-url "${remote}" 2>/dev/null | sed 's|\.git$||' || echo "unknown/repo"
}

# Check gh CLI authentication
check_gh_auth() {
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI (gh) is not installed or not in PATH"
    fi

    if ! gh auth status &>/dev/null; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
    fi
}

# ============================================
# Initialization
# ============================================

# Initialize common functions
init_common() {
    setup_project_root
    setup_db_vars
    setup_error_handling
    load_env_config
}

# Export functions for use in subshells
export -f log log_info log_success log_warning log_error error
export -f has_jq json_extract_field json_array_length safe_jq
export -f check_github_rate_limit gh_with_rate_limit
export -f cleanup setup_error_handling
export -f load_config load_env_config
export -f setup_db_vars query_db
export -f check_git_repo get_github_repo check_gh_auth
export -f setup_project_root init_common
