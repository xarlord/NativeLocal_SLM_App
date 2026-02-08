#!/bin/bash
# adapt-resources.sh
# Analyzes project metrics from database and recommends optimal memory/CPU allocation
# Generates YAML configuration for pipeline
#
# Usage: adapt-resources.sh [--project=NAME] [--branch=BRANCH] [--output=FILE]

set -e

# Output colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker_db_password_change_me}"

# Parse arguments
PROJECT_NAME=""
BRANCH_NAME="main"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project=*)
      PROJECT_NAME="${1#*=}"
      shift
      ;;
    --branch=*)
      BRANCH_NAME="${1#*=}"
      shift
      ;;
    --output=*)
      OUTPUT_FILE="${1#*=}"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--project=NAME] [--branch=BRANCH] [--output=FILE]"
      echo ""
      echo "Analyzes project metrics and recommends optimal resource allocation"
      echo ""
      echo "Options:"
      echo "  --project=NAME    Project name filter"
      echo "  --branch=BRANCH   Branch name (default: main)"
      echo "  --output=FILE     Write YAML config to file"
      echo ""
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}=== Adaptive Resource Allocation Analysis ===${NC}"
echo ""
echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"
echo "Branch: $BRANCH_NAME"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
  echo -e "${RED}Error: psql is not installed${NC}"
  echo "Install PostgreSQL client to use this script"
  exit 1
fi

# Set PGPASSWORD to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Query recent build metrics
echo -e "${BLUE}Querying build metrics...${NC}"

METRICS_QUERY="
SELECT
  AVG(duration_seconds) as avg_duration,
  AVG(memory_gb) as avg_memory,
  AVG(cpu_cores) as avg_cpu,
  MAX(memory_gb) as max_memory,
  MAX(duration_seconds) as max_duration,
  COUNT(*) as build_count,
  AVG(code_coverage) as avg_coverage,
  SUM(test_count) as total_tests
FROM build_metrics
WHERE branch = '$BRANCH_NAME'
  AND timestamp > NOW() - INTERVAL '30 days'
  AND success = true;
"

METRICS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$METRICS_QUERY" 2>&1)

if [ $? -ne 0 ]; then
  echo -e "${RED}Error querying database:${NC}"
  echo "$METRICS"
  exit 1
fi

# Parse metrics
AVG_DURATION=$(echo "$METRICS" | awk 'NR==1 {print $1}' | sed 's/[^0-9.]//g')
AVG_MEMORY=$(echo "$METRICS" | awk 'NR==1 {print $2}' | sed 's/[^0-9.]//g')
AVG_CPU=$(echo "$METRICS" | awk 'NR==1 {print $3}' | sed 's/[^0-9.]//g')
MAX_MEMORY=$(echo "$METRICS" | awk 'NR==1 {print $4}' | sed 's/[^0-9.]//g')
MAX_DURATION=$(echo "$METRICS" | awk 'NR==1 {print $5}' | sed 's/[^0-9.]//g')
BUILD_COUNT=$(echo "$METRICS" | awk 'NR==1 {print $6}' | sed 's/[^0-9.]//g')
AVG_COVERAGE=$(echo "$METRICS" | awk 'NR==1 {print $7}' | sed 's/[^0-9.]//g')
TOTAL_TESTS=$(echo "$METRICS" | awk 'NR==1 {print $8}' | sed 's/[^0-9.]//g')

# Handle NULL values
AVG_DURATION=${AVG_DURATION:-0}
AVG_MEMORY=${AVG_MEMORY:-0}
AVG_CPU=${AVG_CPU:-0}
MAX_MEMORY=${MAX_MEMORY:-0}
MAX_DURATION=${MAX_DURATION:-0}
BUILD_COUNT=${BUILD_COUNT:-0}
AVG_COVERAGE=${AVG_COVERAGE:-0}
TOTAL_TESTS=${TOTAL_TESTS:-0}

echo "Recent builds (last 30 days): $BUILD_COUNT"
echo "Average duration: ${AVG_DURATION}s"
echo "Average memory used: ${AVG_MEMORY}GB"
echo "Max memory used: ${MAX_MEMORY}GB"
echo "Average CPU cores: ${AVG_CPU}"
echo "Average coverage: ${AVG_COVERAGE}%"
echo "Total tests: ${TOTAL_TESTS}"
echo ""

# Query resource usage history
echo -e "${BLUE}Querying resource efficiency...${NC}"

EFFICIENCY_QUERY="
SELECT
  AVG(memory_efficiency) as avg_mem_efficiency,
  AVG(cpu_efficiency) as avg_cpu_efficiency,
  AVG(peak_memory_gb) as avg_peak_memory,
  AVG(allocated_memory_gb) as avg_allocated_memory,
  AVG(lines_of_code) as avg_loc,
  AVG(module_count) as avg_modules
