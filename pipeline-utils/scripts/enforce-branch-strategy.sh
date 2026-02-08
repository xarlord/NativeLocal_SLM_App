#!/bin/bash
################################################################################
# Enforce Branch Strategy Script
# Part of Feature 4: Branch Management Automation
#
# Enforces branch naming conventions by validating branch names against
# regex patterns defined in config. Rejects invalid branch names and logs
# enforcement actions to database.
#
# Usage:
#   ./enforce-branch-strategy.sh [branch-name]
#
# Examples:
#   ./enforce-branch-strategy.sh feature/user-auth
#   ./enforce-branch-strategy.sh --check-all
#   ./enforce-branch-strategy.sh --fix-name my-feature-branch
################################################################################

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/pipeline-utils/config"
CONFIG_FILE="${CONFIG_DIR}/branch-strategy.yaml"

# Source security utilities
if [[ -f "${SCRIPT_DIR}/security-utils.sh" ]]; then
    source "${SCRIPT_DIR}/security-utils.sh"
else
    echo "WARNING: security-utils.sh not found, security features disabled" >&2
fi

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Default values
MODE="validate"  # validate, check-all, fix-name
BRANCH_NAME=""
OUTPUT_FORMAT="text"
LOG_TO_DB=true
VERBOSE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

usage() {
    cat << EOF
Usage: $0 [options] [branch-name]

Validate and enforce branch naming conventions.

Modes:
  validate [branch-name]    Validate a specific branch name (default)
  --check-all               Check all local branches
  --fix-name [name]         Suggest corrected name for invalid branch

Options:
  -f, --format FORMAT      Output format: text, json (default: text)
  --no-db                  Skip database logging
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message

Supported Branch Types (examples):
  feature/user-auth        Feature branches for new functionality
  bugfix/login-crash       Bugfix branches for defect fixes
  hotfix/security-fix      Hotfix branches for production emergencies
  release/v1.0.0           Release branches for version releases
  support/v1.0.x           Support branches for long-term maintenance
  docs/api-guide           Documentation branches
  refactor/cleanup-code    Refactoring branches
  experiment/new-idea      Experimental branches

Examples:
  # Validate a branch name
  $0 feature/user-authentication

  # Check all local branches
  $0 --check-all

  # Get suggestion for fixing invalid name
  $0 --fix-name MyFeatureBranch

  # Validate with JSON output
  $0 --format json feature/new-feature

Exit Codes:
  0      Validation passed
  1      Validation failed
  2      No branches to validate
  3      Invalid arguments

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --check-all)
                MODE="check-all"
                shift
                ;;
            --fix-name)
                MODE="fix-name"
                BRANCH_NAME="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --no-db)
                LOG_TO_DB=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$BRANCH_NAME" ]]; then
                    BRANCH_NAME="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json)$ ]]; then
        error "Invalid output format: $OUTPUT_FORMAT"
    fi
}

# Load configuration from YAML
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "Config file not found: $CONFIG_FILE"
        log "Using default branch naming rules"
        return 1
    fi

    # Extract protected branches
    PROTECTED_BRANCHES=$(grep -A 10 "^protected_branches:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")

    # Extract rejected patterns
    REJECTED_PATTERNS=$(grep -A 10 "^rejected_patterns:" "$CONFIG_FILE" | grep "^  -" | sed 's/^  - //' || echo "")

    log "Loaded configuration from: $CONFIG_FILE"
    return 0
}

