#!/bin/bash
# scan-secrets.sh
# Scans code for secrets using TruffleHog and manages findings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETS_IGNORE="$PROJECT_ROOT/.secretsignore"
RESULTS_FILE="/tmp/trufflehog-results-$$-$(date +%s).json"
SUMMARY_FILE="/tmp/secret-scan-summary-$$-$(date +%s).txt"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration from environment
CI="${CI:-false}"
BUILD_ID="${BUILD_ID:-}"
COMMIT_SHA="${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
BRANCH="${CI_COMMIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')}"
GITHUB_REPO="${GITHUB_REPO:-}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
BLOCK_ON_CRITICAL="${BLOCK_ON_CRITICAL:-true}"

# Severity classification rules
CRITICAL_PATTERNS=(
    "password.*=.*['\"].+['\"]"
    "api[_-]?key.*=.*['\"].+['\"]"
    "secret[_-]?key.*=.*['\"].+['\"]"
    "private[_-]?key"
    "aws[_-]?secret"
    "token.*=.*['\"].+['\"]"
)

HIGH_PATTERNS=(
    "credentials"
    "auth[_-]?token"
    "access[_-]?key"
    "refresh[_-]?token"
)

echo -e "${BLUE}=== Secret Scanning with TruffleHog ===${NC}"
echo "Commit: $COMMIT_SHA"
echo "Branch: $BRANCH"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Check if TruffleHog is available
check_trufflehog() {
    if ! command -v trufflehog &> /dev/null; then
        echo -e "${RED}Error: TruffleHog not found${NC}"
        echo "Install with: go install github.com/trufflesecurity/trufflehog/v3/cmd/trufflehog@latest"
        exit 1
    fi
    echo -e "${GREEN}✓ TruffleHog found: $(trufflehog --version 2>&1 | head -1)${NC}"
}

# Prepare ignore file
prepare_ignore_file() {
    if [ -f "$SECRETS_IGNORE" ]; then
        echo -e "${GREEN}✓ Using .secretsignore file${NC}"
        # TruffleHog doesn't natively support ignore files, so we'll filter results
    else
        echo -e "${YELLOW}⚠ No .secretsignore file found${NC}"
        echo "Consider creating one to exclude false positives"
    fi
}

# Run TruffleHog scan
run_scan() {
    echo -e "${BLUE}Running TruffleHog scan...${NC}"

    local trufflehog_cmd="trufflehog filesystem --directory \"$PROJECT_ROOT\" --json"

    # Add exclusions if .secretsignore exists
    if [ -f "$SECRETS_IGNORE" ]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ "$pattern" =~ ^#.*$ ]] && continue
            [[ -z "$pattern" ]] && continue

            # Convert glob pattern to regex
            pattern=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/.*/g')
            trufflehog_cmd="$trufflehog_cmd --exclude-dirs \"$pattern\""
        done < "$SECRETS_IGNORE"
    fi

    # Execute scan
    eval "$trufflehog_cmd" 2>/dev/null > "$RESULTS_FILE" || true

    # Check if results file has content
    if [ ! -s "$RESULTS_FILE" ]; then
        echo -e "${GREEN}✓ No secrets detected${NC}"
        return 0
    fi

    local finding_count=$(wc -l < "$RESULTS_FILE")
    echo -e "${YELLOW}⚠ Found $finding_count potential secret(s)${NC}"
    return $finding_count
}

