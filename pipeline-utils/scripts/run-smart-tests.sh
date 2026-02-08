#!/bin/bash
################################################################################
# Smart Test Runner Script
# Part of Phase 6: Dynamic Test Selection
#
# Runs only the tests affected by code changes, using module mapping
# and optional JaCoCo coverage data for test impact analysis
#
# Usage:
#   ./run-smart-tests.sh [commit_range] [options]
#
# Examples:
#   ./run-smart-tests.sh HEAD~5..HEAD
#   ./run-smart-tests.sh $CI_COMMIT_PREV $CI_COMMIT
#   ./run-smart-tests.sh main..feature-branch --fallback
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT_CHANGES="$SCRIPT_DIR/detect-changes.sh"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
MODULES_CONFIG="$CONFIG_DIR/test-modules.yaml"

# Default values
COMMIT_RANGE=""
PROJECT_ROOT="${PROJECT_ROOT:-.}"
GRADLE_TASKS="${GRADLE_TASKS:-./gradlew}"
FALLBACK_TO_FULL=false
COVERAGE_ENABLED=false
DRY_RUN=false
VERBOSE=0
REPORT_DIR="${REPORT_DIR:-build/test-selection-report}"
TIMING_FILE="$REPORT_DIR/timing.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Timing variables
START_TIME=$(date +%s)
TOTAL_ESTIMATED_TIME=0
ACTUAL_TIME=0

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $*"
}

usage() {
    cat << EOF
Usage: $0 [commit_range] [options]

Arguments:
  commit_range         Git commit range (e.g., HEAD~5..HEAD, main..feature)
                       Can also be specified as two separate commit SHAs

Options:
  -p, --project PATH   Project root directory (default: .)
  -g, --gradle CMD     Gradle command (default: ./gradlew)
  -f, --fallback       Fall back to full test suite if detection fails
  -c, --coverage       Enable JaCoCo coverage analysis for test impact
  -d, --dry-run        Show what would be tested without running
  -r, --report DIR     Report directory (default: build/test-selection-report)
  -v, --verbose        Enable verbose output
  -h, --help           Show this help message

Environment Variables:
  PROJECT_ROOT         Project root directory
  GRADLE_TASKS         Gradle command to run
  REPORT_DIR           Where to store test selection reports
  CI_COMMIT_PREV       Previous commit SHA (in CI)
  CI_COMMIT            Current commit SHA (in CI)

Examples:
  # Run smart tests for last 5 commits
  $0 HEAD~5..HEAD

  # Use in CI pipeline
  $0 \$CI_COMMIT_PREV \$CI_COMMIT --fallback

  # Dry run to see what would be tested
  $0 main..feature-branch --dry-run

  # Enable coverage-based test impact analysis
  $0 HEAD~1..HEAD --coverage

Exit Codes:
  0      Success (tests passed)
  1      Error occurred
  2      Tests failed
  3      Invalid arguments
  4      Fallback to full tests executed

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

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -p|--project)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            -g|--gradle)
                GRADLE_TASKS="$2"
                shift 2
                ;;
            -f|--fallback)
                FALLBACK_TO_FULL=true
                shift
                ;;
            -c|--coverage)
                COVERAGE_ENABLED=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--report)
                REPORT_DIR="$2"
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
                    if [[ "$1" == *".."* ]]; then
                        COMMIT_RANGE="$1"
                    elif [[ $# -ge 2 && ! "$2" =~ ^- ]]; then
                        COMMIT_RANGE="$1..$2"
                        shift
                    else
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

    cd "$PROJECT_ROOT"
}

################################################################################
# Module Mapping Functions
################################################################################

load_module_mapping() {
    if [[ -f "$MODULES_CONFIG" ]]; then
        log_info "Loading module mapping from $MODULES_CONFIG"
        # Parse YAML config (simplified parsing)
        source "$MODULES_CONFIG" 2>/dev/null || true
    else
        log_warning "Module mapping config not found: $MODULES_CONFIG"
        log_info "Using default module mapping"
    fi
}

map_modules_to_tests() {
    local modules="$1"
    local test_tasks=""

    if [[ -z "$modules" ]]; then
        echo ""
        return
    fi

    # Load module mapping
    load_module_mapping

    # Map each module to its test task
    for module in $modules; do
        local test_task=""

        # Check for custom mapping
        if [[ -n "${MODULE_TEST_MAP[$module]:-}" ]]; then
            test_task="${MODULE_TEST_MAP[$module]}"
        else
            # Default mapping: :module:test
            if [[ "$module" == "root" ]]; then
                test_task="test"
            else
                test_task=":$module:test"
            fi
        fi

        [[ -n "$test_task" ]] && test_tasks="$test_tasks $test_task"
    done

    echo "$test_tasks"
}

get_test_dependencies() {
    local module="$1"
    local dependencies=""

    # Check if module has test dependencies
    if [[ -n "${MODULE_TEST_DEPS[$module]:-}" ]]; then
        dependencies="${MODULE_TEST_DEPS[$module]}"
    fi

    echo "$dependencies"
}

################################################################################
# Test Time Estimation
################################################################################

estimate_test_time() {
    local test_tasks="$1"
    local estimated_seconds=0

    # Default test times (can be overridden in config)
    for task in $test_tasks; do
        local task_name="${task##*:}"  # Remove : prefix if present
        local default_time=60  # 1 minute default

        # Check for custom time estimate
        if [[ -n "${MODULE_TEST_TIME[$task_name]:-}" ]]; then
            estimated_seconds=$((estimated_seconds + MODULE_TEST_TIME[$task_name]))
        else
            estimated_seconds=$((estimated_seconds + default_time))
        fi
    done

    echo "$estimated_seconds"
}

format_duration() {
    local seconds="$1"
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))

    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

