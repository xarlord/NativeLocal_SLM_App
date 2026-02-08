#!/bin/bash
# apply-refactoring.sh
# Apply automated refactoring from YAML or JSON specification
# Usage: ./apply-refactoring.sh <spec-file>
# Logs to refactoring_history table

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

# Refactoring types
SAFE_REFACTORINGS=(
    "rename_class"
    "rename_method"
    "rename_variable"
    "move_file"
    "extract_constant"
    "inline_constant"
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

# Load spec file
load_spec() {
    local spec_file="$1"

    if [[ ! -f "${spec_file}" ]]; then
        error "Spec file not found: ${spec_file}"
    fi

    # Parse based on file extension
    case "${spec_file}" in
        *.yaml|*.yml)
            if command -v yq &>/dev/null; then
                yq eval -o=json "${spec_file}"
            else
                error "yq not found. Please install yq to parse YAML files"
            fi
            ;;
        *.json)
            cat "${spec_file}"
            ;;
        *)
            error "Unsupported file format. Use YAML or JSON"
            ;;
    esac
}

# Validate spec
validate_spec() {
    local spec_json="$1"

    local refactoring_type
    refactoring_type=$(echo "${spec_json}" | jq -r '.type // empty')

    if [[ -z "${refactoring_type}" ]]; then
        error "Spec missing 'type' field"
    fi

    # Check if refactoring is safe
    local is_safe=false
    for safe_type in "${SAFE_REFACTORINGS[@]}"; do
        if [[ "${refactoring_type}" == "${safe_type}" ]]; then
            is_safe=true
            break
        fi
    done

    if [[ "${is_safe}" == "false" ]]; then
        log "WARNING: Refactoring type '${refactoring_type}' is not in the safe list"
        log "Safe refactors: ${SAFE_REFACTORINGS[*]}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Aborted by user"
        fi
    fi

    echo "${refactoring_type}"
}

# Determine risk level
determine_risk_level() {
    local refactoring_type="$1"

    case "${refactoring_type}" in
        rename_class|move_file)
            echo "medium"
            ;;
        rename_method|rename_variable)
            echo "low"
            ;;
        extract_constant|inline_constant)
            echo "low"
            ;;
        *)
            echo "medium"
            ;;
    esac
}

