#!/bin/bash
# diagnose-failure.sh
# Analyzes build logs to identify failure patterns and suggest remediation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERN_CONFIG="$SCRIPT_DIR/../config/failure-patterns.yaml"
LOG_FILE="${1:-}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ -z "$LOG_FILE" ]; then
  echo "Usage: $0 <log-file>"
  echo ""
  echo "Analyzes build failure logs and provides:"
  echo "  - Failure classification"
  echo "  - Severity assessment"
  echo "  - Remediation suggestions"
  echo "  - Auto-fix capability"
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo -e "${RED}Error: Log file not found: $LOG_FILE${NC}"
  exit 1
fi

echo -e "${BLUE}=== CI/CD Failure Diagnosis ===${NC}"
echo "Analyzing: $LOG_FILE"
echo ""

# Function to extract patterns from YAML (simplified)
# In production, use a proper YAML parser
extract_patterns() {
  grep -E "^\s+- name:" "$PATTERN_CONFIG" | sed 's/.*name: "\(.*\)".*/\1/' | head -20
}

# Function to get pattern details
get_pattern_details() {
  local pattern_name="$1"

  echo "SEVERITY:$(grep -A5 "name: \"$pattern_name\"" "$PATTERN_CONFIG" | grep "severity:" | sed 's/.*severity: "\(.*\)".*/\1/')"
  echo "CATEGORY:$(grep -A5 "name: \"$pattern_name\"" "$PATTERN_CONFIG" | grep "category:" | sed 's/.*category: "\(.*\)".*/\1/')"
  echo "AUTO_FIX:$(grep -A10 "name: \"$pattern_name\"" "$PATTERN_CONFIG" | grep "auto_fixable:" | sed 's/.*auto_fixable: \(.*\)/\1/' || echo "false")"
}

# Function to get remediation
get_remediation() {
  local pattern_name="$1"

  grep -A20 "name: \"$pattern_name\"" "$PATTERN_CONFIG" | grep -A100 "remediation:" | grep -B100 "^  [a-z]" | head -20
}

# Analyze log for patterns
echo -e "${BLUE}Scanning log file for failure patterns...${NC}"
echo ""

PATTERNS_TO_CHECK=(
  "OutOfMemoryError"
  "MetaspaceOutOfMemory"
  "NetworkTimeout"
  "ConnectionRefused"
  "DependencyResolutionFailed"
  "GradleDaemonStopped"
  "LockTimeoutException"
  "CompilationError"
  "KotlinNotNullAssertionError"
  "TestFailure"
  "SecretDetected"
  "DiskSpace"
  "PermissionDenied"
  "DockerImageNotFound"
)

FOUND_PATTERNS=()
FOUND_SEVERITIES=()

for pattern in "${PATTERNS_TO_CHECK[@]}"; do
  # Get regex for this pattern
  REGEX=$(grep -A2 "name: \"$pattern\"" "$PATTERN_CONFIG" | grep "regex:" | sed 's/.*regex: "\(.*\)".*/\1/' || echo "$pattern")

  # Check if pattern exists in log
  if grep -qiE "$REGEX" "$LOG_FILE"; then
    FOUND_PATTERNS+=("$pattern")

    # Get severity
    SEVERITY=$(get_pattern_details "$pattern" | grep "SEVERITY:" | cut -d: -f2)
    FOUND_SEVERITIES+=("$SEVERITY")

    # Get category
    CATEGORY=$(get_pattern_details "$pattern" | grep "CATEGORY:" | cut -d: -f2)

    # Get auto-fix status
    AUTO_FIX=$(get_pattern_details "$pattern" | grep "AUTO_FIX:" | cut -d: -f2)

    # Display finding
    case $SEVERITY in
      critical)
        COLOR=$RED
        ICON="🔴"
        ;;
      high)
        COLOR=$RED
        ICON="⚠️ "
        ;;
      medium)
        COLOR=$YELLOW
        ICON="⚡"
        ;;
      low)
        COLOR=$GREEN
        ICON="ℹ️ "
        ;;
      *)
        COLOR=$NC
        ICON="•"
        ;;
    esac

    echo -e "${COLOR}${ICON} Pattern: $pattern${NC}"
    echo "   Category: $CATEGORY"
    echo "   Severity: $SEVERITY"
    echo "   Auto-fixable: $AUTO_FIX"

    # Show matching line
    MATCHING_LINE=$(grep -iE "$REGEX" "$LOG_FILE" | head -1)
    echo "   Found: ${MATCHING_LINE:0:100}..."
    echo ""
  fi
