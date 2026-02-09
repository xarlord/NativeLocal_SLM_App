#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
STALE_DAYS="${STALE_DAYS:-30}"
DRY_RUN="${DRY_RUN:-false}"
PROTECTED_BRANCHES="${PROTECTED_BRANCHES:-main|master|develop|dev}"

# Check if branch is protected
is_protected() {
    local branch="$1"
    if echo "$branch" | grep -E "^($PROTECTED_BRANCHES)$" > /dev/null; then
        return 0
    fi
    return 1
}

# Get stale branches
get_stale_branches() {
    local days="$1"

    log_info "Finding branches older than $days days..."

    git for-each-ref --sort=-committerdate refs/heads/ \
        --format='%(refname:short)|%(committerdate:iso8601)|%(authorname)' \
        | while IFS='|' read -r branch date author; do
        # Skip protected branches
        if is_protected "$branch"; then
            log_info "Skipping protected branch: $branch"
            continue
        fi

        # Check if branch is stale
        branch_date=$(date -d "$date" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$date" +%s 2>/dev/null || echo "0")
        current_date=$(date +%s)
        days_old=$(( (current_date - branch_date) / 86400 ))

        if [ "$days_old" -ge "$days" ]; then
            echo "$branch|$days_old days|$author"
        fi
    done
}

# Get merged branches
get_merged_branches() {
    log_info "Finding merged branches..."

    git for-each-ref --sort=-committerdate refs/heads/ \
        --format='%(refname:short)' \
        | while read -r branch; do
        # Skip protected branches
        if is_protected "$branch"; then
            continue
        fi

        # Check if merged
        if git branch --merged "$branch" 2>/dev/null | grep -qE "^  ($PROTECTED_BRANCHES)$"; then
            echo "$branch"
        fi
    done
}

# Delete branch
delete_branch() {
    local branch="$1"
    local reason="$2"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would delete $branch: $reason"
        return 0
    fi

    log_info "Deleting $branch: $reason"
    git branch -D "$branch" && log_success "Deleted $branch" || log_warning "Failed to delete $branch"
}

# Warn about stale branches
warn_stale_branches() {
    local branches="$1"
    local repo_owner="${GITHUB_REPOSITORY_OWNER:-}"
    local repo_name="${GITHUB_REPOSITORY##*/}"

    if [ -z "$repo_owner" ] || [ -z "$repo_name" ]; then
        log_warning "GitHub repository not configured, skipping warnings"
        return 0
    fi

    log_info "Commenting on stale PRs..."
    echo "$branches" | while IFS='|' read -r branch age author; do
        # Find associated PR
        pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || echo "")

        if [ -n "$pr_number" ]; then
            log_info "Commenting on PR #$pr_number"
            gh pr comment "$pr_number" --body "⚠️ This branch is stale ($age old). Consider closing if no longer needed." || true
        fi
    done
}

# Main function
main() {
    log_info "Branch Cleanup Utility"
    echo ""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --stale-days)
                STALE_DAYS="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--dry-run] [--stale-days N]"
                echo ""
                echo "Options:"
                echo "  --dry-run       Show what would be done without making changes"
                echo "  --stale-days N  Consider branches stale after N days (default: 30)"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "Configuration:"
    log_info "  Stale threshold: $STALE_DAYS days"
    log_info "  Protected branches: $PROTECTED_BRANCHES"
    log_info "  Dry run: $DRY_RUN"
    echo ""

    # Check if we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        exit 1
    fi

    # Fetch latest
    log_info "Fetching latest branches..."
    git fetch --all --prune > /dev/null 2>&1 || log_warning "Failed to fetch"

    # Clean merged branches
    log_info "=== Merged Branch Cleanup ==="
    MERGED=$(get_merged_branches)
    if [ -n "$MERGED" ]; then
        echo "$MERGED" | while read -r branch; do
            delete_branch "$branch" "Merged to main"
        done
    else
        log_info "No merged branches found"
    fi
    echo ""

    # Clean stale branches
    log_info "=== Stale Branch Cleanup ==="
    STALE=$(get_stale_branches "$STALE_DAYS")
    if [ -n "$STALE" ]; then
        # Warn first
        warn_stale_branches "$STALE"

        # Delete
        echo "$STALE" | while IFS='|' read -r branch age author; do
            delete_branch "$branch" "Stale ($age)"
        done
    else
        log_info "No stale branches found"
    fi
    echo ""

    log_success "Branch cleanup complete"
}

# Execute
main "$@"