FROM resource_usage
WHERE timestamp > NOW() - INTERVAL '30 days';
"

EFFICIENCY=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$EFFICIENCY_QUERY" 2>&1)

if [ $? -eq 0 ]; then
  AVG_MEM_EFFICIENCY=$(echo "$EFFICIENCY" | awk 'NR==1 {print $1}' | sed 's/[^0-9.]//g')
  AVG_CPU_EFFICIENCY=$(echo "$EFFICIENCY" | awk 'NR==1 {print $2}' | sed 's/[^0-9.]//g')
  AVG_PEAK_MEMORY=$(echo "$EFFICIENCY" | awk 'NR==1 {print $3}' | sed 's/[^0-9.]//g')
  AVG_ALLOCATED=$(echo "$EFFICIENCY" | awk 'NR==1 {print $4}' | sed 's/[^0-9.]//g')
  AVG_LOC=$(echo "$EFFICIENCY" | awk 'NR==1 {print $5}' | sed 's/[^0-9.]//g')
  AVG_MODULES=$(echo "$EFFICIENCY" | awk 'NR==1 {print $6}' | sed 's/[^0-9.]//g')

  # Handle NULL values
  AVG_MEM_EFFICIENCY=${AVG_MEM_EFFICIENCY:-0}
  AVG_CPU_EFFICIENCY=${AVG_CPU_EFFICIENCY:-0}
  AVG_PEAK_MEMORY=${AVG_PEAK_MEMORY:-0}
  AVG_ALLOCATED=${AVG_ALLOCATED:-0}
  AVG_LOC=${AVG_LOC:-0}
  AVG_MODULES=${AVG_MODULES:-0}

  echo "Memory efficiency: ${AVG_MEM_EFFICIENCY}%"
  echo "CPU efficiency: ${AVG_CPU_EFFICIENCY}%"
  echo "Peak memory: ${AVG_PEAK_MEMORY}GB"
  echo "Allocated memory: ${AVG_ALLOCATED}GB"
  echo "Lines of code: ${AVG_LOC}"
  echo "Modules: ${AVG_MODULES}"
  echo ""
fi

# Analyze failure patterns
echo -e "${BLUE}Analyzing failure patterns...${NC}"

FAILURE_QUERY="
SELECT
  pattern_type,
  COUNT(*) as count,
  severity
FROM failure_patterns
WHERE last_seen > NOW() - INTERVAL '30 days'
GROUP BY pattern_type, severity
ORDER BY count DESC
LIMIT 5;
"

FAILURES=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$FAILURE_QUERY" 2>&1)

if [ $? -eq 0 ]; then
  echo "Top failure patterns:"
  echo "$FAILURES" | while read -r pattern count severity; do
    if [ -n "$pattern" ]; then
      echo "  - $pattern: $count occurrences ($severity)"
    fi
  done
  echo ""
fi

# Calculate optimal resources based on data
echo -e "${BLUE}=== Resource Recommendations ===${NC}"
echo ""

# Start with historical data or defaults
if [ "$BUILD_COUNT" -gt 0 ]; then
  # We have historical data
  RECOMMENDED_MEMORY=$(echo "$MAX_MEMORY * 1.2" | bc 2>/dev/null || echo "$MAX_MEMORY")
  RECOMMENDED_MEMORY=$(printf "%.0f" "$RECOMMENDED_MEMORY")
  if [ "$RECOMMENDED_MEMORY" -lt 4 ]; then
    RECOMMENDED_MEMORY=4
  fi

  RECOMMENDED_CPU=$(printf "%.0f" "$AVG_CPU")
  if [ "$RECOMMENDED_CPU" -lt 2 ]; then
    RECOMMENDED_CPU=2
  fi
else
  # No historical data, use defaults
  RECOMMENDED_MEMORY=6
  RECOMMENDED_CPU=3
fi

# Adjust based on efficiency
if [ "$AVG_MEM_EFFICIENCY" != "0" ]; then
  EFFICIENCY_CHECK=$(echo "$AVG_MEM_EFFICIENCY < 0.6" | bc 2>/dev/null || echo "0")
  if [ "$EFFICIENCY_CHECK" = "1" ]; then
    echo -e "${YELLOW}⚠️  Low memory efficiency detected (${AVG_MEM_EFFICIENCY}%)${NC}"
    echo "   Current allocation may be too high. Consider reducing memory."
    ADJUSTED_MEMORY=$(echo "$AVG_PEAK_MEMORY * 1.3" | bc 2>/dev/null || echo "$RECOMMENDED_MEMORY")
    ADJUSTED_MEMORY=$(printf "%.0f" "$ADJUSTED_MEMORY")
    if [ "$ADJUSTED_MEMORY" -ge 2 ]; then
      RECOMMENDED_MEMORY=$ADJUSTED_MEMORY
    fi
  fi