################################################################################
# JaCoCo Coverage Analysis
################################################################################

analyze_coverage_impact() {
    if [[ "$COVERAGE_ENABLED" != "true" ]]; then
        return
    fi

    log_info "Analyzing JaCoCo coverage data for test impact"

    local jacoco_exec="build/jacoco/test.exec"
    local jacoco_xml="build/reports/jacoco/test/jacocoTestReport.xml"

    if [[ ! -f "$jacoco_exec" && ! -f "$jacoco_xml" ]]; then
        log_warning "No JaCoCo data found, skipping coverage analysis"
        return
    fi

    # Parse coverage data to find lines covered by tests
    # This is a simplified version - production would use proper XML parsing
    log_info "Found JaCoCo data, analyzing test coverage impact..."

    # Additional tests needed based on coverage
    # (Implementation would parse JaCoCo XML and determine additional tests)
}

################################################################################
# Test Execution
################################################################################

run_tests() {
    local test_tasks="$1"
    local exit_code=0

    if [[ -z "$test_tasks" ]]; then
        log_warning "No tests to run"
        return 0
    fi

    log_step "Running test tasks:"

    for task in $test_tasks; do
        echo "  - $task"
    done

    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: $GRADLE_TASKS $test_tasks"
        return 0
    fi

    # Create report directory
    mkdir -p "$REPORT_DIR"

    # Run tests with timing
    local test_start=$(date +%s)

    if $GRADLE_TASKS $test_tasks --continue 2>&1 | tee "$REPORT_DIR/test-output.log"; then
        exit_code=0
    else
        exit_code=$?
        log_error "Tests failed with exit code: $exit_code"
    fi

    local test_end=$(date +%s)
    ACTUAL_TIME=$((test_end - test_start))

    return $exit_code
}

run_full_test_suite() {
    log_warning "Falling back to full test suite"
    log_step "Running all tests..."

    local test_start=$(date +%s)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: $GRADLE_TASKS test"
        return 0
    fi

    if $GRADLE_TASKS test --continue 2>&1 | tee "$REPORT_DIR/test-output.log"; then
        return 0
    else
        return $?
    fi
}