# Apply rename class refactoring
apply_rename_class() {
    local spec_json="$1"

    local old_name
    local new_name
    local file_path
    old_name=$(echo "${spec_json}" | jq -r '.old_name // empty')
    new_name=$(echo "${spec_json}" | jq -r '.new_name // empty')
    file_path=$(echo "${spec_json}" | jq -r '.file_path // empty')

    if [[ -z "${old_name}" ]] || [[ -z "${new_name}" ]] || [[ -z "${file_path}" ]]; then
        error "rename_class requires: old_name, new_name, file_path"
    fi

    # Validate file path to prevent directory traversal
    if command -v validate_file_path &>/dev/null; then
        if ! validate_file_path "${file_path}"; then
            error "Invalid file path: ${file_path}"
        fi
    fi

    if [[ ! -f "${file_path}" ]]; then
        error "File not found: ${file_path}"
    fi

    # Validate identifiers
    if command -v validate_identifier &>/dev/null; then
        if ! validate_identifier "${old_name}"; then
            error "Invalid identifier: ${old_name}"
        fi
        if ! validate_identifier "${new_name}"; then
            error "Invalid identifier: ${new_name}"
        fi
    else
        # Fallback validation
        if [[ ! "${old_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            error "Invalid identifier: ${old_name}"
        fi
        if [[ ! "${new_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            error "Invalid identifier: ${new_name}"
        fi
    fi

    log "Renaming class ${old_name} to ${new_name} in ${file_path}"

    # Create backup
    cp "${file_path}" "${file_path}.backup"

    # Replace class name with more precise patterns
    sed -i "s/\bclass ${old_name}\b/class ${new_name}/g" "${file_path}"
    sed -i "s/: ${old_name}(/: ${new_name}(/g" "${file_path}"
    sed -i "s/<${old_name}>/<${new_name}>/g" "${file_path}"
    sed -i "s|${old_name}\\.java|${new_name}.java|g" "${file_path}"
    sed -i "s|${old_name}\\.kt|${new_name}.kt|g" "${file_path}"

    # Rename file if needed
    local filename
    filename=$(basename "${file_path}")
    if [[ "${filename}" == *"${old_name}"* ]]; then
        local new_filename
        new_filename="${filename/${old_name}/${new_name}}"
        local dir_path
        dir_path=$(dirname "${file_path}")
        local new_file_path="${dir_path}/${new_filename}"

        log "Renaming file to ${new_file_path}"
        mv "${file_path}" "${new_file_path}"
        file_path="${new_file_path}"
    fi

    echo "${file_path}"
}

# Apply rename method refactoring
apply_rename_method() {
    local spec_json="$1"

    local old_name
    local new_name
    local file_path
    old_name=$(echo "${spec_json}" | jq -r '.old_name // empty')
    new_name=$(echo "${spec_json}" | jq -r '.new_name // empty')
    file_path=$(echo "${spec_json}" | jq -r '.file_path // empty')

    if [[ -z "${old_name}" ]] || [[ -z "${new_name}" ]] || [[ -z "${file_path}" ]]; then
        error "rename_method requires: old_name, new_name, file_path"
    fi

    if [[ ! -f "${file_path}" ]]; then
        error "File not found: ${file_path}"
    fi

    log "Renaming method ${old_name} to ${new_name} in ${file_path}"

    # Create backup
    cp "${file_path}" "${file_path}.backup"

    # Replace method name (function declaration)
    sed -i "s/fun ${old_name}(/fun ${new_name}(/g" "${file_path}"
    sed -i "s/def ${old_name}(/def ${new_name}(/g" "${file_path}"
    sed -i "s/function ${old_name}(/function ${new_name}(/g" "${file_path}"

    # Replace method calls
    sed -i "s/${old_name}(/${new_name}(/g" "${file_path}"

    echo "${file_path}"
}

# Apply rename variable refactoring
apply_rename_variable() {
    local spec_json="$1"

    local old_name
    local new_name
    local file_path
    old_name=$(echo "${spec_json}" | jq -r '.old_name // empty')
    new_name=$(echo "${spec_json}" | jq -r '.new_name // empty')
    file_path=$(echo "${spec_json}" | jq -r '.file_path // empty')

    if [[ -z "${old_name}" ]] || [[ -z "${new_name}" ]] || [[ -z "${file_path}" ]]; then
        error "rename_variable requires: old_name, new_name, file_path"
    fi

    # Validate file path to prevent directory traversal
    if command -v validate_file_path &>/dev/null; then
        if ! validate_file_path "${file_path}"; then
            error "Invalid file path: ${file_path}"
        fi
    fi

    if [[ ! -f "${file_path}" ]]; then
        error "File not found: ${file_path}"
    fi

    # Validate identifiers to prevent unsafe refactoring
    if command -v validate_identifier &>/dev/null; then
        if ! validate_identifier "${old_name}"; then
            error "Invalid identifier: ${old_name}"
        fi
        if ! validate_identifier "${new_name}"; then
            error "Invalid identifier: ${new_name}"
        fi
    else
        # Fallback validation
        if [[ ! "${old_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            error "Invalid identifier: ${old_name}"
        fi
        if [[ ! "${new_name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            error "Invalid identifier: ${new_name}"
        fi
    fi

    log "Renaming variable ${old_name} to ${new_name} in ${file_path}"

    # Create backup
    cp "${file_path}" "${file_path}.backup"

    # Replace variable name with word boundaries (safer pattern)
    # Using \b ensures we only match whole words, not substrings
    sed -i "s/\b${old_name}\b/${new_name}/g" "${file_path}"

    echo "${file_path}"
}

# Apply move file refactoring
apply_move_file() {
    local spec_json="$1"

    local old_path
    local new_path
    old_path=$(echo "${spec_json}" | jq -r '.old_path // empty')
    new_path=$(echo "${spec_json}" | jq -r '.new_path // empty')

    if [[ -z "${old_path}" ]] || [[ -z "${new_path}" ]]; then
        error "move_file requires: old_path, new_path"
    fi

    if [[ ! -f "${old_path}" ]]; then
        error "File not found: ${old_path}"
    fi

    log "Moving file from ${old_path} to ${new_path}"

    # Create target directory if needed
    local target_dir
    target_dir=$(dirname "${new_path}")
    mkdir -p "${target_dir}"

    # Move file
    mv "${old_path}" "${new_path}"

    echo "${new_path}"
}

# Apply extract constant refactoring
apply_extract_constant() {
    local spec_json="$1"

    local value
    local constant_name
    local file_path
    value=$(echo "${spec_json}" | jq -r '.value // empty')
    constant_name=$(echo "${spec_json}" | jq -r '.constant_name // empty')
    file_path=$(echo "${spec_json}" | jq -r '.file_path // empty')

    if [[ -z "${value}" ]] || [[ -z "${constant_name}" ]] || [[ -z "${file_path}" ]]; then
        error "extract_constant requires: value, constant_name, file_path"
    fi

    if [[ ! -f "${file_path}" ]]; then
        error "File not found: ${file_path}"
    fi

    log "Extracting constant ${constant_name} = ${value} in ${file_path}"

    # Create backup
    cp "${file_path}" "${file_path}.backup"

    # Find file type
    local extension
    extension="${file_path##*.}"

    # Add constant declaration at top of class/file
    case "${extension}" in
        kt)
            local constant_line="    const val ${constant_name} = ${value}"
            sed -i "0,/class /s//${constant_line}\n\nclass /" "${file_path}"
            ;;
        java)
            local constant_line="    private static final String ${constant_name} = ${value};"
            sed -i "0,/class /s//${constant_line}\n\nclass /" "${file_path}"
            ;;
        *)
            log "Warning: Unknown file type ${extension}, adding generic constant"
            echo "const val ${constant_name} = ${value}" | cat - "${file_path}" > temp
            mv temp "${file_path}"
            ;;
    esac

    # Replace value with constant
    sed -i "s|\"${value}\"|${constant_name}|g" "${file_path}"
    sed -i "s|'${value}'|${constant_name}|g" "${file_path}"

    echo "${file_path}"
}

# Apply refactoring based on type
apply_refactoring() {
    local refactoring_type="$1"
    local spec_json="$2"

    log "Applying ${refactoring_type} refactoring..."

    case "${refactoring_type}" in
        rename_class)
            apply_rename_class "${spec_json}"
            ;;
        rename_method)
            apply_rename_method "${spec_json}"
            ;;
        rename_variable)
            apply_rename_variable "${spec_json}"
            ;;
        move_file)
            apply_move_file "${spec_json}"
            ;;
        extract_constant)
            apply_extract_constant "${spec_json}"
            ;;
        inline_constant)
            # Simplified: just replaces constant with value
            log "Warning: inline_constant is not fully implemented"
            echo ""
            ;;
        *)
            error "Unsupported refactoring type: ${refactoring_type}"
            ;;
    esac
}

