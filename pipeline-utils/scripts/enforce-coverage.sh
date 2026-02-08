#!/bin/bash
# enforce-coverage.sh
# Parses JaCoCo coverage reports, enforces thresholds, and creates PR comments
# Usage: enforce-coverage.sh [--threshold=80] [--pr-number=N] [--report-path=PATH]

set -e

# ============================================
# Configuration
# ============================================
COVERAGE_THRESHOLD=${COVERAGE_THRESHOLD:-80}
REPORT_PATH=${REPORT_PATH:""}
PR_NUMBER=${PR_NUMBER:""}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-woodpecker}
DB_USER=${DB_USER:-woodpecker}
DB_PASSWORD=${DB_PASSWORD:-woodpecker}

# GitHub configuration
GITHUB_REPO=${GITHUB_REPO:-${CI_REPO}}
GITHUB_TOKEN=${GITHUB_TOKEN:-${GITHUB_TOKEN}}

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --threshold=*)
      COVERAGE_THRESHOLD="${1#*=}"
      shift
      ;;
    --pr-number=*)
      PR_NUMBER="${1#*=}"
      shift
      ;;
    --report-path=*)
      REPORT_PATH="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: $0 [--threshold=80] [--pr-number=N] [--report-path=PATH]"
      echo ""
      echo "Enforces code coverage thresholds and creates PR comments"
      echo ""
      echo "Options:"
      echo "  --threshold=PERCENT    Coverage threshold (default: 80)"
      echo "  --pr-number=N          PR number to comment on"
      echo "  --report-path=PATH     Path to JaCoCo XML report"
      echo ""
      echo "Environment Variables:"
      echo "  GITHUB_TOKEN           GitHub API token"
      echo "  DB_HOST, DB_PORT       Database connection"
      echo "  DB_NAME, DB_USER       Database credentials"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ============================================
# Functions
# ============================================

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_success() {
  echo "✅ $1"
}

log_warning() {
  echo "⚠️  $1"
}

# Find JaCoCo report
find_jacoco_report() {
  log_info "Searching for JaCoCo coverage report..."

  # Common locations
  local locations=(
    "app/build/reports/jacoco/jacocoTestReport/jacocoTestReport.xml"
    "build/reports/jacoco/test/jacocoTestReport.xml"
    "app/build/test-results/jacocoTestReport.xml"
    "build/test-results/jacocoTestReport.xml"
  )

  for location in "${locations[@]}"; do
    if [ -f "$location" ]; then
      log_info "Found report at: $location"
      echo "$location"
      return 0
    fi
  done

  log_error "No JaCoCo report found"
  log_info "Searched in:"
  printf "  - %s\n" "${locations[@]}"
  return 1
}

# Parse JaCoCo XML report
parse_jacoco_report() {
  local report_file=$1

  log_info "Parsing JaCoCo report: $report_file"

  if [ ! -f "$report_file" ]; then
    log_error "Report file not found: $report_file"
    return 1
  fi

  # Check if xmllint is available
  if ! command -v xmllint &> /dev/null; then
    log_error "xmllint not found. Installing..."
    apt-get update && apt-get install -y libxml2-utils
  fi

  # Extract coverage metrics
  local overall=$(xmllint --xpath "string(/report/counter[@type='INSTRUCTION']/@covered)" "$report_file" 2>/dev/null || echo "0")
  local overall_total=$(xmllint --xpath "string(/report/counter[@type='INSTRUCTION']/@missed)" "$report_file" 2>/dev/null || echo "0")

  local line_covered=$(xmllint --xpath "string(/report/counter[@type='LINE']/@covered)" "$report_file" 2>/dev/null || echo "0")
  local line_total=$(xmllint --xpath "string(/report/counter[@type='LINE']/@missed)" "$report_file" 2>/dev/null || echo "0")

  local branch_covered=$(xmllint --xpath "string(/report/counter[@type='BRANCH']/@covered)" "$report_file" 2>/dev/null || echo "0")
  local branch_total=$(xmllint --xpath "string(/report/counter[@type='BRANCH']/@missed)" "$report_file" 2>/dev/null || echo "0")

  local method_covered=$(xmllint --xpath "string(/report/counter[@type='METHOD']/@covered)" "$report_file" 2>/dev/null || echo "0")
  local method_total=$(xmllint --xpath "string(/report/counter[@type='METHOD']/@missed)" "$report_file" 2>/dev/null || echo "0")

  # Calculate percentages
  local overall_total_sum=$((overall + overall_total))
  local line_total_sum=$((line_covered + line_total))
  local branch_total_sum=$((branch_covered + branch_total))
  local method_total_sum=$((method_covered + method_total))

  local overall_pct=0
  local line_pct=0
  local branch_pct=0
  local method_pct=0

  if [ $overall_total_sum -gt 0 ]; then
    overall_pct=$(awk "BEGIN {printf \"%.2f\", ($overall / $overall_total_sum) * 100}")
  fi

  if [ $line_total_sum -gt 0 ]; then
    line_pct=$(awk "BEGIN {printf \"%.2f\", ($line_covered / $line_total_sum) * 100}")
  fi

  if [ $branch_total_sum -gt 0 ]; then
    branch_pct=$(awk "BEGIN {printf \"%.2f\", ($branch_covered / $branch_total_sum) * 100}")
  fi

  if [ $method_total_sum -gt 0 ]; then
    method_pct=$(awk "BEGIN {printf \"%.2f\", ($method_covered / $method_total_sum) * 100}")
  fi

  # Output JSON
  cat <<EOF
{
  "overall_coverage": $overall_pct,
  "line_coverage": $line_pct,
  "branch_coverage": $branch_pct,
  "method_coverage": $method_pct,
  "instructions_covered": $overall,
  "instructions_total": $overall_total_sum,
  "lines_covered": $line_covered,
  "lines_total": $line_total_sum,
  "branches_covered": $branch_covered,
  "branches_total": $branch_total_sum,
  "methods_covered": $method_covered,
  "methods_total": $method_total_sum
}
EOF
}

