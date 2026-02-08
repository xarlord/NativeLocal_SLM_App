#!/bin/bash
# check-licenses.sh
# Validates open-source licenses against compliance policy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LICENSE_POLICY="$SCRIPT_DIR/../config/license-policy.yaml"
REPORT_FILE="/tmp/license-report-$$-$(date +%s).json"
COMPLIANCE_REPORT="/tmp/license-compliance-$$-$(date +%s).md"

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
DB_USER="${DB_NAME:-woodpecker}"

# License categories
ALLOWED_LICENSES=()
RESTRICTED_LICENSES=()
REVIEW_LICENSES=()

echo -e "${BLUE}=== License Compliance Check ===${NC}"
echo "Commit: $COMMIT_SHA"
echo "Branch: $BRANCH"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Check for Gradle
check_gradle() {
    if [ ! -f "$PROJECT_ROOT/build.gradle" ] && [ ! -f "$PROJECT_ROOT/build.gradle.kts" ]; then
        echo -e "${YELLOW}⚠ No Gradle project found${NC}"
        echo "This script requires a Gradle project with the license plugin"
        exit 1
    fi
    echo -e "${GREEN}✓ Gradle project detected${NC}"
}

# Load license policy from YAML config
load_license_policy() {
    if [ ! -f "$LICENSE_POLICY" ]; then
        echo -e "${RED}Error: License policy not found: $LICENSE_POLICY${NC}"
        exit 1
    fi

    echo -e "${BLUE}Loading license policy...${NC}"

    # Parse YAML file (simplified parser)
    local current_section=""
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Check section headers
        if [[ "$line" =~ ^allowed: ]]; then
            current_section="allowed"
        elif [[ "$line" =~ ^restricted: ]]; then
            current_section="restricted"
        elif [[ "$line" =~ ^review_required: ]]; then
            current_section="review"
        # Parse license entries
        elif [[ "$line" =~ ^\s*-\s*(.+)$ ]]; then
            local license="${BASH_REMATCH[1]}"
            # Trim whitespace and quotes
            license=$(echo "$license" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'\'']\|["'\'']$//g')

            case "$current_section" in
                allowed)
                    ALLOWED_LICENSES+=("$license")
                    ;;
                restricted)
                    RESTRICTED_LICENSES+=("$license")
                    ;;
                review)
                    REVIEW_LICENSES+=("$license")
                    ;;
            esac
        fi
    done < "$LICENSE_POLICY"

    echo -e "${GREEN}✓ Loaded policy:${NC}"
    echo "  - Allowed licenses: ${#ALLOWED_LICENSES[@]}"
    echo "  - Restricted licenses: ${#RESTRICTED_LICENSES[@]}"
    echo "  - Review-required: ${#REVIEW_LICENSES[@]}"
}

# Generate license report using Gradle
generate_license_report() {
    echo -e "${BLUE}Generating license report...${NC}"

    cd "$PROJECT_ROOT"

    # Check if license plugin is configured
    if ! ./gradlew tasks --all 2>/dev/null | grep -qi "license"; then
        echo -e "${YELLOW}⚠ License plugin not found. Checking dependencies...${NC}"

        # Fallback: parse dependencies directly
        if ! ./gradlew dependencies 2>/dev/null > "/tmp/gradle-deps-$$"; then
            echo -e "${RED}Error: Failed to retrieve dependencies${NC}"
            exit 1
        fi

        # Extract dependencies (simplified)
        grep -E '^\+\-\-\-|^\||[a-z0-9\.\-]+:[a-z0-9\.\-]+:[0-9\.]+' "/tmp/gradle-deps-$$" | \
            sed 's/.*\([a-z0-9\.\-]\+:[a-z0-9\.\-]\+:[0-9\.]\+\).*/\1/' | \
            sort -u > "/tmp/deps-list-$$"

        echo -e "${YELLOW}⚠ License information not available without plugin${NC}"
        echo "Install Gradle License Report plugin for full compliance checking"

        rm -f "/tmp/gradle-deps-$$" "/tmp/deps-list-$$"
        return 1
    fi

    # Run license report
    ./gradlew licenseReport 2>/dev/null || {
        echo -e "${YELLOW}⚠ License report generation failed, trying alternative...${NC}"
        ./gradlew generateLicenseReport 2>/dev/null || {
            echo -e "${RED}Error: Failed to generate license report${NC}"
            exit 1
        }
    }

    # Find generated report
    local report_path=$(find build/reports/licenses -name "*.json" -o -name "*.xml" 2>/dev/null | head -1)

    if [ -z "$report_path" ]; then
        # Try common locations
        for path in \
            "build/reports/licenses/license-report.json" \
            "build/reports/dependency-license/license-report.json" \
            "build/reports/license-report.json"
        do
            if [ -f "$path" ]; then
                report_path="$path"
                break
            fi
        done
    fi

    if [ -z "$report_path" ]; then
        echo -e "${YELLOW}⚠ License report not found${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ License report generated: $report_path${NC}"
    cp "$report_path" "$REPORT_FILE"
    return 0
}