# Classify severity based on findings
classify_severity() {
    local finding_file="$1"
    local result=""
    local line_content

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        # Extract source metadata
        local source_name=$(echo "$line" | jq -r '.SourceName // .source_name // "unknown"' 2>/dev/null || echo "unknown")
        local source_type=$(echo "$line" | jq -r '.SourceType // .type // "unknown"' 2>/dev/null || echo "unknown")
        local detector_name=$(echo "$line" | jq -r '.DetectorName // .detector // "unknown"' 2>/dev/null || echo "unknown")

        # Extract verified status
        local verified=$(echo "$line" | jq -r '.Verified // .verified // false' 2>/dev/null || echo "false")

        # Get file path if available
        local file_path=$(echo "$line" | jq -r '.SourceMetadata?.Data?.Git?.file // .file // "unknown"' 2>/dev/null || echo "unknown")

        # Default to medium severity
        local severity="medium"

        # Critical: verified secrets
        if [ "$verified" == "true" ]; then
            severity="critical"
        fi

        # High: sensitive detector names
        case "$detector_name" in
            *AWS*|*Stripe*|*PayPal*|*Slack*|*GitHub*|*SSH*|*Private*|*Password*)
                [ "$severity" != "critical" ] && severity="high"
                ;;
        esac

        # Check against critical patterns
        for pattern in "${CRITICAL_PATTERNS[@]}"; do
            if echo "$line" | grep -iqE "$pattern"; then
                severity="critical"
                break
            fi
        done

        # Check against high patterns
        if [ "$severity" != "critical" ]; then
            for pattern in "${HIGH_PATTERNS[@]}"; do
                if echo "$line" | grep -iqE "$pattern"; then
                    severity="high"
                    break
                fi
            done
        fi

        result="$result$severity|$detector_name|$file_path|$source_name|$verified"$'\n'
    done < "$finding_file"

    echo "$result"
}

# Generate summary report
generate_summary() {
    local findings="$1"
    echo -e "${BLUE}=== Secret Scan Summary ===${NC}" > "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    echo "**Commit:** $COMMIT_SHA" >> "$SUMMARY_FILE"
    echo "**Branch:** $BRANCH" >> "$SUMMARY_FILE"
    echo "**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    local critical=0
    local high=0
    local medium=0
    local low=0

    echo "## Findings by Severity" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    while IFS='|' read -r severity detector file source verified; do
        [ -z "$severity" ] && continue

        case "$severity" in
            critical) ((critical++)) ;;
            high) ((high++)) ;;
            medium) ((medium++)) ;;
            low) ((low++)) ;;
        esac
    done <<< "$findings"

    echo "- **Critical:** $critical" >> "$SUMMARY_FILE"
    echo "- **High:** $high" >> "$SUMMARY_FILE"
    echo "- **Medium:** $medium" >> "$SUMMARY_FILE"
    echo "- **Low:** $low" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    if [ $critical -gt 0 ] || [ $high -gt 0 ]; then
        echo "## Detailed Findings" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"

        while IFS='|' read -r severity detector file source verified; do
            [ -z "$severity" ] && continue

            if [ "$severity" == "critical" ] || [ "$severity" == "high" ]; then
                echo "### $severity: $detector" >> "$SUMMARY_FILE"
                echo "- **File:** $file" >> "$SUMMARY_FILE"
                echo "- **Source:** $source" >> "$SUMMARY_FILE"
                echo "- **Verified:** $verified" >> "$SUMMARY_FILE"
                echo "" >> "$SUMMARY_FILE"
            fi
        done <<< "$findings"
    fi

    cat "$SUMMARY_FILE"
}