# Store coverage in database
store_coverage_history() {
  local coverage_json=$1
  local commit_sha=${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo "unknown")}
  local branch=${CI_COMMIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}
  local build_id=${CI_BUILD_NUMBER:-0}

  log_info "Storing coverage history in database..."

  # Extract values
  local overall=$(echo "$coverage_json" | jq -r '.overall_coverage')
  local line=$(echo "$coverage_json" | jq -r '.line_coverage')
  local branch=$(echo "$coverage_json" | jq -r '.branch_coverage')
  local method=$(echo "$coverage_json" | jq -r '.method_coverage')

  # Check if threshold met
  local threshold_met="false"
  if (( $(echo "$overall >= $COVERAGE_THRESHOLD" | bc -l) )); then
    threshold_met="true"
  fi

  # Insert into database
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO coverage_history (
  build_id,
  commit_sha,
  branch,
  overall_coverage,
  line_coverage,
  branch_coverage,
  method_coverage,
  threshold_met,
  threshold_value
) VALUES (
  $build_id,
  '$commit_sha',
  '$branch',
  $overall,
  $line,
  $branch,
  $method,
  $threshold_met,
  $COVERAGE_THRESHOLD
);
EOF

  if [ $? -eq 0 ]; then
    log_success "Coverage history stored successfully"
  else
    log_warning "Failed to store coverage history (non-critical)"
  fi
}

# Generate PR comment
generate_pr_comment() {
  local coverage_json=$1
  local threshold=$2
  local commit_sha=${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null | cut -c1-8)}

  local overall=$(echo "$coverage_json" | jq -r '.overall_coverage')
  local line=$(echo "$coverage_json" | jq -r '.line_coverage')
  local branch=$(echo "$coverage_json" | jq -r '.branch_coverage')
  local method=$(echo "$coverage_json" | jq -r '.method_coverage')

  local status="✅ PASSED"
  local color="🟢"

  if (( $(echo "$overall < $threshold" | bc -l) )); then
    status="❌ FAILED"
    color="🔴"
  fi

  # Generate progress bar
  local progress_bar=""
  local filled=$(awk "BEGIN {printf \"%.0f\", $overall / 5}")
  local empty=$((20 - filled))
  for ((i=0; i<filled; i++)); do progress_bar+="█"; done
  for ((i=0; i<empty; i++)); do progress_bar+="░"; done

  cat <<EOF
## $color Code Coverage Report: $status

