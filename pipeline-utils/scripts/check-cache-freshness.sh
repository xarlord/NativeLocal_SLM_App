#!/bin/bash
# check-cache-freshness.sh
# Checks if Gradle cache is fresh based on dependency changes
# Returns 0 if cache is fresh, 1 if stale

set -e

CACHE_DIR="${CACHE_DIR:-/cache/gradle}"
HASH_FILE="${CACHE_DIR}/.cache-hash"
PROJECT_DIR="${PROJECT_DIR:-.}"

echo "Checking Gradle cache freshness..."
echo "Cache directory: $CACHE_DIR"
echo "Project directory: $PROJECT_DIR"
echo ""

# Find dependency files
DEPS_FILES=""
if [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
  DEPS_FILES="$DEPS_FILES $PROJECT_DIR/build.gradle.kts"
fi
if [ -f "$PROJECT_DIR/settings.gradle.kts" ]; then
  DEPS_FILES="$DEPS_FILES $PROJECT_DIR/settings.gradle.kts"
fi
if [ -f "$PROJECT_DIR/build.gradle" ]; then
  DEPS_FILES="$DEPS_FILES $PROJECT_DIR/build.gradle"
fi
if [ -f "$PROJECT_DIR/settings.gradle" ]; then
  DEPS_FILES="$DEPS_FILES $PROJECT_DIR/settings.gradle"
fi

# Also check gradle wrapper properties
if [ -f "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.properties" ]; then
  DEPS_FILES="$DEPS_FILES $PROJECT_DIR/gradle/wrapper/gradle-wrapper.properties"
fi

if [ -z "$DEPS_FILES" ]; then
  echo "⚠️  No dependency files found"
  exit 0  # Consider cache fresh if no deps files
fi

echo "Dependency files to check:"
echo "$DEPS_FILES" | tr ' ' '\n' | sed 's/^/  - /'
echo ""

# Calculate current hash
CURRENT_HASH=""
for file in $DEPS_FILES; do
  if [ -f "$file" ]; then
    FILE_HASH=$(md5sum "$file" | awk '{print $1}')
    CURRENT_HASH="${CURRENT_HASH}${FILE_HASH}"
  fi
done

CURRENT_HASH=$(echo "$CURRENT_HASH" | md5sum | awk '{print $1}')
echo "Current dependency hash: $CURRENT_HASH"

# Get stored hash
if [ -f "$HASH_FILE" ]; then
  STORED_HASH=$(cat "$HASH_FILE")
  echo "Stored dependency hash: $STORED_HASH"
else
  echo "No stored hash found (first run)"
  STORED_HASH=""
fi

echo ""

# Compare hashes
if [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
  echo "✅ Cache is FRESH - dependencies unchanged"
  echo ""
  echo "Cache statistics:"
  if [ -d "$CACHE_DIR" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    CACHE_FILES=$(find "$CACHE_DIR" -type f | wc -l)
    echo "  Size: $CACHE_SIZE"
    echo "  Files: $CACHE_FILES"
  fi
  exit 0
else
  echo "⚠️  Cache is STALE - dependencies have changed"
  echo ""

  if [ -n "$STORED_HASH" ]; then
    echo "Action required:"
    echo "  1. Clear old cache: rm -rf $CACHE_DIR/*"
    echo "  2. Update hash: echo '$CURRENT_HASH' > $HASH_FILE"
    echo "  3. Rebuild with: ./gradlew build --refresh-dependencies"
  else
    echo "Action required:"
    echo "  1. Store current hash: echo '$CURRENT_HASH' > $HASH_FILE"
    echo "  2. Build with: ./gradlew build"
  fi

  echo ""
  echo "Would you like to invalidate the cache now? (yes/no)"
  read -r response

  if [ "$response" = "yes" ] || [ "$response" = "y" ]; then
    echo ""
    echo "Invalidating cache..."
    rm -rf "$CACHE_DIR"/*
    echo "$CURRENT_HASH" > "$HASH_FILE"
    echo "✅ Cache invalidated and hash updated"
  else
    echo "Cache not invalidated. Manual intervention required."
  fi

  exit 1
fi
