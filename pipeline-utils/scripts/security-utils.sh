#!/bin/bash
# security-utils.sh
# Security utility functions for input validation and SQL injection prevention
# Source this file in other scripts to use the security functions

# ============================================
# SQL Injection Prevention
# ============================================

# Escape single quotes for PostgreSQL SQL queries
# Usage: escaped=$(psql_escape "$user_input")
psql_escape() {
    local input="$1"
    # Replace single quote with two single quotes (PostgreSQL escape mechanism)
    echo "${input//\'/\'\'}"
}

# Escape for LIKE queries (also escape % and _)
# Usage: escaped=$(psql_like_escape "$user_input")
psql_like_escape() {
    local input="$1"
    # First escape backslashes, then escape special chars
    input="${input//\/\\}"
    input="${input//\'/\'\'}"
    input="${input//%/\%}"
    input="${input//_/\_}"
    echo "${input}"
}

# Validate and escape file paths for SQL queries
# Usage: escaped=$(validate_and_escape_path "$file_path")
validate_and_escape_path() {
    local file_path="$1"

    # Basic path validation - prevent directory traversal
    if [[ "${file_path}" =~ \.\. ]]; then
        echo "ERROR: Path contains directory traversal" >&2
        return 1
    fi

    # Check for null bytes
    if [[ "${file_path}" =~ $'\0' ]]; then
        echo "ERROR: Path contains null bytes" >&2
        return 1
    fi

    psql_escape "${file_path}"
    return 0
}

# ============================================
# Input Validation
# ============================================

