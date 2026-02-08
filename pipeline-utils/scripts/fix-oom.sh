#!/bin/bash
# fix-oom.sh
# Auto-fix script for OutOfMemoryError issues

set -e

echo "🔧 Attempting to fix OutOfMemoryError issue..."

# Check current Gradle memory settings
echo "Current GRADLE_OPTS: ${GRADLE_OPTS:-<not set>}"

# Calculate new memory settings
# Get available system memory (in GB)
if [ -f /proc/meminfo ]; then
  MEMtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEMtotal_gb=$((MEMtotal / 1024 / 1024))
else
  MEMtotal_gb=8  # Default to 8GB
fi

# Use 60% of available memory, max 8GB
SUGGESTED_MEMORY=$((MEMtotal_gb * 60 / 100))
if [ $SUGGESTED_MEMORY -gt 8 ]; then
  SUGGESTED_MEMORY=8
fi

echo "Suggested memory allocation: ${SUGGESTED_MEMORY}g"

# Set new environment variables
export GRADLE_OPTS="-Xmx${SUGGESTED_MEMORY}g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError"
export JAVA_OPTS="-Xmx${SUGGESTED_MEMORY}g"

echo ""
echo "✅ Updated memory settings:"
echo "   GRADLE_OPTS=$GRADLE_OPTS"
echo "   JAVA_OPTS=$JAVA_OPTS"
echo ""
echo "You can now retry your build with:"
echo "   ./gradlew <task>"
