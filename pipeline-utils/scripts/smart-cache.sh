#!/bin/bash
# smart-cache.sh
# Implements cache warming, intelligent invalidation, and hit/miss tracking
#
# Usage: smart-cache.sh [command] [options]
# Commands:
#   warm         - Warm the cache by downloading dependencies
#   invalidate   - Invalidate cache based on dependency changes
#   status       - Show cache status and statistics
#   track        - Record cache hit/miss in database
#   analyze      - Analyze cache effectiveness

set -e

# Output colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CACHE_DIR="${CACHE_DIR:-/cache/gradle}"
PROJECT_DIR="${PROJECT_DIR:-.}"
HASH_FILE="${CACHE_DIR}/.cache-hash"
METADATA_FILE="${CACHE_DIR}/.cache-metadata"

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker_db_password_change_me}"

# Build metadata
BUILD_ID="${CI_BUILD_ID:-0}"
COMMIT_SHA="${CI_COMMIT_SHA:-unknown}"
PIPELINE_ID="${CI_PIPELINE_ID:-0}"

# Function to print usage
usage() {
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  warm                    - Warm the cache by downloading dependencies"
  echo "  invalidate              - Invalidate cache based on dependency changes"
  echo "  status                  - Show cache status and statistics"
  echo "  track [hit|miss]        - Record cache hit/miss in database"
  echo "  analyze                 - Analyze cache effectiveness from database"
  echo ""
  echo "Options:"
  echo "  --force                 - Force operation (skip checks)"
  echo "  --verbose               - Verbose output"
  echo ""
  echo "Environment Variables:"
  echo "  CACHE_DIR              - Cache directory (default: /cache/gradle)"
  echo "  PROJECT_DIR            - Project directory (default: .)"
  echo "  DB_HOST, DB_PORT,      - Database connection"
  echo "  DB_NAME, DB_USER,      - "
  echo "  DB_PASSWORD            - "
  echo ""
  exit 1
}

# Function to calculate dependency hash
calculate_hash() {
  local hash=""

  # Gradle files
  for file in build.gradle.kts settings.gradle.kts build.gradle settings.gradle gradle.properties; do
    if [ -f "$PROJECT_DIR/$file" ]; then
      FILE_HASH=$(md5sum "$PROJECT_DIR/$file" 2>/dev/null | awk '{print $1}')
      hash="${hash}${FILE_HASH}"
    fi
  done

  # Check all module gradle files
  while IFS= read -r -d '' file; do
    FILE_HASH=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
    hash="${hash}${FILE_HASH}"
  done < <(find "$PROJECT_DIR" -name "build.gradle.kts" -print0 2>/dev/null)

  # Gradle wrapper
  if [ -f "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.properties" ]; then
    FILE_HASH=$(md5sum "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.properties" 2>/dev/null | awk '{print $1}')
    hash="${hash}${FILE_HASH}"
  fi

  # Generate final hash
  echo "$hash" | md5sum | awk '{print $1}'
}

# Function to get dependency list
get_dependencies() {
  cd "$PROJECT_DIR"

  # Try to get dependencies from Gradle
  if [ -f "./gradlew" ]; then
    ./gradlew dependencies --write-locks 2>/dev/null || true
  fi
}

