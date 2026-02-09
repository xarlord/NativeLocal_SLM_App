#!/bin/bash
set -euo pipefail

# Automated Issue Triage Script
# Classifies, labels, and assigns issues automatically

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
REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
DRY_RUN="${DRY_RUN:-false}"

# Issue classification keywords
declare -A ISSUE_CATEGORIES=(
    ["bug"]="bug error crash fail exception broken doesn't work"
    ["enhancement"]="feature enhancement add improve"
    ["documentation"]="docs documentation readme guide"
    ["performance"]="performance slow optimization speed memory"
    ["security"]="security vulnerability exploit xss injection"
    ["ui/ux"]="ui ux design interface layout visual"
    ["question"]="question help how to"
)

# Get issue title and body
get_issue_details() {
    local issue_number="$1"
    gh issue view "$issue_number" --json title,body --jq '.title,.body'
}

# Classify issue
classify_issue() {
    local title="$1"
    local body="$2"
    local content="$title $body"
    content=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    for category in "${!ISSUE_CATEGORIES[@]}"; do
        keywords="${ISSUE_CATEGORIES[$category]}"
        for keyword in $keywords; do
            if echo "$content" | grep -q "$keyword"; then
                echo "$category"
                return 0
            fi
        done
    done

    echo "unclassified"
}

# Detect duplicates
detect_duplicate() {
    local title="$1"
    local similar_issues

    # Search for similar issues
    similar_issues=$(gh issue list \
        --search "$title" \
        --state all \
        --json number,title \
        --jq '.[] | select(.number != env.IssueNumber) | .number' \
        2>/dev/null || echo "")

    if [ -n "$similar_issues" ]; then
        echo "$similar_issues" | head -n 1
    fi
}

# Get code owner for files
get_code_owner() {
    # Parse CODEOWNERS file
    if [ -f "CODEOWNERS" ]; then
        # Simple CODEOWNERS parser
        grep -E "@[a-zA-Z0-9_-]+" CODEOWNERS | head -n 1 | grep -oE "@[a-zA-Z0-9_-]+" | head -n 1 || echo ""
    elif [ -f ".github/CODEOWNERS" ]; then
        grep -E "@[a-zA-Z0-9_-]+" ".github/CODEOWNERS" | head -n 1 | grep -oE "@[a-zA-Z0-9_-]+" | head -n 1 || echo ""
    fi
}

# Estimate complexity
estimate_complexity() {
    local title="$1"
    local body="$2"
    local complexity="small"

    # Count lines
    lines=$(echo -e "$title\n$body" | wc -l)

    # Check for complexity indicators
    if echo "$title" | grep -qiE "refactor|rewrite|architecture|infrastructure"; then
        complexity="large"
    elif [ "$lines" -gt 50 ]; then
        complexity="medium"
    fi

    echo "$complexity"
}

# Triage single issue
triage_issue() {
    local issue_number="$1"
    local title body category duplicate owner complexity

    log_info "Triaging issue #$issue_number..."

    # Get issue details
    details=$(get_issue_details "$issue_number")
    title=$(echo "$details" | sed -n '1p')
    body=$(echo "$details" | sed -n '2p')

    # Classify
    category=$(classify_issue "$title" "$body")
    log_info "  Category: $category"

    # Check for duplicates
    export IssueNumber="$issue_number"
    duplicate=$(detect_duplicate "$title")
    if [ -n "$duplicate" ]; then
        log_warning "  Possible duplicate: #$duplicate"
    fi

    # Get complexity
    complexity=$(estimate_complexity "$title" "$body")
    log_info "  Complexity: $complexity"

    # Get code owner
    owner=$(get_code_owner)
    if [ -n "$owner" ]; then
        log_info "  Suggested assignee: $owner"
    fi

    # Apply labels
    if [ "$DRY_RUN" != "true" ]; then
        gh issue edit "$issue_number" --add-label "$category" --add-label "triaged" --add-label "complexity:$complexity" 2>/dev/null || true

        # Assign if owner found
        if [ -n "$owner" ]; then
            gh issue edit "$issue_number" --assignee "$owner" 2>/dev/null || true
        fi

        # Comment if duplicate
        if [ -n "$duplicate" ]; then
            gh issue comment "$issue_number" --body "Possible duplicate of #$duplicate" 2>/dev/null || true
        fi

        log_success "  Issue #$issue_number triaged"
    else
        log_info "  [DRY RUN] Would add labels: $category, triaged, complexity:$complexity"
    fi
}

# Get open issues
get_open_issues() {
    gh issue list \
        --state open \
        --json number \
        --jq '.[].number' \
        2>/dev/null || echo ""
}

# Main function
main() {
    log_info "=== Automated Issue Triage ==="
    echo ""

    # Check for gh
    if ! command -v gh > /dev/null 2>&1; then
        log_error "gh CLI not installed"
        exit 1
    fi

    # Check authentication
    if ! gh auth status > /dev/null 2>&1; then
        log_error "Not authenticated with GitHub"
        exit 1
    fi

    # Get issues
    ISSUES=$(get_open_issues)

    if [ -z "$ISSUES" ]; then
        log_info "No open issues to triage"
        exit 0
    fi

    # Count issues
    ISSUE_COUNT=$(echo "$ISSUES" | wc -l)
    log_info "Found $ISSUE_COUNT open issues"
    echo ""

    # Triage each issue
    echo "$ISSUES" | while read -r issue_number; do
        triage_issue "$issue_number"
        echo ""
    done

    log_success "Issue triage complete"
}

# Execute
main "$@"