# Create GitHub issue for critical findings
create_github_issue() {
    local findings="$1"
    local critical=$2
    local high=$3

    if [ $critical -eq 0 ] && [ $high -eq 0 ]; then
        return 0
    fi

    if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠ GitHub credentials not set, skipping issue creation${NC}"
        return 0
    fi

    echo -e "${BLUE}Creating GitHub issue...${NC}"

    local issue_title="🔒 Security Alert: Secrets Detected in $BRANCH"
    local issue_body=$(cat "$SUMMARY_FILE")

    # Use gh CLI to create issue
    if command -v gh &> /dev/null; then
        echo "$issue_body" | gh issue create \
            --repo "$GITHUB_REPO" \
            --title "$issue_title" \
            --body "$(cat "$SUMMARY_FILE")" \
            --label "security,secrets,critical" \
            2>/dev/null && {
            echo -e "${GREEN}✓ GitHub issue created${NC}"
            return 0
        } || {
            echo -e "${YELLOW}⚠ Failed to create GitHub issue${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}⚠ GitHub CLI not found, skipping issue creation${NC}"
        return 0
    fi
}

# Store results in database
store_in_database() {
    local findings="$1"
    local critical=$2
    local high=$3
    local medium=$4
    local low=$5
    local total=$((critical + high + medium + low))

    if [ $total -eq 0 ]; then
        return 0
    fi

    if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
        echo -e "${YELLOW}⚠ Database not configured, skipping storage${NC}"
        return 0
    fi

    echo -e "${BLUE}Storing results in database...${NC}"

    # Create findings JSON
    local findings_json=""
    while IFS='|' read -r severity detector file source verified; do
        [ -z "$severity" ] && continue
        cat <<EOF
{
  "severity": "$severity",
  "detector": "$detector",
  "file": "$file",
  "source": "$source",
  "verified": "$verified"
}
EOF
    done > /tmp/findings-raw-$$ <<< "$findings"

    if command -v jq &> /dev/null; then
        findings_json=$(jq -s '.' /tmp/findings-raw-$$ 2>/dev/null || echo "[]")
    else
        findings_json="[]"
    fi
    rm -f /tmp/findings-raw-$$

    # Determine action taken
    local action="passed"
    if [ $critical -gt 0 ]; then
        action="blocked"
    elif [ $high -gt 0 ]; then
        action="warning"
    fi

    # Get scanner version
    local scanner_version=$(trufflehog --version 2>&1 | head -1 || echo "unknown")

    # Store in database
    local psql_result=0
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF 2>/dev/null
INSERT INTO security_scans (
  build_id,
  commit_sha,
  branch,
  scan_type,
  scanner_version,
  findings_count,
  critical_count,
  high_count,
  medium_count,
  low_count,
  findings,
  action_taken,
  timestamp
) VALUES (
  ${BUILD_ID:-NULL},
  '$COMMIT_SHA',
  '$BRANCH',
  'secret',
  '$scanner_version',
  $total,
  $critical,
  $high,
  $medium,
  $low,
  '$findings_json'::jsonb,
  '$action',
  NOW()
)
ON CONFLICT DO NOTHING;
EOF
    psql_result=$?

    if [ $psql_result -ne 0 ]; then
        echo -e "${YELLOW}⚠ Failed to store in database${NC}"
        return 0
    fi

    echo -e "${GREEN}✓ Results stored in database${NC}"
}

# Main execution
main() {
    check_trufflehog
    prepare_ignore_file

    # Run the scan
    run_scan || true

    # Process results
    if [ -s "$RESULTS_FILE" ]; then
        local findings=$(classify_severity "$RESULTS_FILE")

        # Generate summary
        local summary=$(generate_summary "$findings")

        # Count severities
        local critical=$(echo "$findings" | grep -c "^critical" || true)
        local high=$(echo "$findings" | grep -c "^high" || true)
        local medium=$(echo "$findings" | grep -c "^medium" || true)
        local low=$(echo "$findings" | grep -c "^low" || true)

        # Store in database
        store_in_database "$findings" $critical $high $medium $low

        # Create GitHub issue if needed
        create_github_issue "$findings" $critical $high

        # Block commit if critical secrets found
        if [ $critical -gt 0 ] && [ "$BLOCK_ON_CRITICAL" == "true" ]; then
            echo ""
            echo -e "${RED}=== BLOCKING COMMIT ===${NC}"
            echo -e "${RED}✗ Critical secrets detected! Commit blocked.${NC}"
            echo ""
            echo "Please remove the secrets before committing."
            echo "Use 'git rev-parse HEAD' to see the commit."
            echo ""
            rm -f "$RESULTS_FILE" "$SUMMARY_FILE"
            exit 1
        fi

        # Warn on high severity
        if [ $high -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}=== WARNING ===${NC}"
            echo -e "${YELLOW}⚠ High-severity secrets detected${NC}"
            echo ""
        fi
    fi

    # Cleanup
    rm -f "$RESULTS_FILE" "$SUMMARY_FILE"

    echo ""
    echo -e "${GREEN}✓ Secret scan complete${NC}"
    exit 0
}

# Run main function
main "$@"