done

# Summary
echo -e "${BLUE}=== Summary ===${NC}"

if [ ${#FOUND_PATTERNS[@]} -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No known failure patterns detected${NC}"
  echo "The failure may be:"
  echo "  - A new type of error"
  echo "  - Related to specific test failures"
  echo "  - Due to environmental issues"
  echo ""
  echo "Recommendation: Review the log manually for details"
else
  echo "Found ${#FOUND_PATTERNS[@]} known failure pattern(s):"
  echo ""

  # Count by severity
  CRITICAL_COUNT=$(echo "${FOUND_SEVERITIES[@]}" | grep -o "critical" | wc -l)
  HIGH_COUNT=$(echo "${FOUND_SEVERITIES[@]}" | grep -o "high" | wc -l)
  MEDIUM_COUNT=$(echo "${FOUND_SEVERITIES[@]}" | grep -o "medium" | wc -l)
  LOW_COUNT=$(echo "${FOUND_SEVERITIES[@]}" | grep -o "low" | wc -l)

  echo "  Critical: $CRITICAL_COUNT"
  echo "  High:     $HIGH_COUNT"
  echo "  Medium:   $MEDIUM_COUNT"
  echo "  Low:      $LOW_COUNT"
  echo ""

  # Detailed remediation for each found pattern
  echo -e "${BLUE}=== Remediation ===${NC}"
  echo ""

  for i in "${!FOUND_PATTERNS[@]}"; do
    PATTERN="${FOUND_PATTERNS[$i]}"
    SEVERITY="${FOUND_SEVERITIES[$i]}"

    # Color based on severity
    case $SEVERITY in
      critical|high)
        COLOR=$RED
        ;;
      medium)
        COLOR=$YELLOW
        ;;
      *)
        COLOR=$NC
        ;;
    esac

    echo -e "${COLOR}### $PATTERN${NC}"

    # Get and display remediation
    REMEDIATION=$(get_remediation "$PATTERN")
    if [ -n "$REMEDIATION" ]; then
      echo "$REMEDIATION" | sed 's/^/  /'
    else
      echo "  No specific remediation available"
      echo "  Review the log file for more details"
    fi
    echo ""
  done

  # Check if auto-fix is available
  echo -e "${BLUE}=== Auto-Fix Options ===${NC}"
  echo ""

  HAS_AUTO_FIX=false
  for i in "${!FOUND_PATTERNS[@]}"; do
    PATTERN="${FOUND_PATTERNS[$i]}"
    AUTO_FIX=$(get_pattern_details "$PATTERN" | grep "AUTO_FIX:" | cut -d: -f2)

    if [ "$AUTO_FIX" = "true" ]; then
      HAS_AUTO_FIX=true
      FIX_SCRIPT=$(grep -A10 "name: \"$PATTERN\"" "$PATTERN_CONFIG" | grep "auto_fix_script:" | sed 's/.*auto_fix_script: "\(.*\)".*/\1/')

      echo -e "${GREEN}✓ $PATTERN${NC}"
      echo "  Run: ./pipeline-utils/scripts/$FIX_SCRIPT"
    fi
  done

  if [ "$HAS_AUTO_FIX" = "false" ]; then
    echo "No automatic fixes available for these failures"
    echo "Manual intervention required"
  fi
fi

# Exit with appropriate code
if [[ " ${FOUND_SEVERITIES[@]} " =~ " critical " ]] || [[ " ${FOUND_SEVERITIES[@]} " =~ " high " ]]; then
  exit 1
elif [ ${#FOUND_PATTERNS[@]} -gt 0 ]; then
  exit 2
else
  exit 0
fi