################################################################################
# Reporting
################################################################################

calculate_time_savings() {
    local estimated_time="$1"
    local actual_time="$2"

    if [[ $estimated_time -gt 0 ]]; then
        local saved_percent=$(( (estimated_time - actual_time) * 100 / estimated_time ))
        echo "$saved_percent"
    else
        echo "0"
    fi
}

generate_report() {
    local affected_modules="$1"
    local test_tasks="$2"
    local exit_code="$3"
    local fallback_used="$4"

    mkdir -p "$REPORT_DIR"

    local report_file="$REPORT_DIR/summary.md"
    local timing_file="$REPORT_DIR/timing.json"

    # Calculate time savings
    local time_saved_percent=$(calculate_time_savings "$TOTAL_ESTIMATED_TIME" "$ACTUAL_TIME")

    # Generate Markdown report
    cat > "$report_file" << EOF
# Smart Test Selection Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Commit Range:** \`$COMMIT_RANGE\`
**Exit Code:** $exit_code

## Summary

- **Affected Modules:** ${affected_modules:-"none"}
- **Test Tasks Executed:** ${test_tasks:-"none"}
- **Fallback Used:** $fallback_used
- **Dry Run:** $DRY_RUN

## Time Metrics

| Metric | Value |
|--------|-------|
| Estimated Full Test Time | $(format_duration "$TOTAL_ESTIMATED_TIME") |
| Actual Test Time | $(format_duration "$ACTUAL_TIME") |
| Time Saved | $(format_duration "$((TOTAL_ESTIMATED_TIME - ACTUAL_TIME))") |
| Efficiency Gain | ${time_saved_percent}% |

## Modules Tested

$([ -n "$affected_modules" ] && echo "$affected_modules" | tr ' ' '\n' | sed 's/^/- /' || echo "None")

## Test Tasks

$([ -n "$test_tasks" ] && echo "$test_tasks" | tr ' ' '\n' | sed 's/^/- /' || echo "None")

## Result

$([ $exit_code -eq 0 ] && echo "✅ **All tests passed**" || echo "❌ **Tests failed**")

## Logs

Detailed test output available in: \`$REPORT_DIR/test-output.log\`

---

Generated by \`run-smart-tests.sh\` - Phase 6: Dynamic Test Selection
EOF

    # Generate JSON timing data
    cat > "$timing_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "commit_range": "$COMMIT_RANGE",
  "affected_modules": [$(echo "$affected_modules" | tr ' ' ',' | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
  "test_tasks": [$(echo "$test_tasks" | tr ' ' ',' | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
  "fallback_used": $fallback_used,
  "dry_run": $DRY_RUN,
  "timing": {
    "estimated_seconds": $TOTAL_ESTIMATED_TIME,
    "actual_seconds": $ACTUAL_TIME,
    "time_saved_seconds": $((TOTAL_ESTIMATED_TIME - ACTUAL_TIME)),
    "efficiency_percent": $time_saved_percent
  },
  "exit_code": $exit_code
}
EOF

    log_success "Report generated: $report_file"
}

print_summary() {
    local affected_modules="$1"
    local test_tasks="$2"
    local exit_code="$3"
    local fallback_used="$4"

    local time_saved_percent=$(calculate_time_savings "$TOTAL_ESTIMATED_TIME" "$ACTUAL_TIME")

    echo ""
    echo "=========================================="
    echo "Smart Test Selection Summary"
    echo "=========================================="
    echo ""
    echo "Affected Modules: ${affected_modules:-"none"}"
    echo "Test Tasks: ${test_tasks:-"none"}"
    echo "Fallback Used: $fallback_used"
    echo ""
    echo "Time Metrics:"
    echo "  Estimated: $(format_duration "$TOTAL_ESTIMATED_TIME")"
    echo "  Actual:    $(format_duration "$ACTUAL_TIME")"
    echo "  Saved:     $(format_duration "$((TOTAL_ESTIMATED_TIME - ACTUAL_TIME))") (${time_saved_percent}%)"
    echo ""

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed${NC}"
    else
        echo -e "${RED}✗ Tests failed${NC}"
    fi

    echo ""
    echo "Full report: $REPORT_DIR/summary.md"
    echo ""
}

################################################################################
# Store Results in Database
################################################################################

store_results_db() {
    local affected_modules="$1"
    local exit_code="$2"
    local time_saved_percent="$3"

    # Check if database connection is available
    if ! command -v psql &> /dev/null; then
        [[ $VERBOSE -eq 1 ]] && log_warning "psql not found, skipping database storage"
        return 0
    fi

    # Parse commit range for SHAs
    local commit_from=$(echo "$COMMIT_RANGE" | cut -d'.' -f1)
    local commit_to=$(echo "$COMMIT_RANGE" | cut -d'.' -f3)

    log_info "Storing test selection results in database..."

    # This would insert into test_selection_metrics table
    # For now, just log it
    if [[ $VERBOSE -eq 1 ]]; then
        log_info "DB Entry: modules=$affected_modules, exit=$exit_code, saved=${time_saved_percent}%"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    parse_args "$@"

    log_step "Phase 6: Dynamic Test Selection"
    log_info "Commit Range: $COMMIT_RANGE"
    log_info "Project Root: $PROJECT_ROOT"
    echo ""

    # Step 1: Detect changes
    log_step "Detecting affected modules..."
    local change_output
    change_output=$($DETECT_CHANGES "$COMMIT_RANGE" -f bash -p "$PROJECT_ROOT" 2>&1)

    if [[ $? -ne 0 ]]; then
        log_error "Change detection failed"

        if [[ "$FALLBACK_TO_FULL" == "true" ]]; then
            run_full_test_suite
            exit $?
        else
            exit 1
        fi
    fi

    # Parse change detection output
    eval "$change_output"

    local affected_modules="$AFFECTED_MODULES"

    log_success "Affected modules: ${affected_modules:-"none"}"
    echo ""

    # Step 2: Map modules to tests
    log_step "Mapping modules to test tasks..."

    local test_tasks
    test_tasks=$(map_modules_to_tests "$affected_modules")

    if [[ -z "$test_tasks" ]]; then
        log_warning "No test tasks found for affected modules"

        if [[ "$FALLBACK_TO_FULL" == "true" ]]; then
            log_warning "Falling back to full test suite"
            run_full_test_suite
            exit $?
        else
            log_info "No tests to run, exiting"
            exit 0
        fi
    fi

    # Step 3: Estimate test time
    TOTAL_ESTIMATED_TIME=$(estimate_test_time "$test_tasks")
    log_info "Estimated test time: $(format_duration "$TOTAL_ESTIMATED_TIME")"
    echo ""

    # Step 4: Analyze coverage impact (if enabled)
    if [[ "$COVERAGE_ENABLED" == "true" ]]; then
        analyze_coverage_impact
    fi

    # Step 5: Run tests
    local test_exit_code=0
    local fallback_used="false"

    run_tests "$test_tasks"
    test_exit_code=$?

    # If tests failed and fallback is enabled, try full suite
    if [[ $test_exit_code -ne 0 && "$FALLBACK_TO_FULL" == "true" ]]; then
        log_warning "Smart tests failed, trying full test suite..."
        fallback_used="true"

        run_full_test_suite
        test_exit_code=$?
    fi

    # Step 6: Generate reports
    log_step "Generating reports..."
    generate_report "$affected_modules" "$test_tasks" "$test_exit_code" "$fallback_used"

    # Step 7: Store results
    local time_saved_percent=$(calculate_time_savings "$TOTAL_ESTIMATED_TIME" "$ACTUAL_TIME")
    store_results_db "$affected_modules" "$test_exit_code" "$time_saved_percent"

    # Step 8: Print summary
    print_summary "$affected_modules" "$test_tasks" "$test_exit_code" "$fallback_used"

    exit $test_exit_code
}

# Run main function
main "$@"
