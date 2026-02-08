#!/bin/bash
################################################################################
# Detect Changes Script
# Part of Phase 6: Dynamic Test Selection
#
# Analyzes git changes between commits to determine affected modules
# and calculate change impact score
#
# Usage:
#   ./detect-changes.sh [commit_range] [options]
#
# Examples:
#   ./detect-changes.sh HEAD~5..HEAD
#   ./detect-changes.sh main..feature-branch
#   ./detect-changes.sh $CI_COMMIT_PREV $CI_COMMIT
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
MODULES_CONFIG="$CONFIG_DIR/test-modules.yaml"

# Default values
COMMIT_RANGE=""
OUTPUT_FORMAT="text"  # text, json, bash
VERBOSE=0
PROJECT_ROOT="${PROJECT_ROOT:-.}"
IMPACT_THRESHOLD=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat << EOF
Usage: $0 [commit_range] [options]

Arguments:
  commit_range         Git commit range (e.g., HEAD~5..HEAD, main..feature)
                       Can also be specified as two separate commit SHAs

Options:
  -f, --format FORMAT  Output format: text, json, bash (default: text)
  -p, --project PATH   Project root directory (default: .)
  -t, --threshold N    Minimum impact score to report (default: 10)
  -v, --verbose        Enable verbose output
  -h, --help           Show this help message

Output Formats:
  text   Human-readable output with color
  json   JSON format for programmatic consumption
  bash   Bash variables for sourcing in scripts

Examples:
  # Detect changes between last 5 commits
  $0 HEAD~5..HEAD

  # Compare two branches with JSON output
  $0 -f json main..feature-branch

  # Use in pipeline with environment variables
  eval \$(./detect-changes.sh $CI_COMMIT_PREV $CI_COMMIT -f bash)

  # Verbose mode with custom project root
  $0 -v -p /path/to/project HEAD~1..HEAD

Exit Codes:
  0      Success
  1      Error occurred
  2      No changes detected
  3      Invalid arguments

EOF
    exit 0
}

################################################################################
# Parse Arguments
################################################################################

parse_args() {
    if [[ $# -eq 0 ]]; then
        log_error "No commit range specified"
        usage
        exit 3
    fi

    # Parse positional arguments first
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            -t|--threshold)
                IMPACT_THRESHOLD="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 3
                ;;
            *)
                if [[ -z "$COMMIT_RANGE" ]]; then
                    # Check if this is already a range or a single commit
                    if [[ "$1" == *".."* ]]; then
                        COMMIT_RANGE="$1"
                    elif [[ $# -ge 2 && ! "$2" =~ ^- ]]; then
                        # Two commits provided
                        COMMIT_RANGE="$1..$2"
                        shift
                    else
                        # Single commit, compare to parent
                        COMMIT_RANGE="$1^..$1"
                    fi
                else
                    log_error "Too many arguments"
                    usage
                    exit 3
                fi
                shift
                ;;
        esac
    done

    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|bash)$ ]]; then
        log_error "Invalid output format: $OUTPUT_FORMAT"
        exit 3
    fi

    # Validate project root
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "Project root not found: $PROJECT_ROOT"
        exit 1
    fi

    cd "$PROJECT_ROOT"

    # Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository: $PROJECT_ROOT"
        exit 1
    fi
}

################################################################################
# Git Operations
################################################################################

get_changed_files() {
    local range="$1"

    # Get list of changed files (excluding deleted files)
    git diff --name-only --diff-filter=d "$range" 2>/dev/null || {
        log_error "Failed to get changed files for range: $range"
        return 1
    }
}

get_file_diff_stats() {
    local range="$1"
    local file="$2"

    git diff --numstat "$range" -- "$file" 2>/dev/null | awk '{print $1, $2}'
}

categorize_file_by_module() {
    local file="$1"

    # Remove leading ./
    file="${file#./}"

    # Extract module from path
    # Standard Android structure: module/src/main/...
    if [[ "$file" =~ ^([^/]+)/ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "root"
    fi
}

calculate_file_impact() {
    local additions="$1"
    local deletions="$2"
    local file="$3"

    # Base impact: lines changed
    local impact=$((additions + deletions))

    # Multipliers for different file types
    case "$file" in
        *.kt|*.java)
            # Source code changes are high impact
            impact=$((impact * 3))
            ;;
        build.gradle*|*.kts|pom.xml|settings.gradle*)
            # Build file changes affect everything
            impact=$((impact * 5))
            ;;
        *.xml)
            # Resource/layout changes
            impact=$((impact * 2))
            ;;
        *.proto|*.json)
            # Data structure changes
            impact=$((impact * 4))
            ;;
        *)
            # Other files
            impact=$((impact * 1))
            ;;
    esac

    echo "$impact"
}

################################################################################
# Module Detection
################################################################################

detect_affected_modules() {
    local changed_files="$1"
    local -A module_impact
    local -A module_file_counts
    local total_impact=0

    if [[ -z "$changed_files" ]]; then
        log_warning "No changed files detected"
        return 2
    fi

    # Process each changed file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        # Get diff stats
        read -r additions deletions <<< "$(get_file_diff_stats "$COMMIT_RANGE" "$file")"

        # Categorize by module
        local module
        module=$(categorize_file_by_module "$file")

        # Calculate impact
        local impact
        impact=$(calculate_file_impact "${additions:-0}" "${deletions:-0}" "$file")

        # Accumulate by module
        if [[ -n "${module_impact[$module]:-}" ]]; then
            module_impact[$module]=$((module_impact[$module] + impact))
            module_file_counts[$module]=$((module_file_counts[$module] + 1))
        else
            module_impact[$module]=$impact
            module_file_counts[$module]=1
        fi

        total_impact=$((total_impact + impact))

        [[ $VERBOSE -eq 1 ]] && log_info "  $file: +${additions:-0} -${deletions:-0} -> $module (impact: $impact)"

    done <<< "$changed_files"

    # Output results
    case "$OUTPUT_FORMAT" in
        text)
            output_text "${module_impact[@]}" "${module_file_counts[@]}" "$total_impact"
            ;;
        json)
            output_json "${module_impact[@]}" "${module_file_counts[@]}" "$total_impact"
            ;;
        bash)
            output_bash "${module_impact[@]}" "${module_file_counts[@]}" "$total_impact"
            ;;
    esac
}

