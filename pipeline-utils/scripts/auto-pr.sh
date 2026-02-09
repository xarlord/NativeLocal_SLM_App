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
PR_TITLE="${1:-}"
PR_BODY="${2:-}"
BASE_BRANCH="${BASE_BRANCH:-main}"
AUTO_MERGE="${AUTO_MERGE:-false}"
REVIEWERS="${REVIEWERS:-}"
ASSIGNEES="${ASSIGNEES:-}"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# PR template
get_pr_template() {
    cat << 'EOF'
## 📝 Summary

[Describe what this PR does]

## 🔄 Changes

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## ✅ Checklist

- [ ] Tests pass
- [ ] Code coverage maintained
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## 🔗 Related Issues

Closes #

## 📸 Screenshots (if applicable)

[Add screenshots for UI changes]
EOF
}

# Create PR
create_pr() {
    local title="$1"
    local body="$2"

    log_info "Creating PR: $title"

    # Build gh command
    CMD="gh pr create --base \"$BASE_BRANCH\" --title \"$title\" --body \"$body\""

    if [ -n "$ASSIGNEES" ]; then
        CMD="$CMD --assignee \"$ASSIGNEES\""
    fi

    if [ -n "$REVIEWERS" ]; then
        CMD="$CMD --reviewer \"$REVIEWERS\""
    fi

    if [ "$AUTO_MERGE" = "true" ]; then
        CMD="$CMD --label \"automerge\""
    fi

    # Execute
    PR_URL=$(eval "$CMD" 2>&1) || {
        log_error "Failed to create PR"
        echo "$PR_URL"
        return 1
    }

    log_success "PR created: $PR_URL"

    # Enable auto-merge if requested
    if [ "$AUTO_MERGE" = "true" ]; then
        log_info "Enabling auto-merge..."
        PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "")
        if [ -n "$PR_NUMBER" ]; then
            gh pr merge "$PR_NUMBER" --auto --merge || log_warning "Failed to enable auto-merge"
        fi
    fi

    return 0
}

# Get PR title from commits
get_title_from_commits() {
    local last_commit
    last_commit=$(git log -1 --pretty=%B HEAD)
    echo "$last_commit" | head -n 1
}

# Main function
main() {
    log_info "Automated PR Creator"
    echo ""

    # Check if gh is installed
    if ! command -v gh > /dev/null 2>&1; then
        log_error "gh CLI not installed. Install from https://cli.github.com/"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status > /dev/null 2>&1; then
        log_error "Not authenticated with GitHub. Run 'gh auth login'"
        exit 1
    }

    # Check if on main branch
    if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ] || [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        log_error "Cannot create PR from main/master branch"
        exit 1
    fi

    log_info "Current branch: $CURRENT_BRANCH"
    log_info "Base branch: $BASE_BRANCH"

    # Check if PR already exists
    if gh pr view --json url --jq '.url' > /dev/null 2>&1; then
        log_warning "PR already exists for this branch"
        gh pr view --json title,url,number
        exit 0
    fi

    # Get title
    if [ -z "$PR_TITLE" ]; then
        PR_TITLE=$(get_title_from_commits)
        log_info "Auto-generated title: $PR_TITLE"
    fi

    # Get body
    if [ -z "$PR_BODY" ]; then
        # Check for PR template
        if [ -f ".github/PULL_REQUEST_TEMPLATE.md" ]; then
            PR_BODY=$(cat .github/PULL_REQUEST_TEMPLATE.md)
            log_info "Using .github/PULL_REQUEST_TEMPLATE.md"
        elif [ -f ".github/pull_request_template.md" ]; then
            PR_BODY=$(cat .github/pull_request_template.md)
            log_info "Using .github/pull_request_template.md"
        else
            PR_BODY=$(get_pr_template)
            log_info "Using default template"
        fi
    fi

    # Create PR
    create_pr "$PR_TITLE" "$PR_BODY"
}

# Execute
main "$@"