# Database query function (with SQL injection protection)
query_db() {
    local query="$1"
    # Query should be escaped by caller
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Log enforcement action to database
log_enforcement_to_db() {
    local branch="$1"
    local result="$2"
    local matched_pattern="${3:-none}"
    local suggested_name="${4:-}"

    if [[ "$LOG_TO_DB" != "true" ]]; then
        return 0
    fi

    # Validate and escape inputs using security functions
    if declare -f validate_branch_name > /dev/null; then
        branch=$(validate_branch_name "$branch") || return 1
        result=$(psql_escape "$result")
        matched_pattern=$(psql_escape "$matched_pattern")
        suggested_name=$(psql_escape "$suggested_name")
    else
        # Basic escaping
        branch="${branch//\'/''}"
        result="${result//\'/''}"
        matched_pattern="${matched_pattern//\'/''}"
        suggested_name="${suggested_name//\'/''}"
    fi

    local query="
INSERT INTO branch_history (
  branch_name, status, category, detected_at
) VALUES (
  '$branch', '$result', 'validation:$matched_pattern', NOW()
)
ON CONFLICT (branch_name, detected_at) DO UPDATE SET
  status = EXCLUDED.status,
  category = EXCLUDED.category;
"

    query_db "$query" >/dev/null

    [[ $VERBOSE -eq 1 ]] && log "  Logged enforcement to DB: $branch -> $result"
}

# Check if branch is protected
is_protected() {
    local branch="$1"

    # Use centralized security function if available
    if declare -f is_protected_branch > /dev/null; then
        is_protected_branch "$branch" "$PROTECTED_BRANCHES"
        return $?
    fi

    # Fallback to local implementation
    local protected
    for protected in $PROTECTED_BRANCHES; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done

    return 1
}

# Check if branch matches rejected pattern
is_rejected() {
    local branch="$1"
    local pattern

    for pattern in $REJECTED_PATTERNS; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# Validate branch name against patterns
validate_branch_name() {
    local branch="$1"
    local branch_type="$2"

    # Define branch patterns
    local patterns=(
        "feature/^feature/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "bugfix/^bugfix/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "hotfix/^hotfix/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "release/^release/v[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9]+)?$"
        "support/^support/v[0-9]+\.[0-9]+\.x$"
        "docs/^docs/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "refactor/^refactor/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "experiment/^experiment/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
        "test/^test/[a-z0-9-]+(?:-[a-z0-9-]+)*$"
    )

    # Check each pattern
    for pattern_entry in "${patterns[@]}"; do
        local type="${pattern_entry%%/*}"
        local regex="${pattern_entry#*/}"

        if [[ "$branch" =~ $regex ]]; then
            echo "valid|$type|$regex"
            return 0
        fi
    done

    echo "invalid|none|none"
    return 1
}

# Suggest corrected branch name
suggest_fix() {
    local branch="$1"

    # Convert to lowercase and replace spaces with hyphens
    local suggested
    suggested=$(echo "$branch" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr '_' '-')

    # Remove special characters except hyphens
    suggested=$(echo "$suggested" | sed 's/[^a-z0-9-]//g')

    # Remove consecutive hyphens
    suggested=$(echo "$suggested" | sed 's/-\+/-/g')

    # Remove leading/trailing hyphens
    suggested=$(echo "$suggested" | sed 's/^-\+//;s/-\+$//')

    # If empty, suggest a default
    if [[ -z "$suggested" ]]; then
        suggested="feature/untitled"
    fi

    # Try to determine type from original name
    if [[ "$branch" =~ [Ff]eature ]]; then
        suggested="feature/${suggested#feature-}"
    elif [[ "$branch" =~ [Bb]ugfix ]]; then
        suggested="bugfix/${suggested#bugfix-}"
    elif [[ "$branch" =~ [Hh]otfix ]]; then
        suggested="hotfix/${suggested#hotfix-}"
    elif [[ "$branch" =~ [Rr]elease ]]; then
        suggested="release/${suggested#release-}"
    elif [[ "$branch" =~ [Dd]oc ]]; then
        suggested="docs/${suggested#docs-}"
    elif [[ "$branch" =~ [Rr]efactor ]]; then
        suggested="refactor/${suggested#refactor-}"
    elif [[ "$branch" =~ [Ee]xperiment ]]; then
        suggested="experiment/${suggested#experiment-}"
    elif [[ ! "$suggested" =~ / ]]; then
        # No type detected, default to feature
        suggested="feature/${suggested}"
    fi

    echo "$suggested"
}

# ============================================
# Output Functions
# ============================================

output_validation_result() {
    local branch="$1"
    local result="$2"
    local matched_type="$3"
    local suggested="$4"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat << EOF
{
  "branch": "$branch",
  "valid": $( [[ "$result" == "valid" ]] && echo "true" || echo "false" ),
  "type": "$matched_type",
  "suggested_name": "${suggested:-null}"
}
EOF
    else
        if [[ "$result" == "valid" ]]; then
            echo -e "${GREEN}✓ VALID${NC}: $branch (type: $matched_type)"
        else
            echo -e "${RED}✗ INVALID${NC}: $branch"
            if [[ -n "$suggested" ]]; then
                echo -e "  ${YELLOW}Suggested:${NC} $suggested"
            fi
        fi
    fi
}

output_check_all_results() {
    local valid_count="$1"
    local invalid_count="$2"
    local invalid_list="$3"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat << EOF
{
  "total_checked": $((valid_count + invalid_count)),
  "valid_count": $valid_count,
  "invalid_count": $invalid_count,
  "invalid_branches": [
$(echo "$invalid_list" | while IFS='|' read -r branch suggested; do
    [[ -z "$branch" ]] && continue
    cat << BRANCH
    {
      "name": "$branch",
      "suggested": "$suggested"
    },
BRANCH
done | sed '$ s/,$//')
  ]
}
EOF
    else
        echo ""
        echo "=========================================="
        echo "Branch Validation Report"
        echo "=========================================="
        echo "Total branches checked: $((valid_count + invalid_count))"
        echo -e "${GREEN}Valid: $valid_count${NC}"
        echo -e "${RED}Invalid: $invalid_count${NC}"
        echo ""

        if [[ $invalid_count -gt 0 ]]; then
            echo "Invalid Branches:"
            echo "----------------"
            echo "$invalid_list" | while IFS='|' read -r branch suggested; do
                [[ -z "$branch" ]] && continue
                echo -e "${RED}✗${NC} $branch"
                echo -e "  ${YELLOW}Suggested:${NC} $suggested"
                echo ""
            done
        fi
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"
    load_config

    # Change to project root
    cd "$PROJECT_ROOT" || error "Failed to change to project root: $PROJECT_ROOT"

    # Validate git repository if needed
    if [[ "$MODE" == "check-all" ]]; then
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            error "Not a git repository: $PROJECT_ROOT"
        fi
    fi

    case "$MODE" in
        validate)
            if [[ -z "$BRANCH_NAME" ]]; then
                error "Branch name required for validation mode"
            fi

            log "Validating branch: $BRANCH_NAME"

            # Skip protected branches
            if is_protected "$BRANCH_NAME"; then
                log "Branch is protected, skipping validation"
                exit 0
            fi

            # Check rejected patterns
            if is_rejected "$BRANCH_NAME"; then
                log "Branch matches rejected pattern"
                output_validation_result "$BRANCH_NAME" "invalid" "rejected" ""
                log_enforcement_to_db "$BRANCH_NAME" "rejected" "pattern"
                exit 1
            fi

            # Validate against patterns
            local validation_result
            validation_result=$(validate_branch_name "$BRANCH_NAME")
            IFS='|' read -r result matched_type pattern <<< "$validation_result"

            if [[ "$result" == "valid" ]]; then
                log "Branch validation passed"
                output_validation_result "$BRANCH_NAME" "valid" "$matched_type" ""
                log_enforcement_to_db "$BRANCH_NAME" "valid" "$matched_type"
                exit 0
            else
                local suggested
                suggested=$(suggest_fix "$BRANCH_NAME")

                log "Branch validation failed"
                output_validation_result "$BRANCH_NAME" "invalid" "none" "$suggested"
                log_enforcement_to_db "$BRANCH_NAME" "invalid" "none" "$suggested"
                exit 1
            fi
            ;;

        check-all)
            log "Checking all local branches..."

            # Get all branches
            local branches
            branches=$(git branch | sed 's/^[* ] //')

            if [[ -z "$branches" ]]; then
                log "No branches found"
                exit 2
            fi

            local valid_count=0
            local invalid_count=0
            local invalid_list=""

            while IFS= read -r branch; do
                [[ -z "$branch" ]] && continue

                # Skip protected branches
                if is_protected "$branch"; then
                    [[ $VERBOSE -eq 1 ]] && log "  Skipping protected: $branch"
                    continue
                fi

                # Check rejected patterns
                if is_rejected "$branch"; then
                    ((invalid_count++))
                    local suggested
                    suggested=$(suggest_fix "$branch")
                    invalid_list+="${branch}|${suggested}\n"
                    log "  ✗ REJECTED: $branch"
                    log_enforcement_to_db "$branch" "rejected" "pattern" "$suggested"
                    continue
                fi

                # Validate against patterns
                local validation_result
                validation_result=$(validate_branch_name "$branch")
                IFS='|' read -r result matched_type pattern <<< "$validation_result"

                if [[ "$result" == "valid" ]]; then
                    ((valid_count++))
                    [[ $VERBOSE -eq 1 ]] && log "  ✓ VALID: $branch ($matched_type)"
                    log_enforcement_to_db "$branch" "valid" "$matched_type"
                else
                    ((invalid_count++))
                    local suggested
                    suggested=$(suggest_fix "$branch")
                    invalid_list+="${branch}|${suggested}\n"
                    log "  ✗ INVALID: $branch -> suggested: $suggested"
                    log_enforcement_to_db "$branch" "invalid" "none" "$suggested"
                fi
            done <<< "$branches"

            # Output results
            output_check_all_results "$valid_count" "$invalid_count" "$invalid_list"

            log "Check complete! Valid: $valid_count, Invalid: $invalid_count"

            if [[ $invalid_count -gt 0 ]]; then
                exit 1
            else
                exit 0
            fi
            ;;

        fix-name)
            if [[ -z "$BRANCH_NAME" ]]; then
                error "Branch name required for fix-name mode"
            fi

            log "Analyzing branch name: $BRANCH_NAME"

            local suggested
            suggested=$(suggest_fix "$BRANCH_NAME")

            if [[ "$OUTPUT_FORMAT" == "json" ]]; then
                cat << EOF
{
  "original": "$BRANCH_NAME",
  "suggested": "$suggested"
}
EOF
            else
                echo "Original: $BRANCH_NAME"
                echo "Suggested: $suggested"
                echo ""
                echo "To rename your branch:"
                echo "  git branch -m $BRANCH_NAME $suggested"
            fi

            exit 0
            ;;

        *)
            error "Invalid mode: $MODE"
            ;;
    esac
}

# Run main function
main "$@"
