#!/bin/bash
# estimate-complexity.sh
# Estimate issue complexity (1-5 scale)
# Factors: lines of code, files affected, keywords, historical data
# Add complexity label and estimate comment
# Usage: ./estimate-complexity.sh {issue_number}

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

# Complexity factor weights
LINES_WEIGHT="${LINES_WEIGHT:-0.3}"
FILES_WEIGHT="${FILES_WEIGHT:-0.2}"
KEYWORD_WEIGHT="${KEYWORD_WEIGHT:-0.5}"

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

# Load weights from config
load_weights() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        local lines_weight
        local files_weight
        local keyword_weight

        lines_weight=$(grep "^  lines_of_code_weight:" "${CONFIG_FILE}" | awk '{print $2}' | sed 's/#.*//')
        files_weight=$(grep "^  files_affected_weight:" "${CONFIG_FILE}" | awk '{print $2}' | sed 's/#.*//')
        keyword_weight=$(grep "^  keyword_weight:" "${CONFIG_FILE}" | awk '{print $2}' | sed 's/#.*//')

        [[ -n "${lines_weight}" ]] && LINES_WEIGHT="${lines_weight}"
        [[ -n "${files_weight}" ]] && FILES_WEIGHT="${files_weight}"
        [[ -n "${keyword_weight}" ]] && KEYWORD_WEIGHT="${keyword_weight}"
    fi
}

# Get issue data
get_issue_data() {
    local issue_number="$1"

    log "Fetching issue #${issue_number} from GitHub..."

    gh issue view "${issue_number}" --json title,body,labels 2>/dev/null || {
        error "Failed to fetch issue #${issue_number}"
    }
}

# Estimate lines of code from issue
estimate_lines_of_code() {
    local text="$1"

    local lines=0
    local text_lower
    text_lower=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

    # Look for explicit line mentions
    if echo "${text_lower}" | grep -qE "([0-9]+\s*lines?)|lines?\s*of\s*code"; then
        local mentioned
        mentioned=$(echo "${text_lower}" | grep -oE "[0-9]+\s*lines?" | grep -oE "[0-9]+" | head -1)

        if [[ -n "${mentioned}" ]]; then
            lines=${mentioned}
        fi
    else
        # Estimate from description length
        local word_count
        word_count=$(echo "${text}" | wc -w)

        if [[ ${word_count} -gt 500 ]]; then
            lines=500
        elif [[ ${word_count} -gt 200 ]]; then
            lines=200
        elif [[ ${word_count} -gt 100 ]]; then
            lines=100
        else
            lines=50
        fi
    fi

    echo "${lines}"
}

# Count files affected
count_files_affected() {
    local text="$1"

    local files=0
    local text_lower
    text_lower=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

    # Look for file path mentions
    local file_mentions
    file_mentions=$(echo "${text}" | grep -oE '\b[a-zA-Z0-9_/-]+\.[a-z]{2,4}\b|\b[src/app]/[a-zA-Z0-9_/-]+\b' | wc -l)

    files=${file_mentions}

    # Look for explicit file count mentions
    if echo "${text_lower}" | grep -qE "([0-9]+\s*files?)|files?\s*affected"; then
        local mentioned
        mentioned=$(echo "${text_lower}" | grep -oE "[0-9]+\s*files?" | grep -oE "[0-9]+" | head -1)

        if [[ -n "${mentioned}" && "${mentioned}" -gt "${files}" ]]; then
            files=${mentioned}
        fi
    fi

    # Cap at reasonable maximum
    if [[ ${files} -gt 20 ]]; then
        files=20
    fi

    echo "${files}"
}

# Score keywords for complexity
score_keywords() {
    local text="$1"

    local score=0
    local text_lower
    text_lower=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

    # High complexity keywords
    local high_keywords="refactor rewrite redesign restructure architecture migration major overhaul"
    for keyword in ${high_keywords}; do
        if echo "${text_lower}" | grep -qF "${keyword}"; then
            score=$((score + 5))
        fi
    done

    # Medium complexity keywords
    local medium_keywords="feature enhancement implement add new support optimize improve fix"
    for keyword in ${medium_keywords}; do
        if echo "${text_lower}" | grep -qF "${keyword}"; then
            score=$((score + 2))
        fi
    done

    # Low complexity keywords
    local low_keywords="minor trivial simple small typo update change tweak adjust"
    for keyword in ${low_keywords}; do
        if echo "${text_lower}" | grep -qF "${keyword}"; then
            score=$((score + 1))
        fi
    done

    echo "${score}"
}

