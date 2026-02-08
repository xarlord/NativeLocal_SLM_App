#!/bin/bash
# fix-lock.sh
# Auto-fix script for Gradle lock timeout issues

set -e

echo "🔧 Attempting to fix Gradle lock timeout..."

# Stop all Gradle daemons
echo "Stopping all Gradle daemons..."
./gradlew --stop 2>/dev/null || echo "No daemons running"

# Remove lock files from cache
echo "Removing lock files..."
find /cache/gradle -name "*.lock" -type f -delete 2>/dev/null || true

# Remove lock files from project
echo "Removing lock files from project..."
find . -name "*.lock" -type f -delete 2>/dev/null || true
find . -name ".lock" -type f -delete 2>/dev/null || true

# Remove .gradle directory with lock files
if [ -d ".gradle" ]; then
  echo "Clearing .gradle directory..."
  rm -rf .gradle/
fi

echo ""
echo "✅ Lock files removed"
echo ""
echo "Waiting 2 seconds before retry..."
sleep 2

echo ""
echo "You can now retry your build:"
echo "   ./gradlew <task>"
