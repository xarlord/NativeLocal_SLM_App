#!/bin/bash
# fix-dependencies.sh
# Auto-fix script for dependency resolution failures

set -e

echo "🔧 Attempting to fix dependency resolution issue..."

cd simpleGame 2>/dev/null || true

# Option 1: Clean build cache
echo "Option 1: Cleaning Gradle cache..."
rm -rf /cache/gradle/caches/*.lock
rm -rf /cache/gradle/caches/modules-2/metadata-*/descriptors.lock 2>/dev/null || true

# Option 2: Refresh dependencies
echo ""
echo "Option 2: Refreshing dependencies..."
./gradlew --refresh-dependencies --no-daemon || {
  echo "Warning: Refresh failed, trying full clean..."

  # Option 3: Full clean
  echo ""
  echo "Option 3: Performing full clean..."
  ./gradlew clean --no-daemon

  # Clear more cache
  rm -rf /cache/gradle/caches/

  echo "Cache cleared"
}

# Option 4: Check repository configuration
echo ""
echo "Checking repository configuration..."
if [ -f "build.gradle.kts" ]; then
  echo "✅ build.gradle.kts found"

  # Check for common repository issues
  if ! grep -q "mavenCentral()" build.gradle.kts && ! grep -q "mavenCentral()" build.gradle.kts; then
    echo "⚠️  mavenCentral() not found in repositories"
  fi

  if ! grep -q "google()" build.gradle.kts && ! grep -q "google()" build.gradle.kts; then
    echo "⚠️  google() not found in repositories"
  fi
fi

# Option 5: Verify network connectivity
echo ""
echo "Checking network connectivity..."
if command -v curl &> /dev/null; then
  if curl -s -o /dev/null -w "%{http_code}" https://repo1.maven.org/maven2/ | grep -q "200\|301\|302"; then
    echo "✅ Maven Central is reachable"
  else
    echo "❌ Cannot reach Maven Central"
    echo "Check your network connection or proxy settings"
  fi
fi

echo ""
echo "✅ Dependency fixes applied"
echo ""
echo "Next steps:"
echo "  1. Retry your build: ./gradlew build"
echo "  2. If still failing, check build.gradle.kts repository configuration"
echo "  3. Consider using a dependency mirror if network issues persist"
