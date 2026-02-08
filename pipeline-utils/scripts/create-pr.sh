#!/bin/bash
# create-pr.sh
# Create pull request using gh CLI
# Usage: ./create-pr.sh "Title" "Body" "source-branch" "target-branch"
# Logs to automated_prs table

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source common functions
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
    init_common
else
    # Fallback if common.sh not available
    log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2; }
    error() { log "ERROR: $*"; exit 1; }
    trap cleanup EXIT
    cleanup() {
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            log "Script failed with exit code: $exit_code"
        fi
    }
fi

RETRY_SCRIPT="${SCRIPT_DIR}/retry-command.sh"
TEMPLATE_DIR="${PROJECT_ROOT}/pipeline-utils/templates"

# Git configuration
GIT_REMOTE="${GIT_REMOTE:-origin}"
DEFAULT_TARGET_BRANCH="${DEFAULT_TARGET_BRANCH:-main}"
DEFAULT_PR_TYPE="${DEFAULT_PR_TYPE:-feature}"

# ============================================
# Helper Functions
# ============================================


# Check gh CLI
check_gh_cli() {
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI not found. Please install gh first."
    fi

    if ! gh auth status &>/dev/null; then
        error "GitHub CLI not authenticated. Run: gh auth login"
    fi
}

# Get repository info
get_repo_info() {
    local repo_url
    repo_url=$(git remote get-url "${GIT_REMOTE}" 2>/dev/null || echo "")

    if [[ -z "${repo_url}" ]]; then
        error "Cannot get repository URL. Is '${GIT_REMOTE}' remote configured?"
    fi

    # Extract owner/repo from URL
    local repo
    repo=$(echo "${repo_url}" | sed -n 's|.*github.com[:/]\([^/]*\)/\([^/]*\)\.git|\1/\2|p')

    if [[ -z "${repo}" ]]; then
        error "Cannot parse repository owner/name from URL"
    fi

    echo "${repo}"
}