# Parse and classify licenses
classify_licenses() {
    local report="$1"

    # If no report file, use dependency list fallback
    if [ ! -f "$report" ]; then
        echo -e "${YELLOW}⚠ Using dependency list (no license info)${NC}"
        return 0
    fi

    echo -e "${BLUE}Classifying licenses...${NC}"

    # Parse JSON report
    if command -v jq &> /dev/null; then
        jq -r '.dependencies[]? | .name + " | " + (.licenses[]? | .name // "Unknown")' "$report" 2>/dev/null || \
        jq -r '.[]? | .name + " | " + (.license // "Unknown")' "$report" 2>/dev/null
    else
        echo -e "${YELLOW}⚠ jq not found, attempting XML parse...${NC}"
        # Add XML parsing logic here if needed
    fi
}

# Check license against policy
check_license() {
    local license_name="$1"
    local dependency_name="$2"

    # Normalize license name
    local normalized=$(echo "$license_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')

    # Check against restricted licenses
    for restricted in "${RESTRICTED_LICENSES[@]}"; do
        local restricted_norm=$(echo "$restricted" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        if [[ "$normalized" == *"$restricted_norm"* ]]; then
            echo "RESTRICTED|$dependency_name|$license_name"
            return 0
        fi
    done

    # Check against review-required licenses
    for review in "${REVIEW_LICENSES[@]}"; do
        local review_norm=$(echo "$review" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        if [[ "$normalized" == *"$review_norm"* ]]; then
            echo "REVIEW|$dependency_name|$license_name"
            return 0
        fi
    done

    # Check against allowed licenses
    for allowed in "${ALLOWED_LICENSES[@]}"; do
        local allowed_norm=$(echo "$allowed" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        if [[ "$normalized" == *"$allowed_norm"* ]]; then
            echo "ALLOWED|$dependency_name|$license_name"
            return 0
        fi
    done

    # Unknown license
    echo "UNKNOWN|$dependency_name|$license_name"
    return 0
}

# Generate compliance report
generate_compliance_report() {
    local classifications="$1"

    echo -e "${BLUE}=== License Compliance Report ===${NC}" > "$COMPLIANCE_REPORT"
    echo "" >> "$COMPLIANCE_REPORT"
    echo "**Commit:** $COMMIT_SHA" >> "$COMPLIANCE_REPORT"
    echo "**Branch:** $BRANCH" >> "$COMPLIANCE_REPORT"
    echo "**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$COMPLIANCE_REPORT"
    echo "" >> "$COMPLIANCE_REPORT"

    local restricted_count=0
    local review_count=0
    local allowed_count=0
    local unknown_count=0

    # Count and list by category
    echo "## Summary" >> "$COMPLIANCE_REPORT"
    echo "" >> "$COMPLIANCE_REPORT"

    while IFS='|' read -r status dep lic; do
        [ -z "$status" ] && continue

        case "$status" in
            RESTRICTED) ((restricted_count++)) ;;
            REVIEW) ((review_count++)) ;;
            ALLOWED) ((allowed_count++)) ;;
            UNKNOWN) ((unknown_count++)) ;;
        esac
    done <<< "$classifications"

    echo "- **Restricted (Blocked):** $restricted_count" >> "$COMPLIANCE_REPORT"
    echo "- **Review Required:** $review_count" >> "$COMPLIANCE_REPORT"
    echo "- **Allowed:** $allowed_count" >> "$COMPLIANCE_REPORT"
    echo "- **Unknown:** $unknown_count" >> "$COMPLIANCE_REPORT"
    echo "" >> "$COMPLIANCE_REPORT"

    # List restricted licenses
    if [ $restricted_count -gt 0 ]; then
        echo "## 🔴 Restricted Licenses (BLOCKED)" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"
        echo "The following dependencies use licenses that violate our policy:" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"

        while IFS='|' read -r status dep lic; do
            [ -z "$status" ] && continue
            if [ "$status" == "RESTRICTED" ]; then
                echo "- **$dep**" >> "$COMPLIANCE_REPORT"
                echo "  - License: $lic" >> "$COMPLIANCE_REPORT"
                echo "  - Action: Remove this dependency or seek approval" >> "$COMPLIANCE_REPORT"
                echo "" >> "$COMPLIANCE_REPORT"
            fi
        done <<< "$classifications"
    fi

    # List review-required licenses
    if [ $review_count -gt 0 ]; then
        echo "## 🟡 Review Required" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"
        echo "The following dependencies require legal review:" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"

        while IFS='|' read -r status dep lic; do
            [ -z "$status" ] && continue
            if [ "$status" == "REVIEW" ]; then
                echo "- **$dep**" >> "$COMPLIANCE_REPORT"
                echo "  - License: $lic" >> "$COMPLIANCE_REPORT"
                echo "  - Action: Review with legal team before use" >> "$COMPLIANCE_REPORT"
                echo "" >> "$COMPLIANCE_REPORT"
            fi
        done <<< "$classifications"
    fi

    # List unknown licenses
    if [ $unknown_count -gt 0 ]; then
        echo "## ⚠ Unknown Licenses" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"
        echo "The following dependencies have unknown license information:" >> "$COMPLIANCE_REPORT"
        echo "" >> "$COMPLIANCE_REPORT"

        while IFS='|' read -r status dep lic; do
            [ -z "$status" ] && continue
            if [ "$status" == "UNKNOWN" ]; then
                echo "- **$dep**" >> "$COMPLIANCE_REPORT"
                echo "  - License: $lic" >> "$COMPLIANCE_REPORT"
                echo "" >> "$COMPLIANCE_REPORT"
            fi
        done <<< "$classifications"
    fi

    # Compliance status
    echo "## Compliance Status" >> "$COMPLIANCE_REPORT"
    echo "" >> "$COMPLIANCE_REPORT"

    if [ $restricted_count -gt 0 ]; then
        echo "❌ **FAILED** - Restricted licenses found" >> "$COMPLIANCE_REPORT"
    elif [ $review_count -gt 0 ]; then
        echo "⚠️ **WARNING** - Review required" >> "$COMPLIANCE_REPORT"
    elif [ $unknown_count -gt 0 ]; then
        echo "⚠️ **WARNING** - Unknown licenses present" >> "$COMPLIANCE_REPORT"
    else
        echo "✅ **PASSED** - All licenses compliant" >> "$COMPLIANCE_REPORT"
    fi

    cat "$COMPLIANCE_REPORT"
}

