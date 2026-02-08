#!/bin/bash
# detect-duplicates.sh
# Find potential duplicate issues using GitHub search API
# Calculate similarity score based on word overlap
# Usage: ./detect-duplicates.sh {issue_number}

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

# Similarity threshold (default: 0.7 = 70%)
SIMILARITY_THRESHOLD="${DUPLICATE_THRESHOLD:-0.7}"

# Max results to check
MAX_RESULTS="${MAX_RESULTS:-20}"

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

# Get threshold from config file
get_threshold_from_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        local threshold
        threshold=$(grep "^duplicate_threshold:" "${CONFIG_FILE}" | awk '{print $2}' | sed 's/#.*//')

        if [[ -n "${threshold}" ]]; then
            echo "${threshold}"
            return
        fi
    fi

    echo "0.7"  # Default threshold
}

# Get issue data
get_issue_data() {
    local issue_number="$1"

    gh issue view "${issue_number}" --json title,body,state,labels 2>/dev/null || {
        error "Failed to fetch issue #${issue_number}"
    }
}

# Extract keywords from text
extract_keywords() {
    local text="$1"

    # Convert to lowercase
    text=$(echo "${text}" | tr '[:upper:]' '[:lower:]')

    # Remove common stop words
    local stop_words="a an the and or but is are was were be been being have has had do does did will would should could may might must can this that these those with for from at by to in on of it its"

    # Remove punctuation and split into words
    echo "${text}" | tr -d '[:punct:]' | tr -s ' ' '\n' | while read -r word; do
        # Skip stop words and short words
        if [[ ${#word} -lt 3 ]]; then
            continue
        fi

        if echo "${stop_words}" | grep -qw "${word}"; then
            continue
        fi

        echo "${word}"
    done | sort -u
}

# Calculate Jaccard similarity between two texts (FIXED)
calculate_similarity() {
    local text1="$1"
    local text2="$2"

    local keywords1
    local keywords2

    keywords1=$(extract_keywords "${text1}")
    keywords2=$(extract_keywords "${text2}")

    # Count unique words in each
    local count1
    local count2
    count1=$(echo "${keywords1}" | grep -c '.' || echo "0")
    count2=$(echo "${keywords2}" | grep -c '.' || echo "0")

    if [[ ${count1} -eq 0 || ${count2} -eq 0 ]]; then
        echo "0.0"
        return
    fi

    # Create sorted files for comm command
    local sorted1
    local sorted2
    sorted1=$(echo "${keywords1}" | sort)
    sorted2=$(echo "${keywords2}" | sort)

    # Count intersection (words in both)
    local intersection
    intersection=$(comm -12 <(echo "${sorted1}") <(echo "${sorted2}") | wc -l)

    # Count union (unique words in either)
    # We need to combine both lists and count unique words
    local combined
    combined=$(echo "${sorted1}"$'\n'"${sorted2}" | sort -u)
    local union
    union=$(echo "${combined}" | wc -l)

    if [[ ${union} -eq 0 ]]; then
        echo "0.0"
        return
    fi

    # Calculate Jaccard index: intersection / union
    local similarity
    similarity=$(awk "BEGIN {printf \"%.2f\", ${intersection}/${union}}")

    echo "${similarity}"
}

# Search for similar issues
search_similar_issues() {
    local issue_number="$1"
    local title="$2"

    log "Searching for similar issues..."

    # Extract key terms from title (words longer than 3 chars)
    local search_terms
    search_terms=$(echo "${title}" | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]' | tr -s ' ' '\n' | while read -r word; do
        if [[ ${#word} -ge 4 ]]; then
            echo "${word}"
        fi
    done | head -5 | tr '\n' ' ')

    if [[ -z "${search_terms}" ]]; then
        log "No suitable search terms found"
        echo ""
        return
    fi

    log "Search terms: ${search_terms}"

    # Search GitHub issues
    local results
    results=$(gh search issues --search "${search_terms}" --limit "${MAX_RESULTS}" --json number,title,state,url 2>/dev/null || echo "[]")

    # Filter out the current issue and closed issues
    echo "${results}" | jq "[.[] | select(.number != ${issue_number}) | select(.state == \"open\")]"
}

# Check if two issues are duplicates
check_duplicate() {
    local issue1_number="$1"
    local issue1_title="$2"
    local issue1_body="$3"
    local issue2_number="$4"
    local issue2_title="$5"
    local issue2_body="$6"

    local text1="${issue1_title} ${issue1_body}"
    local text2="${issue2_title} ${issue2_body}"

    # Calculate similarity
    local similarity
    similarity=$(calculate_similarity "${text1}" "${text2}")

    echo "${similarity}"
}

# Add duplicate comment to issue
add_duplicate_comment() {
    local issue_number="$1"
    local duplicate_of="$2"
    local similarity="$3"

    local comment="## Potential Duplicate Detected

This issue may be a duplicate of [#${duplicate_of}](https://github.com/${GITHUB_REPO}/issues/${duplicate_of}).

**Similarity Score:** ${similarity}

Please review both issues and:
- If they are duplicates: Close this issue and add any relevant comments to the original
- If they are different: Remove the \`duplicate\` label and explain the differences

---
*This comment was automatically generated by the duplicate detection system*"

    log "Adding duplicate comment to issue #${issue_number}"

    gh issue comment "${issue_number}" --body "${comment}" 2>/dev/null || {
        log "Warning: Failed to add comment"
        return 1
    }

    return 0
}

# Apply duplicate label
apply_duplicate_label() {
    local issue_number="$1"

    log "Applying 'duplicate' label to issue #${issue_number}"

    gh issue edit "${issue_number}" --add-label "duplicate" 2>/dev/null || {
        log "Warning: Failed to apply label"
        return 1
    }

    return 0
}

# Ensure duplicate tracking table exists
ensure_duplicate_table() {
    local query="
CREATE TABLE IF NOT EXISTS issue_duplicates (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    duplicate_of INTEGER NOT NULL,
    similarity_score NUMERIC(3,2) NOT NULL,
    detected_at TIMESTAMP DEFAULT NOW(),
    confirmed BOOLEAN DEFAULT NULL,
    confirmed_by VARCHAR(100),
    UNIQUE(issue_number, duplicate_of)
);
"

    query_db "${query}" >/dev/null
}

# Log duplicate detection to database
log_duplicate() {
    local issue_number="$1"
    local duplicate_of="$2"
    local similarity="$3"

    log "Logging duplicate detection to database..."

    # Validate inputs
    if ! is_valid_issue_number "${issue_number}"; then
        log_error "Invalid issue number: ${issue_number}"
        return 1
    fi

    if ! is_valid_issue_number "${duplicate_of}"; then
        log_error "Invalid duplicate issue number: ${duplicate_of}"
        return 1
    fi

    # Validate similarity is a number
    if ! [[ "${similarity}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Invalid similarity score: ${similarity}"
        return 1
    fi

    local query="
INSERT INTO issue_duplicates (issue_number, duplicate_of, similarity_score)
VALUES (${issue_number}, ${duplicate_of}, ${similarity})
ON CONFLICT (issue_number, duplicate_of) DO UPDATE SET
    similarity_score = EXCLUDED.similarity_score,
    detected_at = NOW();
"

    query_db "${query}" >/dev/null

    log "Duplicate logged successfully"
}

# Check if issue already has duplicate label
has_duplicate_label() {
    local issue_number="$1"

    local labels
    labels=$(gh issue view "${issue_number}" --json labels --jq '.labels[].name' 2>/dev/null || echo "")

    if echo "${labels}" | grep -q "duplicate"; then
        return 0
    else
        return 1
    fi
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

    # Get GitHub repo
    GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]\(.*\)\.git|\1|' || echo '')}"

    if [[ -z "${GITHUB_REPO}" ]]; then
        error "Could not determine GitHub repository"
    fi

    # Load threshold from config
    SIMILARITY_THRESHOLD=$(get_threshold_from_config)
    log "Similarity threshold: ${SIMILARITY_THRESHOLD}"

    log "Starting duplicate detection for issue #${issue_number}"

    # Ensure database table exists
    ensure_duplicate_table

    # Check if already marked as duplicate
    if has_duplicate_label "${issue_number}"; then
        log "Issue already marked as duplicate, skipping"
        exit 0
    fi

    # Get issue data
    log "Fetching issue data..."
    local issue_json
    issue_json=$(get_issue_data "${issue_number}")

    local issue_title
    local issue_body
    issue_title=$(echo "${issue_json}" | jq -r '.title')
    issue_body=$(echo "${issue_json}" | jq -r '.body')

    log "Issue title: ${issue_title}"

    # Search for similar issues
    local similar_issues
    similar_issues=$(search_similar_issues "${issue_number}" "${issue_title}")

    local similar_count
    similar_count=$(echo "${similar_issues}" | jq 'length')

    if [[ ${similar_count} -eq 0 ]]; then
        log "No similar issues found"
        exit 0
    fi

    log "Found ${similar_count} potentially similar issues"

    # Check each similar issue
    local found_duplicates=0

    for i in $(seq 0 $((similar_count - 1))); do
        local other_issue
        other_issue=$(echo "${similar_issues}" | jq ".[${i}]")

        local other_number
        local other_title
        other_number=$(echo "${other_issue}" | jq -r '.number')
        other_title=$(echo "${other_issue}" | jq -r '.title')

        log "Checking issue #${other_number}: ${other_title}"

        # Get other issue body
        local other_body
        other_body=$(gh issue view "${other_number}" --json body --jq '.body' 2>/dev/null || echo "")

        # Calculate similarity
        local similarity
        similarity=$(check_duplicate \
            "${issue_number}" "${issue_title}" "${issue_body}" \
            "${other_number}" "${other_title}" "${other_body}")

        log "  Similarity: ${similarity}"

        # Check if similarity exceeds threshold
        if (( $(echo "${similarity} >= ${SIMILARITY_THRESHOLD}" | bc -l) )); then
            log "  ✓ Potential duplicate found!"

            # Add comment and label
            add_duplicate_comment "${issue_number}" "${other_number}" "${similarity}"
            apply_duplicate_label "${issue_number}"

            # Log to database
            log_duplicate "${issue_number}" "${other_number}" "${similarity}"

            found_duplicates=$((found_duplicates + 1))

            # Only mark the first duplicate to avoid spam
            break
        fi
    done

    if [[ ${found_duplicates} -eq 0 ]]; then
        log "No duplicates found (similarity below threshold ${SIMILARITY_THRESHOLD})"
    else
        log "Found ${found_duplicates} potential duplicate(s)"
    fi

    log "Duplicate detection complete!"
}

# Run main function
main "$@"