# Detect PR type from branch name
detect_pr_type() {
    local branch_name="$1"

    case "${branch_name}" in
        feature/*)
            echo "feature"
            ;;
        bugfix/*|fix/*)
            echo "fix"
            ;;
        hotfix/*)
            echo "hotfix"
            ;;
        release/*)
            echo "release"
            ;;
        refactor/*)
            echo "refactor"
            ;;
        deps/*|dependency/*|dependencies/*)
            echo "dependency"
            ;;
        *)
            echo "${DEFAULT_PR_TYPE}"
            ;;
    esac
}

# Determine risk level
determine_risk_level() {
    local pr_type="$1"
    local branch_name="$2"

    case "${pr_type}" in
        hotfix)
            echo "high"
            ;;
        dependency)
            # Check if it's a major version bump
            if [[ "${branch_name}" =~ major ]]; then
                echo "high"
            else
                echo "medium"
            fi
            ;;
        release)
            echo "medium"
            ;;
        feature|refactor)
            echo "medium"
            ;;
        fix|bugfix)
            echo "low"
            ;;
        *)
            echo "low"
            ;;
    esac
}

# Load PR template
load_pr_template() {
    local pr_type="$1"

    # Try type-specific template first
    local template_file="${TEMPLATE_DIR}/${pr_type}-pr.md"

    if [[ ! -f "${template_file}" ]]; then
        # Try default refactor template
        template_file="${TEMPLATE_DIR}/refactor-pr.md"
    fi

    if [[ ! -f "${template_file}" ]]; then
        # Try dependency template
        template_file="${TEMPLATE_DIR}/dep-update-pr.md"
    fi

    if [[ -f "${template_file}" ]]; then
        cat "${template_file}"
    else
        # Return empty if no template found
        echo ""
    fi
}

# Get default reviewers
get_default_reviewers() {
    local pr_type="$1"

    # Could be configured via environment variables or config files
    case "${pr_type}" in
        dependency)
            echo "${DEFAULT_REVIEWERS_DEPENDENCY:-}"
            ;;
        refactor)
            echo "${DEFAULT_REVIEWERS_REFACTOR:-}"
            ;;
        *)
            echo "${DEFAULT_REVIEWERS:-}"
            ;;
    esac
}

# Get labels for PR type
get_labels() {
    local pr_type="$1"
    local risk_level="$2"

    local labels=("${pr_type}" "automated")

    # Add risk label
    labels+=("risk:${risk_level}")

    # Add additional labels based on type
    case "${pr_type}" in
        dependency)
            labels+=("dependencies")
            ;;
        hotfix)
            labels+=("urgent" "priority:high")
            ;;
        refactor)
            labels+=("refactoring")
            ;;
    esac

    # Convert to comma-separated string
    local IFS=','
    echo "${labels[*]}"
}

# Create the PR
create_pr() {
    local title="$1"
    local body="$2"
    local source_branch="$3"
    local target_branch="$4"
    local pr_type="$5"
    local labels="$6"
    local reviewers="$7"
    local is_draft="${8:-false}"

    log "Creating pull request..."
    log "  Title: ${title}"
    log "  Source: ${source_branch}"
    log "  Target: ${target_branch}"
    log "  Type: ${pr_type}"
    log "  Labels: ${labels}"

    # Build gh pr create command
    local cmd=("gh" "pr" "create")
    cmd+=("--title" "${title}")
    cmd+=("--body" "${body}")
    cmd+=("--base" "${target_branch}")
    cmd+=("--head" "${source_branch}")

    # Add labels
    if [[ -n "${labels}" ]]; then
        IFS=',' read -ra label_array <<< "${labels}"
        for label in "${label_array[@]}"; do
            cmd+=("--label" "${label}")
        done
    fi

    # Add reviewers
    if [[ -n "${reviewers}" ]]; then
        cmd+=("--reviewer" "${reviewers}")
    fi

    # Set draft
    if [[ "${is_draft}" == "true" ]]; then
        cmd+=("--draft")
    fi

    # Execute with retry
    local output
    output=$("${RETRY_SCRIPT}" --max-retries=3 --delay=10 "${cmd[@]}" 2>&1)

    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        error "Failed to create PR: ${output}"
    fi

    # Extract PR URL and number
    local pr_url="${output}"
    local pr_number
    pr_number=$(echo "${output}" | grep -oE '[0-9]+' | head -1 || echo "")

    if [[ -z "${pr_number}" ]]; then
        # Try to get PR number from URL
        pr_number=$(echo "${pr_url}" | grep -oE '/pull/([0-9]+)' | cut -d'/' -f3 || echo "")
    fi

    echo "${pr_number}|${pr_url}"
}

# Log to database
log_to_database() {
    local pr_number="$1"
    local pr_url="$2"
    local title="$3"
    local body="$4"
    local source_branch="$5"
    local target_branch="$6"
    local pr_type="$7"
    local risk_level="$8"
    local reviewers="$9"
    local labels="${10}"
    local is_draft="${11}"

    log "Logging to database..."

    local sanitized_title
    local sanitized_body
    sanitized_title=$(echo "${title}" | sed "s/'/''/g")
    sanitized_body=$(echo "${body}" | sed "s/'/''/g")

    local reviewers_json
    if has_jq; then
        reviewers_json=$(echo "${reviewers}" | jq -R -s 'split(",") | map(select(length > 0))' 2>/dev/null || echo "[]")
    else
        # Fallback: create simple JSON array
        if [[ -n "${reviewers}" ]]; then
            reviewers_json="[\"$(echo "${reviewers}" | sed 's/,/"","/g')\"]"
        else
            reviewers_json="[]"
        fi
    fi

    local labels_json
    if has_jq; then
        labels_json=$(echo "${labels}" | jq -R -s 'split(",") | map(select(length > 0))' 2>/dev/null || echo "[]")
    else
        # Fallback: create simple JSON array
        if [[ -n "${labels}" ]]; then
            labels_json="[\"$(echo "${labels}" | sed 's/,/"","/g')\"]"
        else
            labels_json="[]"
        fi
    fi

    local query="
INSERT INTO automated_prs (
    pr_number,
    pr_url,
    title,
    body,
    source_branch,
    target_branch,
    pr_type,
    risk_level,
    draft,
    reviewers,
    labels,
    status,
    created_by_script,
    created_at
) VALUES (
    ${pr_number},
    '${pr_url}',
    '${sanitized_title}',
    '${sanitized_body}',
    '${source_branch}',
    '${target_branch}',
    '${pr_type}',
    '${risk_level}',
    ${is_draft},
    '${reviewers_json}'::jsonb,
    '${labels_json}'::jsonb,
    'open',
    'create-pr.sh',
    NOW()
) RETURNING id;
"

    local pr_id
    pr_id=$(query_db "${query}")

    if [[ -n "${pr_id}" ]]; then
        log "Database entry created with ID: ${pr_id}"
        echo "${pr_id}"
    else
        log "Warning: Failed to log to database"
        echo ""
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    local title="$1"
    local body="$2"
    local source_branch="${3:-$(git branch --show-current)}"
    local target_branch="${4:-${DEFAULT_TARGET_BRANCH}}"
    local is_draft="${CREATE_DRAFT_PR:-false}"

    log "=== PR Creation Script ==="

    # Check prerequisites
    check_gh_cli

    # Get repository info
    local repo
    repo=$(get_repo_info)
    log "Repository: ${repo}"

    # Get current branch if not specified
    if [[ -z "${source_branch}" ]]; then
        error "Cannot determine source branch. Please specify it explicitly."
    fi

    # Detect PR type
    local pr_type
    pr_type=$(detect_pr_type "${source_branch}")
    log "PR type: ${pr_type}"

    # Determine risk level
    local risk_level
    risk_level=$(determine_risk_level "${pr_type}" "${source_branch}")
    log "Risk level: ${risk_level}"

    # Load template if body is a placeholder
    if [[ "${body}" == "AUTO" ]] || [[ "${body}" == "auto" ]] || [[ -z "${body}" ]]; then
        log "Loading PR template..."
        local template
        template=$(load_pr_template "${pr_type}")

        if [[ -n "${template}" ]]; then
            # Basic template variable substitution
            template=$(echo "${template}" | sed "s|{{type}}|${pr_type}|g")
            template=$(echo "${template}" | sed "s|{{risk_level}}|${risk_level}|g")
            template=$(echo "${template}" | sed "s|{{source_branch}}|${source_branch}|g")
            template=$(echo "${template}" | sed "s|{{target_branch}}|${target_branch}|g")
            template=$(echo "${template}" | sed "s|{{CURRENT_DATE}}|$(date -u +'%Y-%m-%d')|g")

            body="${template}"
            log "Template loaded"
        fi
    fi

    # Get labels
    local labels
    labels=$(get_labels "${pr_type}" "${risk_level}")

    # Get reviewers
    local reviewers
    reviewers=$(get_default_reviewers "${pr_type}")

    # Create PR
    local pr_result
    pr_result=$(create_pr "${title}" "${body}" "${source_branch}" "${target_branch}" "${pr_type}" "${labels}" "${reviewers}" "${is_draft}")

    local pr_number
    local pr_url
    pr_number=$(echo "${pr_result}" | cut -d'|' -f1)
    pr_url=$(echo "${pr_result}" | cut -d'|' -f2)

    if [[ -z "${pr_number}" ]] || [[ -z "${pr_url}" ]]; then
        error "Failed to create PR or parse result"
    fi

    # Log to database
    local pr_id
    pr_id=$(log_to_database "${pr_number}" "${pr_url}" "${title}" "${body}" "${source_branch}" "${target_branch}" "${pr_type}" "${risk_level}" "${reviewers}" "${labels}" "${is_draft}")

    log "=== PR Created Successfully ==="
    log "PR Number: ${pr_number}"
    log "PR URL: ${pr_url}"
    log "Database ID: ${pr_id}"
    echo ""
    log "PR Summary:"
    log "  Title: ${title}"
    log "  Type: ${pr_type}"
    log "  Risk: ${risk_level}"
    log "  Labels: ${labels}"
    log "  Source: ${source_branch}"
    log "  Target: ${target_branch}"
    echo ""
    log "Next steps:"
    log "1. Monitor PR status: gh pr view ${pr_number}"
    log "2. Request additional reviews: ./request-review.sh ${pr_number}"
    log "3. Check mergeability: ./auto-merge-check.sh ${pr_number}"

    # Output PR number for scripting
    echo "${pr_number}"
}

# Show usage
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <title> <body> [source-branch] [target-branch]"
    echo ""
    echo "Arguments:"
    echo "  title          PR title (use quotes)"
    echo "  body           PR body (use quotes, or 'AUTO' to use template)"
    echo "  source-branch  Source branch (default: current branch)"
    echo "  target-branch  Target branch (default: ${DEFAULT_TARGET_BRANCH})"
    echo ""
    echo "Environment variables:"
    echo "  CREATE_DRAFT_PR   Set to 'true' to create draft PR"
    echo "  DEFAULT_REVIEWERS Comma-separated list of default reviewers"
    echo ""
    echo "Examples:"
    echo "  $0 'Add new feature' 'This adds a cool feature' feature/new-cool-feature main"
    echo "  $0 'Update dependency' 'AUTO' deps/update-lib-1.0.0 main"
    echo "  $0 'Fix login bug' 'Fixes #123' bugfix/login-error main"
    echo ""
    echo "The script will:"
    echo "  1. Detect PR type from branch name"
    echo "  2. Load appropriate template (if body='AUTO')"
    echo "  3. Assign labels based on type and risk"
    echo "  4. Create PR using gh CLI"
    echo "  5. Log to automated_prs table"
    exit 1
fi

# Change to project root
cd "${PROJECT_ROOT}" || error "Cannot change to project root"

# Run main function
main "$@"