fi

# Adjust based on project size
if [ "$AVG_LOC" != "0" ]; then
  if [ "$AVG_LOC" -lt 5000 ]; then
    if [ "$RECOMMENDED_MEMORY" -gt 4 ]; then
      RECOMMENDED_MEMORY=4
    fi
    if [ "$RECOMMENDED_CPU" -gt 2 ]; then
      RECOMMENDED_CPU=2
    fi
  elif [ "$AVG_LOC" -gt 100000 ]; then
    if [ "$RECOMMENDED_MEMORY" -lt 8 ]; then
      RECOMMENDED_MEMORY=8
    fi
    if [ "$RECOMMENDED_CPU" -lt 4 ]; then
      RECOMMENDED_CPU=4
    fi
  fi
fi

# Check for OOM failures
OOM_CHECK=$(echo "$FAILURES" | grep -i "OutOfMemory" | wc -l)
if [ "$OOM_CHECK" -gt 0 ]; then
  echo -e "${RED}⚠️  OutOfMemory errors detected in recent builds${NC}"
  INCREASED_MEMORY=$((RECOMMENDED_MEMORY + 2))
  echo "   Increasing memory allocation: ${RECOMMENDED_MEMORY}GB -> ${INCREASED_MEMORY}GB"
  RECOMMENDED_MEMORY=$INCREASED_MEMORY
fi

echo -e "${GREEN}Recommended Configuration:${NC}"
echo "  Memory: ${RECOMMENDED_MEMORY}GB"
echo "  CPU: ${RECOMMENDED_CPU} cores"
echo ""

# Generate Gradle JVM args
JVM_HEAP=$(echo "$RECOMMENDED_MEMORY * 0.7" | bc 2>/dev/null || echo "4")
JVM_HEAP=$(printf "%.0f" "$JVM_HEAP")
GRADLE_OPTS="-Xmx${JVM_HEAP}g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError"

echo "Gradle Options:"
echo "  GRADLE_OPTS: $GRADLE_OPTS"
echo ""

# Generate YAML configuration
YAML_CONFIG="# Woodpecker CI Resource Configuration
# Generated by adapt-resources.sh on $(date)
# Based on analysis of $BUILD_COUNT builds over the last 30 days

pipeline:
  resources:
    memory: ${RECOMMENDED_MEMORY}GB
    cpu: ${RECOMMENDED_CPU}

steps:
  build:
    image: android-ci:latest
    commands:
      - export GRADLE_OPTS=\"$GRADLE_OPTS\"
      - ./gradlew assembleDebug --no-daemon
    resources:
      memory: ${RECOMMENDED_MEMORY}GB
      cpu: ${RECOMMENDED_CPU}

  test:
    image: android-ci:latest
    commands:
      - export GRADLE_OPTS=\"$GRADLE_OPTS\"
      - ./gradlew test --no-daemon
    resources:
      memory: ${RECOMMENDED_MEMORY}GB
      cpu: ${RECOMMENDED_CPU}

# Performance Notes:
# - Average build duration: ${AVG_DURATION}s
# - Average coverage: ${AVG_COVERAGE}%
# - Memory efficiency: ${AVG_MEM_EFFICIENCY}%
# - Test count: ${TOTAL_TESTS}
"

# Output YAML
echo -e "${BLUE}=== Generated Configuration ===${NC}"
echo ""
echo "$YAML_CONFIG"

# Write to file if requested
if [ -n "$OUTPUT_FILE" ]; then
  echo "$YAML_CONFIG" > "$OUTPUT_FILE"
  echo ""
  echo -e "${GREEN}✅ Configuration written to: $OUTPUT_FILE${NC}"
fi

# Record recommendation in database
echo ""
echo -e "${BLUE}Recording recommendation in database...${NC}"

INSERT_QUERY="
INSERT INTO resource_usage (allocated_memory_gb, allocated_cpu_cores, lines_of_code, module_count, test_count)
VALUES ($RECOMMENDED_MEMORY, $RECOMMENDED_CPU, ${AVG_LOC:-0}, ${AVG_MODULES:-0}, ${TOTAL_TESTS:-0});
"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$INSERT_QUERY" > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Recommendation recorded in database${NC}"
else
  echo -e "${YELLOW}⚠️  Could not record recommendation (this is okay)${NC}"
fi

echo ""
echo -e "${GREEN}=== Analysis Complete ===${NC}"
echo ""
echo "To apply these recommendations:"
echo "1. Update your .woodpecker.yml with the generated configuration"
echo "2. Monitor build performance"
echo "3. Re-run this script periodically to optimize"
echo ""

exit 0