# Get historical complexity for similar issues (with SQL injection protection)
get_historical_complexity() {
    local title="$1"

    # Extract key terms
    local terms
    terms=$(echo "${title}" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower]' | tr -s ' ' '\n' | while read -r word; do
        if [[ ${#word} -ge 4 ]]; then
            echo "${word}"
        fi
    done | head -3 | tr '\n' '|')

    if [[ -z "${terms}" ]]; then
        echo "0"
        return
    fi

    # Escape terms for SQL to prevent injection
    local terms_escaped
    terms_escaped=$(psql_escape "${terms}")

    local query="
SELECT AVG(complexity_score)
FROM issue_complexity
WHERE issue_title ~ '${terms_escaped}'
AND estimated_at > NOW() - INTERVAL '6 months';
"

    local avg_complexity
    avg_complexity=$(query_db "${query}" | awk '{printf "%.0f", $1}' || echo "0")

    echo "${avg_complexity}"
}

# Calculate complexity score (1-5)
calculate_complexity() {
    local lines="$1"
    local files="$2"
    local keyword_score="$3"
    local historical="$4"

    # Normalize each factor to 0-1 scale
    local lines_norm
    local files_norm
    local keywords_norm

    # Lines: 0-1000+ -> 0-1
    if [[ ${lines} -ge 1000 ]]; then
        lines_norm=1.0
    else
        lines_norm=$(awk "BEGIN {printf \"%.2f\", ${lines}/1000}")
    fi

    # Files: 0-20+ -> 0-1
    if [[ ${files} -ge 20 ]]; then
        files_norm=1.0
    else
        files_norm=$(awk "BEGIN {printf \"%.2f\", ${files}/20}")
    fi

    # Keywords: 0-15+ -> 0-1
    if [[ ${keyword_score} -ge 15 ]]; then
        keywords_norm=1.0
    else
        keywords_norm=$(awk "BEGIN {printf \"%.2f\", ${keyword_score}/15}")
    fi

    # Calculate weighted score (0-1)
    local weighted_score
    weighted_score=$(awk "BEGIN {printf \"%.2f\", ${lines_norm}*${LINES_WEIGHT} + ${files_norm}*${FILES_WEIGHT} + ${keywords_norm}*${KEYWORD_WEIGHT}}")

    # Convert to 1-5 scale
    local complexity
    complexity=$(awk "BEGIN {printf \"%.0f\", ${weighted_score}*4 + 1}")

    # Apply historical data as adjustment
    if [[ "${historical}" -gt 0 ]]; then
        # Blend current estimate with historical (70/30)
        complexity=$(awk "BEGIN {printf \"%.0f\", (${complexity}*0.7 + ${historical}*0.3)}")
    fi

    # Ensure within bounds
    if [[ ${complexity} -lt 1 ]]; then
        complexity=1
    elif [[ ${complexity} -gt 5 ]]; then
        complexity=5
    fi

    echo "${complexity}"
}

# Get complexity description
get_complexity_description() {
    local complexity="$1"

    case "${complexity}" in
        1)
            echo "Trivial - Quick fix, minimal changes"
            ;;
        2)
            echo "Low - Simple changes, well-defined scope"
            ;;
        3)
            echo "Medium - Moderate changes, some complexity"
            ;;
        4)
            echo "High - Complex changes, multiple components"
            ;;
        5)
            echo "Critical - Major refactoring or architecture changes"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Apply complexity label
apply_complexity_label() {
    local issue_number="$1"
    local complexity="$2"

    # Remove existing complexity labels
    local existing_labels
    existing_labels=$(gh issue view "${issue_number}" --json labels --jq '.labels[].name' 2>/dev/null | grep "^complexity-" || echo "")

    while read -r label; do
        [[ -z "${label}" ]] && continue
        gh issue edit "${issue_number}" --remove-label "${label}" 2>/dev/null || true
    done <<< "${existing_labels}"

    # Add new label
    local new_label="complexity-${complexity}"
    log "Applying label '${new_label}' to issue #${issue_number}"

    gh issue edit "${issue_number}" --add-label "${new_label}" 2>/dev/null || {
        log "Warning: Failed to apply label"
        return 1
    }

    return 0
}