# Create GitHub issue for violations
create_github_issue() {
    local restricted=$1
    local review=$2

    if [ $restricted -eq 0 ] && [ $review -eq 0 ]; then
        return 0
    fi

    if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠ GitHub credentials not set, skipping issue creation${NC}"
        return 0
    fi

    echo -e "${BLUE}Creating GitHub issue...${NC}"

    local issue_title="⚖️ License Compliance Alert: $BRANCH"

    # Use gh CLI to create issue
    if command -v gh &> /dev/null; then
        gh issue create \
            --repo "$GITHUB_REPO" \
            --title "$issue_title" \
            --body "$(cat "$COMPLIANCE_REPORT")" \
            --label "legal,license-compliance" \
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

# Store in database
store_in_database() {
    local restricted=$1
    local review=$2
    local allowed=$3
    local unknown=$4
    local total=$((restricted + review + allowed + unknown))

    if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
        echo -e "${YELLOW}⚠ Database not configured, skipping storage${NC}"
        return 0
    fi

    echo -e "${BLUE}Storing results in database...${NC}"

    # Determine action
    local action="passed"
    if [ $restricted -gt 0 ]; then
        action="blocked"
    elif [ $review -gt 0 ] || [ $unknown -gt 0 ]; then
        action="warning"
    fi

    # Create findings JSON
    local findings_json="{\"restricted\": $restricted, \"review\": $review, \"unknown\": $unknown, \"allowed\": $allowed}"

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
  'license',
  'Gradle License Plugin',
  $total,
  $restricted,
  $review,
  $unknown,
  0,
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
    check_gradle
    load_license_policy

    # Generate report
    if ! generate_license_report; then
        echo -e "${YELLOW}⚠ Could not generate full license report${NC}"
        echo "Install Gradle License Report plugin for complete compliance checking"
        exit 0
    fi

    # Classify licenses
    local classifications=$(classify_licenses "$REPORT_FILE")

    if [ -z "$classifications" ]; then
        echo -e "${YELLOW}⚠ No license information found${NC}"
        rm -f "$REPORT_FILE" "$COMPLIANCE_REPORT"
        exit 0
    fi

    # Check each license
    local results=""
    while IFS='|' read -r dep lic; do
        [ -z "$dep" ] && continue
        results+=$(check_license "$lic" "$dep")$'\n'
    done <<< "$classifications"

    # Generate compliance report
    local report=$(generate_compliance_report "$results")

    # Count categories
    local restricted=$(echo "$results" | grep -c "^RESTRICTED" || true)
    local review=$(echo "$results" | grep -c "^REVIEW" || true)
    local allowed=$(echo "$results" | grep -c "^ALLOWED" || true)
    local unknown=$(echo "$results" | grep -c "^UNKNOWN" || true)

    # Store in database
    store_in_database $restricted $review $allowed $unknown

    # Create GitHub issue if needed
    create_github_issue $restricted $review

    # Cleanup
    rm -f "$REPORT_FILE"

    # Block on restricted licenses
    if [ $restricted -gt 0 ]; then
        echo ""
        echo -e "${RED}=== LICENSE COMPLIANCE FAILED ===${NC}"
        echo -e "${RED}✗ Restricted licenses found! Build blocked.${NC}"
        echo ""
        rm -f "$COMPLIANCE_REPORT"
        exit 1
    fi

    # Warn on review-required
    if [ $review -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}=== WARNING ===${NC}"
        echo -e "${YELLOW}⚠ Licenses requiring legal review detected${NC}"
        echo ""
    fi

    echo ""
    echo -e "${GREEN}✓ License compliance check complete${NC}"
    rm -f "$COMPLIANCE_REPORT"
    exit 0
}

# Run main function
main "$@"
