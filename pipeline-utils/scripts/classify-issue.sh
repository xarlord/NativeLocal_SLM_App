#!/bin/bash
# classify-issue.sh
# Classify issue type based on title and body
# Categories: bug, feature, enhancement, documentation, performance, security, question
# Usage: ./classify-issue.sh {issue_number}

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/pipeline-utils/config/issue-triage.yaml"

# Source security utilities
source "${SCRIPT_DIR}/security-utils.sh"

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

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

# Database query function
query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Load classification keywords from config
load_keywords() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        # Parse YAML and extract keywords for each category
        grep -A 10 "^classification_keywords:" "${CONFIG_FILE}" | grep -E "^  [a-z]+:" | sed 's/:$//' | sed 's/^  //' || echo ""
    else
        # Default keywords
        cat <<'EOF'
bug
feature
enhancement
documentation
performance
security
question
EOF
    fi
}

# Get keywords for a category from config
get_category_keywords() {
    local category="$1"

    if [[ -f "${CONFIG_FILE}" ]]; then
        # Extract keywords for this category
        awk "/^  ${category}:/,/^  [a-z]+:|^$" "${CONFIG_FILE}" | grep -E "^\s+-\s+" | sed 's/^\s\+-\s//' || echo ""
    fi
}

# Get issue data from GitHub
get_issue_data() {
    local issue_number="$1"

    log "Fetching issue #${issue_number} from GitHub..."

    local issue_json
    issue_json=$(gh issue view "${issue_number}" --json title,body,labels 2>/dev/null) || {
        error "Failed to fetch issue #${issue_number}"
    }

    echo "${issue_json}"
}

# Classify issue based on content with priority-based selection
classify_issue() {
    local title="$1"
    local body="$2"
    local content="${title} ${body}"

    # Convert to lowercase for matching
    local content_lower
    content_lower=$(echo "${content}" | tr '[:upper:]' '[:lower:]')

    # Define category priorities (higher = more important)
    declare -A CATEGORY_PRIORITY=(
        [security]=10
        [bug]=8
        [performance]=6
        [feature]=5
        [enhancement]=3
        [documentation]=2
        [question]=1
    )

    # Define scoring for each category
    declare -A scores
    local best_category="enhancement"
    local best_weighted_score=0

    # Load categories and their keywords
    local categories
    categories=$(load_keywords)

    while read -r category; do
        [[ -z "${category}" ]] && continue

        # Skip if not in our priority map
        [[ -z "${CATEGORY_PRIORITY[$category]+x}" ]] && continue

        local score=0
        local keywords
        keywords=$(get_category_keywords "${category}")

        # If no keywords in config, use defaults
        if [[ -z "${keywords}" ]]; then
            keywords=$(get_default_keywords "${category}")
        fi

        # Score based on keyword matches
        while read -r keyword; do
            [[ -z "${keyword}" ]] && continue

            if echo "${content_lower}" | grep -qF "${keyword}"; then
                score=$((score + 1))
            fi
        done <<< "${keywords}"

        scores["${category}"]=${score}

        # Calculate weighted score (score * priority)
        if [[ ${score} -gt 0 ]]; then
            local weighted_score
            weighted_score=$((score * CATEGORY_PRIORITY[$category]))

            if [[ ${weighted_score} -gt ${best_weighted_score} ]]; then
                best_weighted_score=${weighted_score}
                best_category="${category}"
            fi
        fi
    done <<< "${categories}"

    # Fallback if no strong match
    if [[ ${best_weighted_score} -eq 0 ]]; then
        if echo "${content_lower}" | grep -qE "how|what|why|when|where|who|help|\?"; then
            best_category="question"
        else
            best_category="enhancement"
        fi
    fi

    echo "${best_category}"
}

# Get default keywords for a category
get_default_keywords() {
    local category="$1"

    case "${category}" in
        bug)
            cat <<'EOF'
crash
error
broken
doesn't work
failing
fix
bug
issue
problem
fail
exception
EOF
            ;;
        feature)
            cat <<'EOF'