# Validate GitHub usernames (alphanumeric, hyphens)
# Usage: if validate_github_username "$user"; then ...
validate_github_username() {
    local username="$1"
    [[ "${username}" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# Validate branch names
# Usage: if validate_branch_name "$branch"; then ...
validate_branch_name_strict() {
    local branch="$1"

    # Cannot be empty
    [[ -z "${branch}" ]] && return 1

    # Cannot start or end with /
    [[ "${branch}" =~ ^/ || "${branch}" =~ /$ ]] && return 1

    # Cannot contain consecutive slashes
    [[ "${branch}" =~ // ]] && return 1

    # Cannot contain .. (directory traversal attempt)
    [[ "${branch}" =~ \.\. ]] && return 1

    # Cannot contain spaces or special characters
    [[ "${branch}" =~ [^a-zA-Z0-9/_-] ]] && return 1

    # Must match conventional commit format (type/description)
    [[ "${branch}" =~ ^(feature|bugfix|hotfix|release|refactor|docs|test|experiment|support)/[a-z0-9-]+$ ]] && return 0

    # If it doesn't match the pattern, still allow it (backward compatibility)
    return 0
}

# Validate PR numbers
# Usage: if validate_pr_number "$pr_num"; then ...
validate_pr_number() {
    local pr_num="$1"
    [[ "${pr_num}" =~ ^[0-9]+$ ]]
}

# Validate identifiers (for refactoring)
# Usage: if validate_identifier "$identifier"; then ...
validate_identifier() {
    local identifier="$1"
    [[ "${identifier}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# ============================================
# JSON Security
# ============================================

# Safely escape strings for JSON
# Usage: json_escaped=$(json_escape "$string")
json_escape() {
    local input="$1"
    # Escape backslashes, quotes, and control characters
    input="${input//\/\\}"
    input="${input//\"/\\\"}"
    input="${input//$'\n'/\n}"
    input="${input//$'\r'/\r}"
    input="${input//$'\t'/\t}"
    echo "${input}"
}

# ============================================
# File Path Security
# ============================================

# Validate file paths to prevent directory traversal
# Usage: if validate_file_path "$path"; then ...
validate_file_path() {
    local path="$1"

    # Check for null bytes
    if [[ "${path}" =~ $'\0' ]]; then
        echo "ERROR: Path contains null bytes" >&2
        return 1
    fi

    # Check for directory traversal
    if [[ "${path}" =~ \.\.\/|\.\. ]]; then
        echo "ERROR: Path contains directory traversal" >&2
        return 1
    fi

    return 0
}

# Sanitize file paths for use in commands
# Usage: safe_path=$(sanitize_path "$user_input")
sanitize_path() {
    local path="$1"

    # Remove dangerous characters
    path="${path//;/\;}"
    path="${path//&/\&}"
    path="${path//|/\|}"
    path="${path//\`/\`}"

    echo "${path}"
}

# ============================================
# Command Injection Prevention
# ============================================

# Validate arguments before passing to external commands
# Usage: if validate_command_arg "$arg"; then ...
validate_command_arg() {
    local arg="$1"

    # Check for shell metacharacters that could lead to injection
    if [[ "${arg}" =~ [\;\&\|\'\"\$\(\)\<\>\`] ]]; then
        echo "ERROR: Argument contains dangerous characters" >&2
        return 1
    fi

    return 0
}

# ============================================
# Logging Functions
# ============================================

# Security-aware logging (sanitizes input)
# Usage: log_security "User input: %s" "$user_input"
log_security() {
    local format="$1"
    shift
    local args=("$@")

    # Sanitize each argument
    for i in "${!args[@]}"; do
        args[i]=$(printf '%s' "${args[i]}" | tr -d '[:cntrl:]')
    done

    # Log with timestamp
    printf '[$(date +%%Y-%%m-%%d %%H:%%M:%%S)] %s\n' "$(printf "${format}" "${args[@]}")" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" >&2
}

# ============================================
# Additional Security Functions for Release Management
# ============================================

# Validate semantic version format (X.Y.Z)
# Usage: if validate_semver "1.2.3"; then ...
validate_semver() {
    local version="$1"
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Read password from environment with validation
# Usage: if ! check_password_env "KEYSTORE_PASSWORD"; then echo "Not set"; exit 1; fi
check_password_env() {
    local var_name="$1"
    [[ -n "${!var_name:-}" ]]
}

# Validate git tag name
# Usage: if validate_git_tag "v1.2.3"; then ...
validate_git_tag() {
    local tag="$1"
    # Must not be empty
    [[ -z "${tag}" ]] && return 1
    # Must not contain spaces or special characters
    [[ "${tag}" =~ [\ \~\^:\?\*\[\]] ]] && return 1
    # Must not start with dash
    [[ "${tag}" =~ ^- ]] && return 1
    return 0
}

# Execute SQL with proper error handling (suppresses silent failures)
# Usage: psql_execute_safe "INSERT INTO ..." "Error message"
psql_execute_safe() {
    local query="$1"
    local error_msg="${2:-Database operation failed}"

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    if ! PGPASSWORD="${db_password}" psql -h "${db_host}" -p "${db_port}" -U "${db_user}" -d "${db_name}" -t -A -c "${query}" 2>&1; then
        log_error "${error_msg}"
        return 1
    fi
    return 0
}

# Create git tag with race condition prevention
# Usage: if create_git_tag_safe "v1.2.3"; then ...
create_git_tag_safe() {
    local tag_name="$1"
    local message="${2:-}"

    # Validate tag name first
    if ! validate_git_tag "${tag_name}"; then
        log_error "Invalid tag name: ${tag_name}"
        return 1
    fi

    # Check if tag already exists (prevent race condition)
    if git rev-parse "${tag_name}" >/dev/null 2>&1; then
        log_error "Tag ${tag_name} already exists"
        return 1
    fi

    # Create the tag
    if [[ -n "${message}" ]]; then
        git tag -a "${tag_name}" -m "${message}"
    else
        git tag "${tag_name}"
    fi

    return $?
}

# Validate that credentials are provided via environment only
# Usage: if ! validate_env_credentials "KEYSTORE_PATH" "KEYSTORE_PASSWORD"; then exit 1; fi
validate_env_credentials() {
    local missing=()
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("${var}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing[*]}"
        return 1
    fi
    return 0
}

# ============================================
# Additional Security Functions (Requested)
# ============================================

# Validate input contains only safe characters matching a regex pattern
# Usage: validate_input "input" "^[a-zA-Z0-9_-]+$"
# Returns: 0 if valid, 1 if invalid
# Examples:
#   validate_input "username123" "^[a-zA-Z0-9_]+$"              # Valid
#   validate_input "user@name" "^[a-zA-Z0-9_]+$"               # Invalid
#   validate_input "1.2.3" "^[0-9]+\.[0-9]+\.[0-9]+$"          # Valid
#   validate_input "v1.2.3" "^[0-9]+\.[0-9]+\.[0-9]+$"         # Invalid
validate_input() {
    local input="$1"
    local pattern="$2"  # Regex pattern

    if [[ ! "$input" =~ $pattern ]]; then
        log_error "Invalid input: $input (does not match pattern: $pattern)"
        return 1
    fi

    return 0
}

# Validate command arguments to prevent command injection (enhanced version)
# Checks for dangerous shell metacharacters that could be used for command injection
# Usage: validate_command_args "arg1" "arg2" "arg3"
# Returns: 0 if all args safe, 1 if any arg contains dangerous characters
# Examples:
#   validate_command_args "config.json" "output.txt"           # Valid
#   validate_command_args "file;cat /etc/passwd"               # Invalid
#   validate_command_args "$(whoami)"                          # Invalid
#   validate_command_args "file && malicious"                  # Invalid
validate_command_args() {
    local args=("$@")

    for arg in "${args[@]}"; do
        # Check for dangerous characters
        if [[ "$arg" =~ [\|\&\;\$\(\<\>] ]]; then
            log_error "Dangerous characters in argument: $arg"
            return 1
        fi
    done

    return 0
}

# Check if password is being passed unsafely in command line arguments
# Prevents password leakage into process lists, logs, and shell history
# Usage: check_password_security
# Returns: 0 if secure (no passwords in args), 1 if unsafe
# Examples:
#   BAD:  ./script.sh --password=secret123  # check_password_security will catch this
#   GOOD: export DB_PASSWORD=secret123 && ./script.sh
check_password_security() {
    if pgrep -f "password=" >/dev/null; then
        log_error "WARNING: Password detected in process arguments!"
        log_error "Use environment variables instead of command line arguments"
        return 1
    fi
    return 0
}

# Get or set project root directory
# Returns the project root path and validates it exists
# Usage: get_project_root
# Returns: Project root path on stdout, 1 on error
# Examples:
#   export PROJECT_ROOT="/custom/path"
#   root=$(get_project_root)  # Uses /custom/path
#   unset PROJECT_ROOT
#   root=$(get_project_root)  # Uses current directory
get_project_root() {
    local root="${PROJECT_ROOT:-$(pwd)}"

    # Validate it's a directory
    if [[ ! -d "$root" ]]; then
        log_error "Project root not found: $root"
        return 1
    fi

    echo "$root"
}

# ============================================
# Additional Security Utilities
# ============================================

# Sanitize filename by removing dangerous characters
# Usage: sanitize_filename "file/name;?.txt"
# Returns: Sanitized filename
# Example: sanitize_filename "my/file*.txt" => "my_file_.txt"
sanitize_filename() {
    local filename="$1"
    # Replace dangerous characters with underscore
    echo "$filename" | sed 's/[\/\\:*?"<>|]/_/g'
}

# Validate URL format
# Usage: validate_url "https://example.com"
# Returns: 0 if valid URL, 1 if invalid
validate_url() {
    local url="$1"
    # Basic URL validation regex
    local url_regex='^(https?|ftp)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

    if [[ ! "$url" =~ $url_regex ]]; then
        log_error "Invalid URL: $url"
        return 1
    fi

    return 0
}

# Validate email format
# Usage: validate_email "user@example.com"
# Returns: 0 if valid email, 1 if invalid
validate_email() {
    local email="$1"
    # Basic email validation regex
    local email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ ! "$email" =~ $email_regex ]]; then
        log_error "Invalid email: $email"
        return 1
    fi

    return 0
}

# Check for secrets in environment variables
# Usage: check_env_secrets
# Warns if sensitive environment variables are exported in shell
check_env_secrets() {
    local found_secrets=0

    # Check for common secret patterns in exported variables
    for var in $(compgen -e); do
        if [[ "$var" =~ (PASSWORD|SECRET|KEY|TOKEN|API_KEY|PRIVATE) ]]; then
            log_warning "Potential secret in environment: $var"
            found_secrets=1
        fi
    done

    if [[ $found_secrets -eq 1 ]]; then
        log_warning "Environment variables may contain sensitive data"
        log_warning "Ensure these are not logged or exposed"
    fi
}

# Validate port number
# Usage: validate_port "8080"
# Returns: 0 if valid port (1-65535), 1 if invalid
validate_port() {
    local port="$1"

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log_error "Invalid port number: $port (must be numeric)"
        return 1
    fi

    if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        log_error "Invalid port number: $port (must be 1-65535)"
        return 1
    fi

    return 0
}

# Escape string for safe use in grep patterns
# Usage: grep_escape "pattern.*special"
# Returns: Escaped pattern safe for grep
grep_escape() {
    local pattern="$1"
    # Escape special regex characters
    echo "$pattern" | sed 's/[][\.|$(){}^+*?]/\\&/g'
}

# ============================================
# Security Check Summary
# ============================================

# Run comprehensive security checks on inputs
# Usage: security_check "file_path" "version" "port"
# Returns: 0 if all checks pass, 1 if any fail
security_check() {
    local file_path="$1"
    local version="${2:-}"
    local port="${3:-}"
    local all_passed=0

    log_info "Running security checks..."

    # Validate file path
    if [[ -n "$file_path" ]]; then
        if validate_file_path "$file_path"; then
            log_info "PASS: File path validation passed"
        else
            all_passed=1
        fi
    fi

    # Validate version if provided
    if [[ -n "$version" ]]; then
        if validate_semver "$version"; then
            log_info "PASS: Version validation passed"
        else
            all_passed=1
        fi
    fi

    # Validate port if provided
    if [[ -n "$port" ]]; then
        if validate_port "$port"; then
            log_info "PASS: Port validation passed"
        else
            all_passed=1
        fi
    fi

    # Check password security
    if check_password_security; then
        log_info "PASS: Password security check passed"
    else
        all_passed=1
    fi

    if [[ $all_passed -eq 0 ]]; then
        log_info "PASS: All security checks passed"
        return 0
    else
        log_error "FAIL: Some security checks failed"
        return 1
    fi
}

# ============================================
# Issue Triage Security Functions
# ============================================

# Validate GitHub username format
is_valid_github_username() {
    local username="$1"

    # GitHub username rules: max 39 chars, alphanumeric and hyphens, cannot start/end with hyphen
    if [[ "$username" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate issue number
is_valid_issue_number() {
    local number="$1"

    # Issue numbers are positive integers
    if [[ "$number" =~ ^[0-9]+$ ]] && [[ "$number" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Validate and escape integer for SQL
validate_sql_int() {
    local input="$1"
    local default="${2:-0}"

    # Check if input is a valid integer
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        echo "$input"
    else
        echo "$default"
    fi
}

# Validate and escape identifier (table name, column name) for SQL
validate_sql_identifier() {
    local input="$1"

    # Only allow alphanumeric characters and underscores
    if [[ "$input" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "$input"
    else
        echo ""  # Return empty if invalid
    fi
}

# Check if GitHub user exists in repository
github_user_exists() {
    local username="$1"

    # Validate username format
    if ! is_valid_github_username "$username"; then
        log_warning "Invalid GitHub username format: $username"
        return 1
    fi

    # Check if user exists on GitHub
    if gh user view "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Sanitize label name for GitHub
sanitize_github_label() {
    local label="$1"

    # GitHub label rules: max 50 chars, no commas
    echo "$label" | tr -d ',' | cut -c1-50
}

# Sanitize comment text to prevent markup injection
sanitize_comment() {
    local text="$1"

    # Remove potentially dangerous HTML/markup
    # This is a basic sanitization - adjust based on your needs
    echo "$text" | sed 's/<script[^>]*>.*<\/script>//gi' | sed 's/<[^>]*>//g'
}

# Export issue triage security functions
export -f is_valid_github_username
export -f is_valid_issue_number
export -f validate_sql_int
export -f validate_sql_identifier
export -f github_user_exists
export -f sanitize_github_label
export -f sanitize_comment

# ============================================
# Branch Management Security Functions
# ============================================

# Check if branch is protected
# Usage: if is_protected_branch "main"; then ...; fi
# Returns: 0 if protected, 1 if not protected
is_protected_branch() {
    local branch="$1"
    local protected_branches="${2:-main master develop}"
    local protected_patterns="${3:-^release/.* ^hotfix/.*}"

    # Check exact matches
    for protected in $protected_branches; do
        if [[ "$branch" == "$protected" ]]; then
            return 0  # Is protected
        fi
    done

    # Check pattern matches
    for pattern in $protected_patterns; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0  # Is protected
        fi
    done

    return 1  # Not protected
}

# Validate branch can be deleted
# Usage: if can_delete_branch "feature/xyz"; then ...; fi
# Returns: 0 if can delete, 1 if protected
can_delete_branch() {
    local branch="$1"
    local protected_branches="${2:-main master develop}"
    local protected_patterns="${3:-^release/.* ^hotfix/.*}"

    if is_protected_branch "$branch" "$protected_branches" "$protected_patterns"; then
        log_error "Cannot delete protected branch: $branch"
        return 1
    fi

    return 0
}

# Validate branch name
# Usage: branch=$(validate_branch_name "feature/test")
# Returns: Escaped branch name or error
validate_branch_name() {
    local branch="$1"

    # Check for empty
    if [[ -z "$branch" ]]; then
        log_error "Branch name cannot be empty"
        return 1
    fi

    # Check for dangerous characters
    if [[ "$branch" == *"'"* ]] || [[ "$branch" == *'"'* ]] || [[ "$branch" == *';'* ]] || [[ "$branch" == *'\\'* ]]; then
        log_error "Branch name contains invalid characters"
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$branch" =~ \.\. ]]; then
        log_error "Branch name contains path traversal sequence"
        return 1
    fi

    # Return escaped version
    psql_escape "$branch"
    return 0
}

# Create backup directory for branch
# Usage: backup_dir=$(create_branch_backup "feature/test" "/project/root")
create_branch_backup() {
    local branch="$1"
    local project_root="${2:-.}"
    local backup_base="${project_root}/.git/branch-backups"

    # Create backup directory with timestamp
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="${backup_base}/${timestamp}"

    mkdir -p "$backup_dir" || {
        log_error "Failed to create backup directory: $backup_dir"
        return 1
    }

    echo "$backup_dir"
}

# Backup branch data
# Usage: backup_branch_data "feature/test" "/backup/dir" "/project/root"
backup_branch_data() {
    local branch="$1"
    local backup_dir="$2"
    local project_root="${3:-.}"

    cd "$project_root" || return 1

    # Get branch commit SHA
    local commit_sha
    commit_sha=$(git rev-parse "$branch" 2>/dev/null) || {
        log_error "Failed to get commit SHA for branch: $branch"
        return 1
    }

    # Save commit SHA
    echo "$commit_sha" > "${backup_dir}/${branch}.commit"

    # Archive branch contents
    if ! git archive "HEAD:$branch" > "${backup_dir}/${branch}.tar" 2>/dev/null; then
        # Fallback: create patch
        git diff "main...$branch" > "${backup_dir}/${branch}.patch" 2>/dev/null || true
    fi

    # Save branch metadata
    local commit_date
    local commit_author
    local commit_count

    commit_date=$(git log -1 --format='%ci' "$branch" 2>/dev/null)
    commit_author=$(git log -1 --format='%an' "$branch" 2>/dev/null)
    commit_count=$(git rev-list --count "$branch" 2>/dev/null)

    cat > "${backup_dir}/${branch}.metadata" << EOF
branch_name=$branch
commit_sha=$commit_sha
commit_date=$commit_date
commit_author=$commit_author
commit_count=$commit_count
backup_date=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
EOF

    # Create restore script
    cat > "${backup_dir}/restore.sh" << EOF
#!/bin/bash
#
# Restore script for branch: $branch
# Backup created: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
#

set -e

BRANCH_NAME="$branch"
BACKUP_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
COMMIT_SHA=\$(cat "\${BACKUP_DIR}/${branch}.commit")

echo "Restoring branch: \$BRANCH_NAME"
echo "From commit: \$COMMIT_SHA"

# Checkout main branch first
git checkout main 2>/dev/null || git checkout master 2>/dev/null

# Create and checkout branch
git checkout -b "\$BRANCH_NAME" "\$COMMIT_SHA"

echo "Branch \$BRANCH_NAME restored successfully from backup"
echo "Backup location: \$BACKUP_DIR"
EOF

    chmod +x "${backup_dir}/restore.sh"

    echo "$backup_dir"
    return 0
}

# Log deletion to file
# Usage: log_branch_deletion "feature/test" "/backup/dir" "/project/root"
log_branch_deletion() {
    local branch="$1"
    local backup_dir="$2"
    local project_root="${3:-.}"
    local deletion_log="${project_root}/.git/branch-deletions.log"

    local timestamp
    timestamp=$(date -u +'%Y-%m-%d %H:%M:%S UTC')

    echo "${timestamp}|DELETED|${branch}|${backup_dir}" >> "$deletion_log"

    return 0
}

# Restore branch from backup
# Usage: restore_branch_from_backup "/backup/dir"
restore_branch_from_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    if [[ ! -f "${backup_dir}/restore.sh" ]]; then
        log_error "Restore script not found in: $backup_dir"
        return 1
    fi

    # Execute restore script
    bash "${backup_dir}/restore.sh"
    return $?
}

# Check if PR already has a comment matching pattern
# Usage: if has_existing_comment "123" "stale branch"; then ...; fi
has_existing_comment() {
    local pr_number="$1"
    local search_pattern="$2"

    if ! command -v gh &>/dev/null; then
        log_warning "gh CLI not available, cannot check for existing comments"
        return 1  # Assume no comment exists
    fi

    # Get PR comments
    local comments
    comments=$(gh pr view "$pr_number" --json comments --jq '.comments[].body' 2>/dev/null || echo "")

    if [[ -z "$comments" ]]; then
        return 1  # No comments found
    fi

    # Check if any comment matches pattern
    if echo "$comments" | grep -q "$search_pattern"; then
        return 0  # Comment exists
    fi

    return 1  # No matching comment
}

# Clean up old branch records from database
# Usage: cleanup_old_branch_records 90
cleanup_old_branch_records() {
    local days_to_keep="${1:-90}"
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    # Validate days_to_keep
    if ! [[ "$days_to_keep" =~ ^[0-9]+$ ]]; then
        log_error "Invalid days_to_keep value: $days_to_keep"
        return 1
    fi

    local query="
DELETE FROM branch_history
WHERE detected_at < NOW() - INTERVAL '${days_to_keep} days';
"

    PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -A -c "$query" 2>/dev/null || {
        log_error "Failed to cleanup old branch records"
        return 1
    }

    log_info "Cleaned up branch records older than ${days_to_keep} days"
    return 0
}

# Get database size
# Usage: size=$(get_db_size)
get_db_size() {
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    local query="
SELECT pg_size_pretty(pg_database_size('$db_name'));
"

    PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -A -c "$query" 2>/dev/null || echo "Unknown"
}

# Get branch_history table size
# Usage: size=$(get_branch_history_size)
get_branch_history_size() {
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-woodpecker}"
    local db_user="${DB_USER:-woodpecker}"
    local db_password="${DB_PASSWORD:-woodpecker}"

    local query="
SELECT pg_size_pretty(pg_total_relation_size('branch_history'));
"

    PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -A -c "$query" 2>/dev/null || echo "Unknown"
}

# Validate branch format
# Usage: if validate_branch_format "feature/test"; then ...; fi
validate_branch_format() {
    local branch="$1"

    # Check for empty
    if [[ -z "$branch" ]]; then
        log_error "Branch name cannot be empty"
        return 1
    fi

    # Check length
    if [[ ${#branch} -gt 255 ]]; then
        log_error "Branch name too long (max 255 characters)"
        return 1
    fi

    # Check for dangerous characters
    if [[ "$branch" =~ [\;\&\|\\] ]]; then
        log_error "Branch name contains invalid characters"
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$branch" =~ \.\. ]]; then
        log_error "Branch name contains path traversal sequence"
        return 1
    fi

    return 0
}

# Validate commit SHA
# Usage: if validate_commit_sha "abc123"; then ...; fi
validate_commit_sha() {
    local sha="$1"

    # Check if empty
    if [[ -z "$sha" ]]; then
        return 0  # Empty is OK (optional field)
    fi

    # Check format (40 hex characters or abbreviated 8+)
    if [[ ! "$sha" =~ ^[a-f0-9]{8,}$ ]]; then
        log_error "Invalid commit SHA format: $sha"
        return 1
    fi

    return 0
}

# Log security event
# Usage: log_security_event "ACCESS" "delete|feature/test|success"
log_security_event() {
    local event_type="$1"
    local message="$2"
    local project_root="${3:-.}"
    local security_log="${project_root}/.git/security-events.log"

    local timestamp
    timestamp=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
    local script_name="${BASH_SOURCE[2]##*/}"

    echo "${timestamp}|${event_type}|${script_name}|${message}" >> "$security_log"

    return 0
}

# Log access attempt
# Usage: log_access_attempt "feature/test" "delete" "success"
log_access_attempt() {
    local resource="$1"
    local action="${2:-access}"
    local result="${3:-success}"

    log_security_event "ACCESS" "$action|$resource|$result"
}

# Log security violation
# Usage: log_security_violation "protected_branch" "main"
log_security_violation() {
    local violation_type="$1"
    local details="$2"

    log_security_event "VIOLATION" "$violation_type|$details"
}

# Export branch management security functions
export -f is_protected_branch
export -f can_delete_branch
export -f validate_branch_name
export -f create_branch_backup
export -f backup_branch_data
export -f log_branch_deletion
export -f restore_branch_from_backup
export -f has_existing_comment
export -f cleanup_old_branch_records
export -f get_db_size
export -f get_branch_history_size
export -f validate_branch_format
export -f validate_commit_sha
export -f log_security_event
export -f log_access_attempt
export -f log_security_violation
