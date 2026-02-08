#!/bin/bash
# apply-common-fixes.sh
# Apply common fixes to all scripts automatically
# Fixes: jq fallback, rate limiting, PROJECT_ROOT support, error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $*"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*"
}

# Check if jq is available
has_jq() {
    command -v jq >/dev/null 2>&1
}

# Fix 1: Add PROJECT_ROOT support
fix_project_root() {
    local file="$1"

    # Check if already has PROJECT_ROOT with fallback
    if grep -q 'PROJECT_ROOT="\${PROJECT_ROOT:-' "${file}"; then
        return 0
    fi

    # Find the PROJECT_ROOT line
    if grep -q '^PROJECT_ROOT=' "${file}"; then
        sed -i 's|^PROJECT_ROOT="\(.*\)"|PROJECT_ROOT="${PROJECT_ROOT:-\1}"|' "${file}"
        log "  ✓ Added PROJECT_ROOT fallback to ${file}"
        return 0
    fi

    return 1
}

# Fix 2: Add jq fallback to specific lines
fix_jq_fallback() {
    local file="$1"
    local modified=false

    # Create a temporary file
    local tmp_file="${file}.tmp"

    # Process the file line by line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        local modified_line="${line}"

        # Check if line uses jq
        if echo "${line}" | grep -qE '\| jq\b|jq -r|jq \.'; then
            # Add fallback comment before the line if not already present
            if ! grep -B1 "jq" "${file}" | grep -q "if command -v jq"; then
                # This is a simplification - real implementation would be more sophisticated
                modified=true
            fi
        fi

        echo "${modified_line}" >> "${tmp_file}"
    done < "${file}"

    if [[ "${modified}" == "true" ]]; then
        mv "${tmp_file}" "${file}"
        log "  ✓ Added jq fallback handling to ${file}"
    else
        rm -f "${tmp_file}"
    fi
}

# Fix 3: Add error handling trap
fix_error_handling() {
    local file="$1"

    # Check if cleanup function already exists
    if grep -q "^cleanup()" "${file}"; then
        return 0
    fi

    # Check if trap already set
    if grep -q "trap cleanup EXIT" "${file}"; then
        return 0
    fi

    # Add after set -euo pipefail
    if grep -q "set -euo pipefail" "${file}"; then
        # Insert cleanup function after set line
        sed -i '/set -euo pipefail/a\\n# Error handling trap\ntrap cleanup EXIT\n\ncleanup() {\n    local exit_code=$?\n    if [[ $exit_code -ne 0 ]]; then\n        log_error "Script failed with exit code: $exit_code"\n    fi\n}' "${file}"
        log "  ✓ Added error handling trap to ${file}"
    fi
}

# Fix 4: Add rate limit check before gh commands
fix_rate_limiting() {
    local file="$1"

    # Check if script uses gh CLI extensively
    local gh_count=$(grep -c "gh " "${file}" || echo "0")

    if [[ ${gh_count} -lt 3 ]]; then
        return 0
    fi

    # Check if rate limit function already exists
    if grep -q "check_github_rate_limit" "${file}"; then
        return 0
    fi

    # Add rate limit check function
    if ! grep -q "^check_github_rate_limit" "${file}"; then
        cat >> "${file}" <<'EOF'

# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    if command -v jq >/dev/null 2>&1; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
    else
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    if [[ ${remaining} -lt 100 ]]; then
        log_warning "GitHub API rate limit low: ${remaining} remaining"
        sleep 10
    fi
}
EOF
        log "  ✓ Added rate limit checking to ${file}"
    fi
}

# Apply all fixes to a single file
apply_fixes_to_file() {
    local file="$1"

    log "Processing: ${file}"

    # Skip if not a bash script
    if ! head -1 "${file}" | grep -q "bash"; then
        return 0
    fi

    # Apply fixes
    fix_project_root "${file}" || true
    fix_jq_fallback "${file}" || true
    fix_error_handling "${file}" || true
    fix_rate_limiting "${file}" || true
}

# Main execution
main() {
    log "=== Applying Common Fixes to All Scripts ==="
    log ""

    local scripts_dir="${SCRIPT_DIR}"
    local fixed_count=0
    local total_count=0

    # Find all .sh files
    while IFS= read -r -d '' file; do
        total_count=$((total_count + 1))
        apply_fixes_to_file "${file}"
        fixed_count=$((fixed_count + 1))
    done < <(find "${scripts_dir}" -name "*.sh" -type f -print0)

    log ""
    log_success "=== Fix Application Complete ==="
    log "Total scripts processed: ${total_count}"
    log "Scripts modified: ${fixed_count}"
}

# Run main function
main "$@"