**Overall Coverage:** ${overall}% (threshold: ${threshold}%)
\`\`\`
$progress_bar ${overall}%
\`\`\`

### Detailed Metrics

| Metric | Coverage | Status |
|--------|----------|--------|
| **Instructions** | ${overall}% | $([ $(echo "$overall >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |
| **Lines** | ${line}% | $([ $(echo "$line >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |
| **Branches** | ${branch}% | $([ $(echo "$branch >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |
| **Methods** | ${method}% | $([ $(echo "$method >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |

### Statistics

- **Instructions Covered:** $(echo "$coverage_json" | jq -r '.instructions_covered') / $(echo "$coverage_json" | jq -r '.instructions_total')
- **Lines Covered:** $(echo "$coverage_json" | jq -r '.lines_covered') / $(echo "$coverage_json" | jq -r '.lines_total')
- **Branches Covered:** $(echo "$coverage_json" | jq -r '.branches_covered') / $(echo "$coverage_json" | jq -r '.branches_total')
- **Methods Covered:** $(echo "$coverage_json" | jq -r '.methods_covered') / $(echo "$coverage_json" | jq -r '.methods_total')

---

**Commit:** \`$commit_sha\`
**Report generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

*This comment was automatically generated by the CI/CD quality gate*
EOF
}

# Post PR comment
post_pr_comment() {
  local comment=$1

  if [ -z "$PR_NUMBER" ]; then
    log_warning "No PR number provided, skipping comment"
    return 0
  fi

  if [ -z "$GITHUB_TOKEN" ]; then
    log_warning "No GITHUB_TOKEN provided, skipping comment"
    return 0
  fi

  log_info "Posting comment to PR #$PR_NUMBER..."

  local comment_url="https://api.github.com/repos/$GITHUB_REPO/issues/$PR_NUMBER/comments"

  local response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$comment_url" \
    -d "{\"body\": $(echo "$comment" | jq -Rs .)}")

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    log_success "Comment posted successfully"
    return 0
  else
    log_error "Failed to post comment: $response"
    return 1
  fi
}

# Create GitHub issue for coverage failure
create_coverage_issue() {
  local coverage_json=$1
  local threshold=$2
  local commit_sha=${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null | cut -c1-8)}
  local branch=${CI_COMMIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}

  local overall=$(echo "$coverage_json" | jq -r '.overall_coverage')
  local gap=$(awk "BEGIN {printf \"%.2f\", $threshold - $overall}")

  local title="[Quality Gate] Code coverage below threshold ($overall% < $threshold%)"

  local body=$(cat <<EOF
## Code Coverage Quality Gate Failed

The code coverage for this commit is **below the required threshold**.

### Details

- **Current Coverage:** ${overall}%
- **Required Threshold:** ${threshold}%
- **Gap:** ${gap} percentage points
- **Branch:** $branch
- **Commit:** \`$commit_sha\`

### Coverage Breakdown

| Metric | Coverage | Status |
|--------|----------|--------|
| **Instructions** | $(echo "$coverage_json" | jq -r '.overall_coverage')% | ❌ |
| **Lines** | $(echo "$coverage_json" | jq -r '.line_coverage')% | $([ $(echo "$(echo "$coverage_json" | jq -r '.line_coverage') >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |
| **Branches** | $(echo "$coverage_json" | jq -r '.branch_coverage')% | $([ $(echo "$(echo "$coverage_json" | jq -r '.branch_coverage') >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |
| **Methods** | $(echo "$coverage_json" | jq -r '.method_coverage')% | $([ $(echo "$(echo "$coverage_json" | jq -r '.method_coverage') >= $threshold" | bc -l) -eq 1 ] && echo "✅" || echo "❌") |

### Actions Required

1. **Review test coverage:** Add tests for uncovered code paths
2. **Consider refactoring:** Break down complex, untested code
3. **Update threshold:** If ${threshold}% is too high, adjust in pipeline configuration

### Coverage History

Run the following query to see coverage trends:

\`\`\`sql
SELECT
  DATE(timestamp) as date,
  ROUND(AVG(overall_coverage), 2) as avg_coverage,
  COUNT(*) as builds
FROM coverage_history
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;
\`\`\`

---

*This issue was automatically created by the CI/CD quality gate*

**Labels:** quality-gate, coverage, automated
EOF
)

  if [ -z "$GITHUB_TOKEN" ]; then
    log_warning "No GITHUB_TOKEN provided, skipping issue creation"
    return 0
  fi

  log_info "Creating GitHub issue for coverage failure..."

  local response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/issues" \
    -d "{\"title\": \"$title\", \"body\": $(echo "$body" | jq -Rs .), \"labels\": [\"quality-gate\", \"coverage\", \"automated\"]}")

  if echo "$response" | jq -e '.number' > /dev/null 2>&1; then
    local issue_number=$(echo "$response" | jq -r '.number')
    log_success "Issue created: #$issue_number"
    echo "$issue_number"
    return 0
  else
    log_error "Failed to create issue: $response"
    return 1
  fi
}

# ============================================
# Main Execution
# ============================================

main() {
  log_info "=== Coverage Enforcement ==="
  log_info "Threshold: ${COVERAGE_THRESHOLD}%"

  # Find report
  if [ -z "$REPORT_PATH" ]; then
    REPORT_PATH=$(find_jacoco_report)
    if [ $? -ne 0 ]; then
      exit 1
    fi
  fi

  # Parse report
  log_info "Parsing coverage report..."
  coverage_json=$(parse_jacoco_report "$REPORT_PATH")

  if [ $? -ne 0 ]; then
    log_error "Failed to parse coverage report"
    exit 1
  fi

  log_success "Coverage report parsed successfully"
  echo "$coverage_json" | jq .

  # Extract overall coverage
  overall_coverage=$(echo "$coverage_json" | jq -r '.overall_coverage')

  # Store in database
  store_coverage_history "$coverage_json"

  # Generate PR comment
  comment=$(generate_pr_comment "$coverage_json" "$COVERAGE_THRESHOLD")
  echo "$comment"

  # Post comment
  post_pr_comment "$comment"

  # Check threshold
  if (( $(echo "$overall_coverage < $COVERAGE_THRESHOLD" | bc -l) )); then
    log_error "Coverage ${overall_coverage}% is below threshold ${COVERAGE_THRESHOLD}%"

    # Create GitHub issue
    create_coverage_issue "$coverage_json" "$COVERAGE_THRESHOLD"

    log_error "Quality gate FAILED"
    exit 1
  else
    log_success "Coverage ${overall_coverage}% meets threshold ${COVERAGE_THRESHOLD}%"
    log_success "Quality gate PASSED"
    exit 0
  fi
}

# Run main
main
