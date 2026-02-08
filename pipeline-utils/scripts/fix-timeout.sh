#!/bin/bash
# fix-timeout.sh
# Auto-fix script for network timeout issues

set -e

echo "🔧 Attempting to fix network timeout issue..."

# Increase Gradle timeout settings
export GRADLE_OPTS="-Dorg.gradle.daemon.idletimeout=600000"

# Create/update gradle.properties with timeout settings
if [ -f "gradle.properties" ]; then
  echo "Adding timeout settings to gradle.properties..."

  # Backup original
  cp gradle.properties gradle.properties.bak

  # Add timeout settings if not already present
  if ! grep -q "org.gradle.daemon.idletimeout" gradle.properties; then
    echo "" >> gradle.properties
    echo "# Increased timeout for network operations" >> gradle.properties
    echo "org.gradle.daemon.idletimeout=600000" >> gradle.properties
    echo "org.gradle.daemon.idletimeout=600000" >> gradle.properties
  fi

  echo "✅ Timeout settings added to gradle.properties"
else
  echo "⚠️  gradle.properties not found"
  echo "Creating gradle.properties with timeout settings..."

  cat > gradle.properties <<EOF
# Increased timeout for network operations
org.gradle.daemon.idletimeout=600000
org.gradle.daemon.idletimeout=600000
EOF

  echo "✅ Created gradle.properties with timeout settings"
fi

echo ""
echo "Network timeout fixes applied:"
echo "  - Gradle daemon idle timeout: 600 seconds (10 minutes)"
echo ""
echo "Retry your build with:"
echo "   ./gradlew <task> --refresh-dependencies"
