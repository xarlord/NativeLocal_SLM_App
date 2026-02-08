# Quick Fix Guide: Applying Common Fixes to Scripts

This guide provides copy-paste templates for applying the common fixes to any script.

## Fix 1: Add PROJECT_ROOT Support

### Location: Top of script, after SCRIPT_DIR is defined

**Find:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

**Replace with:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
```

## Fix 2: Add Error Handling Trap

### Location: Right after `set -euo pipefail`

**Add after:**
```bash
set -euo pipefail

# Error handling trap
trap cleanup EXIT

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code: $exit_code"
        if type -t send_error_notification >/dev/null; then
            send_error_notification "Script failed with exit code $exit_code"
        fi
    fi
}
```

## Fix 3: Add jq Check and Fallback Functions

### Location: In the helper functions section

**Add:**
```bash
# Check if jq is available
has_jq() {
    command -v jq >/dev/null 2>&1
}

# Get JSON field with jq fallback
json_get_field() {
    local json="$1"
    local field="$2"

    if has_jq; then
        echo "${json}" | jq -r "${field}"
    else
        # Fallback: parse with grep/sed
        local field_name="${field#*.}"
        field_name="${field_name//\"/}"
        echo "${json}" | grep -o "\"${field_name}\":\"[^\"]*\"" | cut -d'"' -f4 || echo ""
    fi
}

# Get array length with jq fallback
json_array_length() {
    local json="$1"

    if has_jq; then
        echo "${json}" | jq 'length' 2>/dev/null || echo "0"
    else
        # Fallback: count commas + 1
        echo "${json}" | grep -o ',' | wc -l | awk '{print $1 + 1}'
    fi
}
```

## Fix 4: Add Rate Limit Checking

### Location: In the helper functions section

**Add:**
```bash
# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    if has_jq; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
    else
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    if [[ ${remaining} -lt 100 ]]; then
        log_warning "GitHub API rate limit low: ${remaining} remaining"
        sleep 10
    fi
}
```

## Fix 5: Replace jq Calls with Fallback Wrappers

### Pattern A: Getting a JSON field

**Find:**
```bash
title=$(echo "${json}" | jq -r '.title')
```

**Replace with:**
```bash
title=$(json_get_field "${json}" '.title')
```

### Pattern B: Getting array length

**Find:**
```bash
count=$(echo "${array}" | jq 'length')
```

**Replace with:**
```bash
count=$(json_array_length "${array}")
```

### Pattern C: Complex jq expressions

**Find:**
```bash
result=$(echo "${json}" | jq -r '.field | .subfield')
```

**Replace with:**
```bash
if has_jq; then
    result=$(echo "${json}" | jq -r '.field | .subfield')
else
    # Fallback for complex expressions
    result=$(echo "${json}" | grep -o '"field":{[^}]*}' | grep -o '"subfield":"[^"]*"' | cut -d'"' -f4 || echo "")
fi
```

## Fix 6: Add Rate Limit Checks Before API Calls

### Location: Before loops or multiple gh commands

**Find:**
```bash
gh issue list ...
gh issue view ...
gh pr list ...
```

**Add before:**
```bash
check_github_rate_limit
gh issue list ...
```

**For loops:**
```bash
# Before loop
check_github_rate_limit

for number in $numbers; do
    gh issue view "$number" ...
    # Add check every 10 iterations
    if (( $((count % 10)) == 0 )); then
        check_github_rate_limit
    fi
done
```

## Complete Example: Minimal Script Template

```bash
#!/bin/bash
# script-name.sh
# Description

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Error handling trap
trap cleanup EXIT

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR: Script failed with exit code: $exit_code"
    fi
}

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

# Check if jq is available
has_jq() {
    command -v jq >/dev/null 2>&1
}

# Check GitHub API rate limit
check_github_rate_limit() {
    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    local remaining
    if has_jq; then
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | jq -r '.resources.core.remaining // 5000')
    else
        remaining=$(gh api -X GET /rate_limit 2>/dev/null | grep -o '"remaining":[0-9]*' | cut -d':' -f2 | head -1 || echo "5000")
    fi

    if [[ ${remaining} -lt 100 ]]; then
        log "WARNING: GitHub API rate limit low: ${remaining} remaining"
        sleep 10
    fi
}

# JSON helper functions
json_get_field() {
    local json="$1"
    local field="$2"

    if has_jq; then
        echo "${json}" | jq -r "${field}"
    else
        local field_name="${field#*.}"
        field_name="${field_name//\"/}"
        echo "${json}" | grep -o "\"${field_name}\":\"[^\"]*\"" | cut -d'"' -f4 || echo ""
    fi
}

json_array_length() {
    local json="$1"

    if has_jq; then
        echo "${json}" | jq 'length' 2>/dev/null || echo "0"
    else
        echo "${json}" | grep -o ',' | wc -l | awk '{print $1 + 1}'
    fi
}

# ============================================
# Main Functions
# ============================================

main() {
    log "Starting script..."

    check_github_rate_limit

    # Your script logic here
}

# Run main
main "$@"
```

## Quick Checklist for Each Script

Use this checklist to verify all fixes are applied:

- [ ] **PROJECT_ROOT**: Changed to `${PROJECT_ROOT:-...}` format
- [ ] **Error Trap**: Added `trap cleanup EXIT` after `set -euo pipefail`
- [ ] **cleanup() function**: Added error handler
- [ ] **has_jq()**: Added jq check function
- [ ] **json_get_field()**: Added JSON field helper (if script parses JSON)
- [ ] **json_array_length()**: Added array length helper (if script counts JSON items)
- [ ] **check_github_rate_limit()**: Added rate limit function (if script uses gh CLI)
- [ ] **jq calls replaced**: All direct jq calls use wrapper functions or have fallbacks
- [ ] **Rate limit checks**: Added before loops or multiple gh commands

## Using the common.sh Library

Even better - source the common library instead of defining helpers:

```bash
# After configuration section
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source common functions
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
    init_common
else
    # Fallback if common.sh not available
    log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2; }
    trap cleanup EXIT
    cleanup() {
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            log "Script failed with exit code: $exit_code"
        fi
    }
fi
```

This provides all the helper functions automatically.

---

*For detailed information, see: COMMON_FIXES_SUMMARY.md*