add
implement
new feature
would like
request
feature
support
EOF
            ;;
        enhancement)
            cat <<'EOF'
improve
enhance
better
optimize
refactor
cleanup
enhancement
improvement
EOF
            ;;
        documentation)
            cat <<'EOF'
docs
readme
documentation
guide
tutorial
doc
README
DOC
EOF
            ;;
        performance)
            cat <<'EOF'
slow
performance
optimize
faster
lag
speed
latency
performance
EOF
            ;;
        security)
            cat <<'EOF'
security
vulnerability
exploit
hack
attack
secure
permission
auth
CVE
EOF
            ;;
        question)
            cat <<'EOF'
how
what
why
when
where
who
help
question
?
EOF
            ;;
        *)
            echo ""
            ;;
    esac
}

# Apply label to GitHub issue
apply_label() {
    local issue_number="$1"
    local label="$2"

    log "Applying label '${label}' to issue #${issue_number}"

    gh issue edit "${issue_number}" --add-label "${label}" 2>/dev/null || {
        log "Warning: Failed to apply label '${label}'"
        return 1
    }

    log "Label applied successfully"
    return 0
}

# Create issue_triage table if not exists
ensure_triage_table() {
    local query="
CREATE TABLE IF NOT EXISTS issue_triage (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL UNIQUE,
    classification VARCHAR(50) NOT NULL,
    confidence NUMERIC(3,2),
    labels TEXT[],
    classified_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
"

    query_db "${query}" >/dev/null
}

# Log classification to database
log_classification() {
    local issue_number="$1"
    local category="$2"
    local confidence="${3:-0.50}"

    log "Logging classification to database..."

    # Validate and sanitize inputs
    if ! is_valid_issue_number "${issue_number}"; then
        log_error "Invalid issue number: ${issue_number}"
        return 1
    fi

    local category_escaped
    category_escaped=$(psql_escape "${category}")

    local labels_array="'{\"${category_escaped}\"}'"
    local query="
INSERT INTO issue_triage (issue_number, classification, confidence, labels)
VALUES (${issue_number}, '${category_escaped}', ${confidence}, ${labels_array})
ON CONFLICT (issue_number) DO UPDATE SET
    classification = EXCLUDED.classification,
    confidence = EXCLUDED.confidence,
    labels = EXCLUDED.labels,
    updated_at = NOW();
"

    query_db "${query}" >/dev/null

    log "Classification logged successfully"
}

# Add comment to issue with classification
add_classification_comment() {
    local issue_number="$1"
    local category="$2"

    local comment="This issue has been automatically classified as **${category}**.

The classification is based on keyword analysis of the issue title and description. If this classification is incorrect, please update the labels manually."

    log "Adding classification comment to issue #${issue_number}"

    gh issue comment "${issue_number}" --body "${comment}" 2>/dev/null || {
        log "Warning: Failed to add comment"
        return 1
    }

    log "Comment added successfully"
    return 0
}

# ============================================
# Main Execution
# ============================================

main() {
    local issue_number="$1"

    if [[ -z "${issue_number}" ]]; then
        error "Usage: $0 {issue_number}"
    fi

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        error "GitHub CLI (gh) is not installed or not in PATH"
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
    fi

    log "Starting issue classification for #${issue_number}"

    # Ensure database table exists
    ensure_triage_table

    # Get issue data
    local issue_json
    issue_json=$(get_issue_data "${issue_number}")

    local title
    local body
    title=$(echo "${issue_json}" | jq -r '.title')
    body=$(echo "${issue_json}" | jq -r '.body')

    log "Issue title: ${title}"

    # Classify the issue
    local classification
    classification=$(classify_issue "${title}" "${body}")

    log "Classification: ${classification}"

    # Apply label
    apply_label "${issue_number}" "${classification}"

    # Log to database
    log_classification "${issue_number}" "${classification}" "0.70"

    # Add comment (optional - can be disabled if too noisy)
    # add_classification_comment "${issue_number}" "${classification}"

    log "Issue classification complete!"
    log "Issue #${issue_number} classified as: ${classification}"
}

# Run main function
main "$@"