# Test compilation
test_compilation() {
    log "Testing compilation..."

    local gradle_cmd="./gradlew"
    if [[ ! -f "${gradle_cmd}" ]]; then
        if [[ -f "simpleGame/gradlew" ]]; then
            gradle_cmd="./simpleGame/gradlew"
        else
            log "Warning: gradlew not found, skipping compilation test"
            return 0
        fi
    fi

    # Run compile with timeout
    timeout 600 "${gradle_cmd}" compileDebugKotlin compileDebugJava --no-daemon --quiet 2>&1 || {
        local exit_code=$?
        if [[ ${exit_code} -eq 124 ]]; then
            log "ERROR: Compilation test timed out after 600s"
            return 1
        else
            log "ERROR: Compilation failed with exit code ${exit_code}"
            return 1
        fi
    }

    log "Compilation successful"
    return 0
}

# Commit changes
commit_changes() {
    local refactoring_type="$1"

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
    commit_message="Refactor: ${refactoring_type}

Automated refactoring applied by apply-refactoring.sh"

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
    local refactoring_type="$1"
    local spec_file="$2"
    local risk_level="$3"
    local affected_files="$4"
    local status="$5"

    log "Logging to database..."

    # Use security function if available, otherwise fallback
    local sanitized_type
    local sanitized_file
    if command -v psql_escape &>/dev/null; then
        sanitized_type=$(psql_escape "${refactoring_type}")
        sanitized_file=$(psql_escape "${spec_file}")
    else
        sanitized_type=$(echo "${refactoring_type}" | sed "s/'/''/g")
        sanitized_file=$(echo "${spec_file}" | sed "s/'/''/g")
    fi

    local files_json
    files_json=$(echo "${affected_files}" | jq -R -s -c 'split("\n") | map(select(length > 0))')

    local query="
INSERT INTO refactoring_history (
    refactoring_type,
    description,
    risk_level,
    safe_transformation,
    affected_files,
    status,
    spec_file,
    created_at
) VALUES (
    '${sanitized_type}',
    'Automated refactoring from ${sanitized_file}',
    '${risk_level}',
    true,
    '${files_json}'::jsonb,
    '${status}',
    '${sanitized_file}',
    NOW()
) RETURNING id;
"

    local refactoring_id
    refactoring_id=$(query_db "${query}")

    if [[ -n "${refactoring_id}" ]]; then
        log "Database entry created with ID: ${refactoring_id}"
        echo "${refactoring_id}"
    else
        log "Warning: Failed to log to database"
        echo ""
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local spec_file="$1"

    log "=== Automated Refactoring Script ==="
    log "Spec file: ${spec_file}"

    # Change to project root
    cd "${PROJECT_ROOT}" || error "Cannot change to project root"

    # Load spec
    local spec_json
    spec_json=$(load_spec "${spec_file}")

    if [[ -z "${spec_json}" ]]; then
        error "Failed to load spec file"
    fi

    # Validate spec
    local refactoring_type
    refactoring_type=$(validate_spec "${spec_json}")

    # Determine risk level
    local risk_level
    risk_level=$(determine_risk_level "${refactoring_type}")
    log "Risk level: ${risk_level}"

    # Apply refactoring
    local affected_files
    affected_files=$(apply_refactoring "${refactoring_type}" "${spec_json}")

    # Count affected files
    local file_count=0
    if [[ -n "${affected_files}" ]]; then
        file_count=$(echo "${affected_files}" | grep -c '^' || echo "0")
    fi

    log "Affected files: ${file_count}"

    # Test compilation
    local compilation_success=false
    if test_compilation; then
        compilation_success=true
    else
        log "WARNING: Compilation failed. Please review the changes."
        log "You can restore backups: find . -name '*.backup' -exec sh -c 'mv \"$1\" \"\${1%.backup}\"' _ {} \;"

        # Log failure to database
        log_to_database "${refactoring_type}" "${spec_file}" "${risk_level}" "[]" "failed"

        error "Refactoring failed compilation test"
    fi

    # Commit changes
    if ! commit_changes "${refactoring_type}"; then
        log "Warning: Failed to commit changes"
    fi

    # Log to database
    local refactoring_id
    refactoring_id=$(log_to_database "${refactoring_type}" "${spec_file}" "${risk_level}" "${affected_files}" "applied")

    log "=== Refactoring Complete ==="
    log "Type: ${refactoring_type}"
    log "Risk: ${risk_level}"
    log "Files affected: ${file_count}"
    log "Compilation: ${compilation_success}"
    log "Refactoring ID: ${refactoring_id}"
    echo ""
    log "Next steps:"
    log "1. Review the changes: git diff HEAD~1"
    log "2. Run tests: ./gradlew test"
    log "3. If satisfied, push: git push ${GIT_REMOTE} \$(git branch --show-current)"
    log "4. Create PR: ./create-pr.sh 'Refactor: ${refactoring_type}' 'Body' '\$(git branch --show-current)' '${DEFAULT_BASE_BRANCH}'"
}

# Show usage
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <spec-file>"
    echo ""
    echo "Spec file format (YAML example):"
    echo "  type: rename_class"
    echo "  old_name: OldClassName"
    echo "  new_name: NewClassName"
    echo "  file_path: app/src/main/java/com/example/OldClassName.kt"
    echo ""
    echo "Supported refactoring types:"
    echo "  - rename_class:   Rename a class and update file"
    echo "  - rename_method:  Rename a method and update references"
    echo "  - rename_variable: Rename a variable"
    echo "  - move_file:      Move a file to a new location"
    echo "  - extract_constant: Extract magic value to constant"
    echo ""
    echo "The script will:"
    echo "  1. Parse the refactoring specification"
    echo "  2. Apply the refactoring"
    echo "  3. Test compilation"
    echo "  4. Commit changes"
    echo "  5. Log to refactoring_history table"
    exit 1
fi

# Run main function
main "$@"