# Function to warm cache
warm_cache() {
  echo -e "${BLUE}=== Cache Warming ===${NC}"
  echo "Cache directory: $CACHE_DIR"
  echo "Project directory: $PROJECT_DIR"
  echo ""

  # Create cache directory if it doesn't exist
  mkdir -p "$CACHE_DIR"

  echo -e "${YELLOW}Step 1: Analyzing dependencies...${NC}"
  get_dependencies

  echo ""
  echo -e "${YELLOW}Step 2: Downloading dependencies...${NC}"
  cd "$PROJECT_DIR"

  # Download dependencies without building
  if [ -f "./gradlew" ]; then
    ./gradlew dependencies --refresh-dependencies 2>&1 | grep -E "Download|Downloading" || true
  fi

  echo ""
  echo -e "${YELLOW}Step 3: Building with cache...${NC}"

  # Build to populate caches
  if [ -f "./gradlew" ]; then
    ./gradlew assembleDebug --build-cache --dry-run 2>/dev/null || true
  fi

  # Calculate and store hash
  CURRENT_HASH=$(calculate_hash)
  echo "$CURRENT_HASH" > "$HASH_FILE"

  # Store metadata
  cat > "$METADATA_FILE" <<EOF
cache_version: 1.0
dependency_hash: $CURRENT_HASH
created: $(date -Iseconds)
commit: $COMMIT_SHA
build_id: $BUILD_ID
project_dir: $PROJECT_DIR
EOF

  echo ""
  echo -e "${GREEN}✅ Cache warmed successfully${NC}"
  echo "Dependency hash: $CURRENT_HASH"

  # Get cache size
  if [ -d "$CACHE_DIR" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    CACHE_FILES=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
    echo "Cache size: $CACHE_SIZE"
    echo "Cache files: $CACHE_FILES"
  fi

  echo ""
}

# Function to invalidate cache
invalidate_cache() {
  echo -e "${BLUE}=== Cache Invalidation ===${NC}"
  echo "Cache directory: $CACHE_DIR"
  echo "Project directory: $PROJECT_DIR"
  echo ""

  # Calculate current hash
  CURRENT_HASH=$(calculate_hash)
  echo "Current dependency hash: $CURRENT_HASH"

  # Get stored hash
  STORED_HASH=""
  if [ -f "$HASH_FILE" ]; then
    STORED_HASH=$(cat "$HASH_FILE")
    echo "Stored dependency hash: $STORED_HASH"
  else
    echo "No stored hash found (first run)"
  fi

  echo ""

  # Compare hashes
  if [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
    if [ "$1" != "--force" ]; then
      echo -e "${GREEN}✅ Cache is valid - dependencies unchanged${NC}"

      # Show metadata if available
      if [ -f "$METADATA_FILE" ]; then
        echo ""
        echo "Cache metadata:"
        cat "$METADATA_FILE" | sed 's/^/  /'
      fi

      echo ""
      exit 0
    else
      echo -e "${YELLOW}⚠️  Forced invalidation requested${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️  Dependencies changed - cache invalid${NC}"
  fi

  echo ""
  echo -e "${YELLOW}Finding changed dependency files...${NC}"

  # Show which files changed
  CHANGED_FILES=""
  for file in build.gradle.kts settings.gradle.kts build.gradle settings.gradle; do
    if [ -f "$PROJECT_DIR/$file" ]; then
      echo "  - $file"
    fi
  done

  # Find module gradle files
  find "$PROJECT_DIR" -name "build.gradle.kts" -printf "  - %p\n" 2>/dev/null || true

  echo ""
  echo -e "${YELLOW}Invalidating cache...${NC}"

  # Clear cache
  rm -rf "$CACHE_DIR"/*
  rm -f "$HASH_FILE"
  rm -f "$METADATA_FILE"

  # Update hash
  echo "$CURRENT_HASH" > "$HASH_FILE"

  echo -e "${GREEN}✅ Cache invalidated${NC}"
  echo ""
  echo "Next build will rebuild the cache automatically."
  echo ""
}

# Function to show cache status
show_status() {
  echo -e "${BLUE}=== Cache Status ===${NC}"
  echo "Cache directory: $CACHE_DIR"
  echo ""

  # Check if cache exists
  if [ ! -d "$CACHE_DIR" ]; then
    echo -e "${RED}❌ Cache directory does not exist${NC}"
    echo "Run 'warm' command to create cache"
    exit 1
  fi

  # Calculate current hash
  CURRENT_HASH=$(calculate_hash)

  # Get stored hash
  STORED_HASH=""
  if [ -f "$HASH_FILE" ]; then
    STORED_HASH=$(cat "$HASH_FILE")
  fi

  # Compare
  echo "Dependency Hash:"
  if [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
    echo -e "  ${GREEN}✅ VALID${NC} - $CURRENT_HASH"
  else
    echo -e "  ${RED}❌ INVALID${NC}"
    echo "    Current:  $CURRENT_HASH"
    echo "    Stored:   ${STORED_HASH:-none}"
  fi

  echo ""

  # Show cache size
  CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
  CACHE_FILES=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
  CACHE_DIRS=$(find "$CACHE_DIR" -type d 2>/dev/null | wc -l)

  echo "Cache Statistics:"
  echo "  Size: $CACHE_SIZE"
  echo "  Files: $CACHE_FILES"
  echo "  Directories: $CACHE_DIRS"
  echo ""

  # Show metadata
  if [ -f "$METADATA_FILE" ]; then
    echo "Cache Metadata:"
    cat "$METADATA_FILE" | sed 's/^/  /'
  else
    echo "No metadata found"
  fi

  echo ""

  # Show top cache directories
  echo "Top Cache Directories:"
  du -sh "$CACHE_DIR"/* 2>/dev/null | sort -hr | head -10 | sed 's/^/  /'
  echo ""
}

# Function to track cache hit/miss
track_cache() {
  local event_type="$1"

  if [ -z "$event_type" ]; then
    echo -e "${RED}Error: Missing event type${NC}"
    echo "Usage: $0 track [hit|miss]"
    exit 1
  fi

  if [ "$event_type" != "hit" ] && [ "$event_type" != "miss" ]; then
    echo -e "${RED}Error: Invalid event type '$event_type'${NC}"
    echo "Must be 'hit' or 'miss'"
    exit 1
  fi

  # Check if psql is available
  if ! command -v psql &> /dev/null; then
    echo -e "${YELLOW}⚠️  psql not available - skipping database tracking${NC}"
    exit 0
  fi

  # Set PGPASSWORD to avoid prompt
  export PGPASSWORD="$DB_PASSWORD"

  echo -e "${BLUE}=== Tracking Cache ${event_type^^} ===${NC}"
  echo "Build ID: $BUILD_ID"
  echo "Commit: $COMMIT_SHA"
  echo ""

  # Get current hash
  CURRENT_HASH=$(calculate_hash)

  # Insert cache metrics
  QUERY="
INSERT INTO build_metrics (
  build_id,
  pipeline_id,
  commit_sha,
  success,
  duration_seconds
) VALUES (
  $BUILD_ID,
  $PIPELINE_ID,
  '$COMMIT_SHA',
  TRUE,
  0
) ON CONFLICT (build_id, commit_sha) DO NOTHING;
"

  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$QUERY" > /dev/null 2>&1

  # Store cache event in a simple log for now
  CACHE_LOG="$CACHE_DIR/.cache-events.log"
  mkdir -p "$(dirname "$CACHE_LOG")"

  echo "$(date -Iseconds) | $event_type | $BUILD_ID | $COMMIT_SHA | $CURRENT_HASH" >> "$CACHE_LOG"

  echo -e "${GREEN}✅ Cache ${event_type} tracked${NC}"
  echo ""
}

# Function to analyze cache effectiveness
analyze_cache() {
  echo -e "${BLUE}=== Cache Effectiveness Analysis ===${NC}"
  echo ""

  # Check if psql is available
  if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql is not installed${NC}"
    exit 1
  fi

  # Set PGPASSWORD to avoid prompt
  export PGPASSWORD="$DB_PASSWORD"

  # Query build metrics for cache analysis
  QUERY="
SELECT
  COUNT(*) as total_builds,
  AVG(duration_seconds) as avg_duration,
  MIN(duration_seconds) as min_duration,
  MAX(duration_seconds) as max_duration
FROM build_metrics
WHERE timestamp > NOW() - INTERVAL '30 days'
  AND success = true;
"

  RESULTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$QUERY" 2>&1)

  if [ $? -ne 0 ]; then
    echo -e "${RED}Error querying database:${NC}"
    echo "$RESULTS"
    exit 1
  fi

  TOTAL_BUILDS=$(echo "$RESULTS" | awk 'NR==1 {print $1}' | sed 's/[^0-9.]//g')
  AVG_DURATION=$(echo "$RESULTS" | awk 'NR==1 {print $2}' | sed 's/[^0-9.]//g')
  MIN_DURATION=$(echo "$RESULTS" | awk 'NR==1 {print $3}' | sed 's/[^0-9.]//g')
  MAX_DURATION=$(echo "$RESULTS" | awk 'NR==1 {print $4}' | sed 's/[^0-9.]//g')

  echo "Build Performance (last 30 days):"
  echo "  Total builds: ${TOTAL_BUILDS:-0}"
  echo "  Avg duration: ${AVG_DURATION:-0}s"
  echo "  Min duration: ${MIN_DURATION:-0}s"
  echo "  Max duration: ${MAX_DURATION:-0}s"
  echo ""

  # Analyze cache log if it exists
  CACHE_LOG="$CACHE_DIR/.cache-events.log"
  if [ -f "$CACHE_LOG" ]; then
    echo "Cache Hit/Miss Statistics:"
    HITS=$(grep -c " hit " "$CACHE_LOG" 2>/dev/null || echo "0")
    MISSES=$(grep -c " miss " "$CACHE_LOG" 2>/dev/null || echo "0")
    TOTAL_EVENTS=$((HITS + MISSES))

    if [ $TOTAL_EVENTS -gt 0 ]; then
      HIT_RATE=$(echo "scale=2; $HITS * 100 / $TOTAL_EVENTS" | bc 2>/dev/null || echo "0")
      echo "  Total events: $TOTAL_EVENTS"
      echo "  Hits: $HITS"
      echo "  Misses: $MISSES"
      echo "  Hit rate: ${HIT_RATE}%"
      echo ""

      # Calculate time savings
      # Assume cache hit saves ~30% of build time
      TIME_SAVED=$(echo "scale=0; $HITS * ${AVG_DURATION:-0} * 0.3" | bc 2>/dev/null || echo "0")
      echo "  Estimated time saved: ${TIME_SAVED}s"

      if [ $(echo "$HIT_RATE > 70" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo -e "  ${GREEN}✅ Excellent hit rate!${NC}"
      elif [ $(echo "$HIT_RATE > 50" | bc 2>/dev/null || echo "0") -eq 1 ]; then
        echo -e "  ${YELLOW}⚠️  Good hit rate, room for improvement${NC}"
      else
        echo -e "  ${RED}❌ Low hit rate - consider cache warming strategy${NC}"
      fi
    fi
    echo ""

    # Show recent events
    echo "Recent Cache Events:"
    tail -10 "$CACHE_LOG" | sed 's/^/  /'
    echo ""
  else
    echo "No cache event log found"
    echo ""
  fi

  echo -e "${BLUE}=== Recommendations ===${NC}"
  echo ""

  if [ -f "$CACHE_LOG" ]; then
    if [ $TOTAL_EVENTS -gt 0 ] && [ $(echo "$HIT_RATE < 50" | bc 2>/dev/null || echo "0") -eq 1 ]; then
      echo -e "${YELLOW}⚠️  Low cache hit rate detected${NC}"
      echo ""
      echo "Recommendations:"
      echo "  1. Set up scheduled cache warming pipeline"
      echo "  2. Warm caches before major builds"
      echo "  3. Check if dependencies change too frequently"
      echo "  4. Consider using fixed dependency versions"
      echo ""
    fi
  fi

  if [ $TOTAL_BUILDS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No build metrics found in database${NC}"
    echo "Run builds with tracking enabled to collect data"
    echo ""
  fi
}

# Main script logic
case "${1:-}" in
  warm)
    warm_cache
    ;;
  invalidate)
    invalidate_cache "$2"
    ;;
  status)
    show_status
    ;;
  track)
    track_cache "$2"
    ;;
  analyze)
    analyze_cache
    ;;
  --help|-h|"")
    usage
    ;;
  *)
    echo -e "${RED}Error: Unknown command '$1'${NC}"
    echo ""
    usage
    ;;
esac

exit 0
