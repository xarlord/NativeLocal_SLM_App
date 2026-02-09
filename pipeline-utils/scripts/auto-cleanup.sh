#!/bin/bash
set -euo pipefail

# Automated Cleanup Orchestration Script
# Runs all cleanup tasks: branches, stale issues, old artifacts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "${MAGENTA}[CLEANUP]${NC} $*"; }

# Configuration
CLEAN_BRANCHES="${CLEAN_BRANCHES:-true}"
CLEAN_ISSUES="${CLEAN_ISSUES:-true}"
CLEAN_ARTIFACTS="${CLEAN_ARTIFACTS:-true}"
DRY_RUN="${DRY_RUN:-false}"

# Clean branches
cleanup_branches() {
    if [ "$CLEAN_BRANCHES" != "true" ]; then
        return
    fi

    log_section "Branch Cleanup"
    echo ""

    if [ -f "${SCRIPT_DIR}/cleanup-branches.sh" ]; then
        "${SCRIPT_DIR}/cleanup-branches.sh" ${DRY_RUN:+--dry-run}
    else
        log_warning "cleanup-branches.sh not found"
    fi
    echo ""
}

# Clean stale issues
cleanup_issues() {
    if [ "$CLEAN_ISSUES" != "true" ]; then
        return
    fi

    log_section "Stale Issue Cleanup"
    echo ""

    # Close stale issues (inactive for 90+ days)
    log_info "Finding stale issues..."

    gh issue list \
        --state open \
        --search "updated:<$(date -d '90 days ago' +%Y-%m-%d)" \
        --json number,title \
        --jq '.[] | "#\(.number) \(.title)"' \
        2>/dev/null | while read -r issue; do
            if [ -n "$issue" ]; then
                log_info "Found stale: $issue"

                if [ "$DRY_RUN" != "true" ]; then
                    issue_number=$(echo "$issue" | grep -oE '#[0-9]+' | grep -oE '[0-9]+')
                    gh issue close "$issue_number" --comment "Closing due to inactivity." 2>/dev/null || true
                fi
            fi
        done

    log_success "Stale issues processed"
    echo ""
}

# Clean old artifacts
cleanup_artifacts() {
    if [ "$CLEAN_ARTIFACTS" != "true" ]; then
        return
    fi

    log_section "Artifact Cleanup"
    echo ""

    # Clean old Jenkins artifacts (>30 days)
    log_info "Finding old artifacts..."

    if [ -d "build" ]; then
        find build -name "*.apk" -mtime +30 -type f 2>/dev/null | while read -r artifact; do
            log_info "Old artifact: $artifact"

            if [ "$DRY_RUN" != "true" ]; then
                rm -f "$artifact"
                log_success "Deleted: $artifact"
            else
                log_info "[DRY RUN] Would delete: $artifact"
            fi
        done
    fi

    log_success "Artifacts cleaned"
    echo ""
}

# Clean Docker resources
cleanup_docker() {
    log_section "Docker Cleanup"
    echo ""

    log_info "Removing dangling images..."
    if [ "$DRY_RUN" != "true" ]; then
        docker image prune -f > /dev/null 2>&1 || log_warning "Docker prune failed"
    else
        log_info "[DRY RUN] Would prune dangling images"
    fi

    log_success "Docker cleanup complete"
    echo ""
}

# Generate cleanup report
generate_report() {
    log_section "Cleanup Report"
    echo ""

    # Count branches
    branch_count=$(git branch 2>/dev/null | wc -l)
    log_info "Total branches: $branch_count"

    # Count open issues
    issue_count=$(gh issue list --state open 2>/dev/null | wc -l || echo "0")
    log_info "Open issues: $issue_count"

    # Disk usage
    disk_usage=$(du -sh . 2>/dev/null | cut -f1)
    log_info "Repository size: $disk_usage"

    echo ""
    log_success "Report generated"
}

# Main function
main() {
    log_info "=== Automated Cleanup Orchestration ==="
    echo ""

    # Check for gh
    if ! command -v gh > /dev/null 2>&1; then
        log_error "gh CLI not installed"
        exit 1
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                export DRY_RUN
                shift
                ;;
            --no-branches)
                CLEAN_BRANCHES=false
                shift
                ;;
            --no-issues)
                CLEAN_ISSUES=false
                shift
                ;;
            --no-artifacts)
                CLEAN_ARTIFACTS=false
                shift
                ;;
            --help)
                echo "Usage: $0 [--dry-run] [--no-branches] [--no-issues] [--no-artifacts]"
                exit 0
                ;;
        esac
    done

    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Run cleanup tasks
    cleanup_branches
    cleanup_issues
    cleanup_artifacts
    cleanup_docker
    generate_report

    log_success "=== Cleanup Complete ==="
}

# Execute
main "$@"