# Add complexity estimate comment
add_complexity_comment() {
    local issue_number="$1"
    local complexity="$2"
    local description="$3"
    local lines="$4"
    local files="$5"
    local keyword_score="$6"

    local comment="## Complexity Estimate

**Estimated Complexity:** ${complexity}/5

**Description:** ${description}

### Breakdown

| Factor | Score |
|--------|-------|
| Estimated Lines of Code | ~${lines} |
| Files Affected | ${files} |
| Keyword Analysis | ${keyword_score} |

This estimate is based on keyword analysis and issue description. The actual complexity may vary.

---
*This comment was automatically generated by the complexity estimation system*"

    log "Adding complexity comment to issue #${issue_number}"

    gh issue comment "${issue_number}" --body "${comment}" 2>/dev/null || {
        log "Warning: Failed to add comment"
        return 1
    }

    return 0
}

# Ensure complexity tracking table exists
ensure_complexity_table() {
    local query="
CREATE TABLE IF NOT EXISTS issue_complexity (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL UNIQUE,
    issue_title TEXT,
    complexity_score INTEGER NOT NULL,
    lines_estimate INTEGER,
    files_estimate INTEGER,
    keyword_score INTEGER,
    historical_avg INTEGER,
    estimated_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
"

    query_db "${query}" >/dev/null
}

# Log complexity to database with SQL injection protection
log_complexity() {
    local issue_number="$1"
    local title="$2"
    local complexity="$3"
    local lines="$4"
    local files="$5"
    local keyword_score="$6"
    local historical="$7"

    log "Logging complexity to database..."

    # Validate inputs
    if ! is_valid_issue_number "${issue_number}"; then
        log_error "Invalid issue number: ${issue_number}"
        return 1
    fi

    # Validate complexity is in valid range
    if [[ ${complexity} -lt 1 || ${complexity} -gt 5 ]]; then
        log_error "Invalid complexity score: ${complexity} (must be 1-5)"
        return 1
    fi

    # Escape title for SQL
    local title_escaped
    title_escaped=$(psql_escape "${title}" | head -c 500)

    local query="
INSERT INTO issue_complexity (issue_number, issue_title, complexity_score, lines_estimate, files_estimate, keyword_score, historical_avg)
VALUES (${issue_number}, '${title_escaped}', ${complexity}, ${lines}, ${files}, ${keyword_score}, ${historical})
ON CONFLICT (issue_number) DO UPDATE SET
    issue_title = EXCLUDED.issue_title,
    complexity_score = EXCLUDED.complexity_score,
    lines_estimate = EXCLUDED.lines_estimate,
    files_estimate = EXCLUDED.files_estimate,
    keyword_score = EXCLUDED.keyword_score,
    historical_avg = EXCLUDED.historical_avg,
    updated_at = NOW();
"

    query_db "${query}" >/dev/null

    log "Complexity logged successfully"
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

    log "Starting complexity estimation for issue #${issue_number}"

    # Load weights from config
    load_weights

    log "Weights: lines=${LINES_WEIGHT}, files=${FILES_WEIGHT}, keywords=${KEYWORD_WEIGHT}"

    # Ensure database table exists
    ensure_complexity_table

    # Get issue data
    local issue_json
    issue_json=$(get_issue_data "${issue_number}")

    local title
    local body
    title=$(echo "${issue_json}" | jq -r '.title')
    body=$(echo "${issue_json}" | jq -r '.body')

    local content="${title} ${body}"

    log "Issue title: ${title}"

    # Analyze factors
    local lines
    local files
    local keyword_score
    local historical

    lines=$(estimate_lines_of_code "${content}")
    files=$(count_files_affected "${content}")
    keyword_score=$(score_keywords "${content}")
    historical=$(get_historical_complexity "${title}")

    log "Analysis:"
    log "  Estimated lines: ${lines}"
    log "  Files affected: ${files}"
    log "  Keyword score: ${keyword_score}"
    log "  Historical average: ${historical}"

    # Calculate complexity
    local complexity
    complexity=$(calculate_complexity "${lines}" "${files}" "${keyword_score}" "${historical}")

    log "Calculated complexity: ${complexity}/5"

    # Get description
    local description
    description=$(get_complexity_description "${complexity}")

    # Apply label
    apply_complexity_label "${issue_number}" "${complexity}"

    # Add comment
    add_complexity_comment "${issue_number}" "${complexity}" "${description}" "${lines}" "${files}" "${keyword_score}"

    # Log to database
    log_complexity "${issue_number}" "${title}" "${complexity}" "${lines}" "${files}" "${keyword_score}" "${historical}"

    log "Complexity estimation complete!"
    log "Issue #${issue_number} complexity: ${complexity}/5 - ${description}"
}

# Run main function
main "$@"