################################################################################
# Output Functions
################################################################################

output_text() {
    local -a sorted_modules=($(printf '%s\n' "${!module_impact[@]}" | sort))

    echo ""
    echo "=========================================="
    echo "Change Detection Report"
    echo "=========================================="
    echo "Commit Range: $COMMIT_RANGE"
    echo "Total Impact Score: $3"
    echo ""

    for module in "${sorted_modules[@]}"; do
        local impact="${module_impact[$module]}"
        local files="${module_file_counts[$module]}"

        if [[ $impact -ge $IMPACT_THRESHOLD ]]; then
            echo -e "${GREEN}✓${NC} $module: $impact impact ($files file(s))"
        else
            echo -e "${YELLOW}○${NC} $module: $impact impact ($files file(s))"
        fi
    done

    echo ""
    echo "Affected Modules (impact >= $IMPACT_THRESHOLD):"

    local affected_count=0
    for module in "${sorted_modules[@]}"; do
        if [[ ${module_impact[$module]} -ge $IMPACT_THRESHOLD ]]; then
            echo "  - $module"
            affected_count=$((affected_count + 1))
        fi
    done

    if [[ $affected_count -eq 0 ]]; then
        echo "  (none)"
    fi

    echo ""
}

output_json() {
    cat << EOF
{
  "commit_range": "$COMMIT_RANGE",
  "total_impact": $3,
  "impact_threshold": $IMPACT_THRESHOLD,
  "modules": [
$(

    local -a sorted_modules=($(printf '%s\n' "${!module_impact[@]}" | sort))
    local first=1

    for module in "${sorted_modules[@]}"; do
        if [[ $first -eq 0 ]]; then
            echo ","
        fi
        first=0

        local impact="${module_impact[$module]}"
        local files="${module_file_counts[$module]}"
        local affected="false"

        [[ $impact -ge $IMPACT_THRESHOLD ]] && affected="true"

        cat << MODULE
    {
      "name": "$module",
      "impact": $impact,
      "file_count": $files,
      "affected": $affected
    }
MODULE
    done

)
  ],
  "affected_modules": [
$(

    local -a sorted_modules=($(printf '%s\n' "${!module_impact[@]}" | sort))
    local first=1

    for module in "${sorted_modules[@]}"; do
        if [[ ${module_impact[$module]} -ge $IMPACT_THRESHOLD ]]; then
            if [[ $first -eq 0 ]]; then
                echo ","
            fi
            first=0
            echo "    \"$module\""
        fi
    done

)
  ]
}
EOF
}

output_bash() {
    local -a sorted_modules=($(printf '%s\n' "${!module_impact[@]}" | sort))
    local affected_modules=""

    for module in "${sorted_modules[@]}"; do
        if [[ ${module_impact[$module]} -ge $IMPACT_THRESHOLD ]]; then
            [[ -n "$affected_modules" ]] && affected_modules+=" "
            affected_modules+="$module"
        fi
    done

    echo "# Change detection results for: $COMMIT_RANGE"
    echo "export COMMIT_RANGE=\"$COMMIT_RANGE\""
    echo "export TOTAL_IMPACT=$3"
    echo "export AFFECTED_MODULES=\"$affected_modules\""
    echo "export MODULE_COUNT=${#sorted_modules[@]}"
    echo "export AFFECTED_COUNT=$(echo "$affected_modules" | wc -w)"

    # Export individual module impacts
    for module in "${sorted_modules[@]}"; do
        local sanitized_name="${module//[^a-zA-Z0-9_]/_}"
        echo "export MODULE_IMPACT_${sanitized_name}=${module_impact[$module]}"
    done
}

################################################################################
# Store Results in Database
################################################################################

store_results() {
    local -a sorted_modules=($(printf '%s\n' "${!module_impact[@]}" | sort))
    local commit_shas=($(echo "$COMMIT_RANGE" | tr '.' ' '))

    # Check if database connection is available
    if ! command -v psql &> /dev/null; then
        [[ $VERBOSE -eq 1 ]] && log_warning "psql not found, skipping database storage"
        return 0
    fi

    # Store module-level impact data
    for module in "${sorted_modules[@]}"; do
        local impact="${module_impact[$module]}"
        local files="${module_file_counts[$module]}"

        # This would insert into a test_selection_metrics table
        # For now, just log it
        [[ $VERBOSE -eq 1 ]] && log_info "Would store to DB: $module=$impact impact"
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    parse_args "$@"

    log_info "Detecting changes in range: $COMMIT_RANGE"
    log_info "Project root: $PROJECT_ROOT"

    # Get changed files
    local changed_files
    changed_files=$(get_changed_files "$COMMIT_RANGE")

    # Detect affected modules
    detect_affected_modules "$changed_files"
    local exit_code=$?

    # Store results if database available
    store_results

    return $exit_code
}

# Run main function
main "$@"
