#!/bin/bash
# analyze-project-size.sh
# Analyzes project characteristics and recommends resource allocation

set -e

# Output colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Project Size Analysis ===${NC}"
echo ""

# Count lines of code (excluding build directories)
echo "Counting lines of code..."
LINES_OF_CODE=$(find . -name "*.kt" -o -name "*.java" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
echo "Total lines of Kotlin/Java code: $LINES_OF_CODE"
echo ""

# Count modules
echo "Analyzing project structure..."
MODULE_COUNT=$(find . -name "build.gradle.kts" -o -name "build.gradle" | wc -l)
echo "Gradle modules: $MODULE_COUNT"
echo ""

# Count source files
SOURCE_FILES=$(find . -name "*.kt" | wc -l)
echo "Kotlin source files: $SOURCE_FILES"
echo ""

# Count test files
TEST_FILES=$(find . -name "*Test.kt" -o -name "*Test.java" | wc -l)
echo "Test files: $TEST_FILES"
echo ""

# Count dependencies
if [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
  DEPENDENCY_COUNT=$(grep -E "^    (implementation|api|testImplementation)" build.gradle.kts 2>/dev/null | wc -l || echo "0")
  echo "Direct dependencies: $DEPENDENCY_COUNT"
  echo ""
fi

# Resource recommendations
echo -e "${BLUE}=== Resource Recommendations ===${NC}"
echo ""

# Determine project size category
if [ "$LINES_OF_CODE" -lt 5000 ]; then
  PROJECT_SIZE="small"
  RECOMMENDED_MEMORY="4GB"
  RECOMMENDED_CPU="2"
  EXPECTED_BUILD_TIME="2-4 minutes"
elif [ "$LINES_OF_CODE" -lt 25000 ]; then
  PROJECT_SIZE="medium"
  RECOMMENDED_MEMORY="6GB"
  RECOMMENDED_CPU="3"
  EXPECTED_BUILD_TIME="4-8 minutes"
elif [ "$LINES_OF_CODE" -lt 100000 ]; then
  PROJECT_SIZE="large"
  RECOMMENDED_MEMORY="8GB"
  RECOMMENDED_CPU="4"
  EXPECTED_BUILD_TIME="8-15 minutes"
else
  PROJECT_SIZE="very large"
  RECOMMENDED_MEMORY="12GB"
  RECOMMENDED_CPU="6"
  EXPECTED_BUILD_TIME="15-30 minutes"
fi

echo -e "${GREEN}Project Size Category:${NC} $PROJECT_SIZE"
echo -e "${GREEN}Recommended Memory:${NC} $RECOMMENDED_MEMORY"
echo -e "${GREEN}Recommended CPU:${NC} $RECOMMENDED_CPU cores"
echo -e "${GREEN}Expected Build Time:${NC} $EXPECTED_BUILD_TIME"
echo ""

# Output as YAML for easy parsing
if [ "$1" = "--yaml" ] || [ "$1" = "-y" ]; then
  echo ""
  echo "---"
  echo "# Resource Configuration"
  echo "resources:"
  echo "  memory: $RECOMMENDED_MEMORY"
  echo "  cpu: $RECOMMENDED_CPU"
  echo ""
  echo "pipeline:"
  echo "  max_parallel_builds: $RECOMMENDED_CPU"
  echo ""
  echo "project:"
  echo "  size: $PROJECT_SIZE"
  echo "  lines_of_code: $LINES_OF_CODE"
  echo "  modules: $MODULE_COUNT"
  echo "  test_files: $TEST_FILES"
fi

# Suggested .woodpecker.yml configuration
echo ""
echo -e "${BLUE}=== Suggested Pipeline Configuration ===${NC}"
echo ""

cat <<EOF
steps:
  build:
    image: android-ci:latest
    commands:
      - ./gradlew assembleDebug
    environment:
      GRADLE_OPTS: "-Xmx$(echo $RECOMMENDED_MEMORY | sed 's/GB/g/g') -XX:MaxMetaspaceSize=512m"
    resources:
      memory: $RECOMMENDED_MEMORY
      cpu: $RECOMMENDED_CPU

  test:
    image: android-ci:latest
    commands:
      - ./gradlew test
    resources:
      memory: $RECOMMENDED_MEMORY
      cpu: $RECOMMENDED_CPU
EOF

echo ""

# Gradle-specific recommendations
echo ""
echo -e "${BLUE}=== Gradle Configuration Recommendations ===${NC}"
echo ""

cat <<EOF
# Add to gradle.properties

# Optimize for CI environment
org.gradle.jvmargs=-Xmx$(echo $RECOMMENDED_MEMORY | sed 's/GB/g/g') -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true
org.gradle.vfs.watch=true

# Increase Kotlin daemon memory
kotlin.daemon.jvmargs=-Xmx2g
kotlin.incremental=true
kotlin.caching.enabled=true
EOF

echo ""

# Exit with 0
exit 0
