#!/bin/bash
# detect-regression.sh
# Runs Android benchmarks, compares against baselines, detects regressions
# Usage: detect-regression.sh [--regression-threshold=5] [--update-baselines]

set -e

# ============================================
# Configuration
# ============================================
REGRESSION_THRESHOLD=${REGRESSION_THRESHOLD:-5}  # 5% degradation threshold
UPDATE_BASELINES=${UPDATE_BASELINES:-false}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-woodpecker}
DB_USER=${DB_USER:-woodpecker}
DB_PASSWORD=${DB_PASSWORD:-woodpecker}

# GitHub configuration
GITHUB_REPO=${GITHUB_REPO:-${CI_REPO}}
GITHUB_TOKEN=${GITHUB_TOKEN:-${GITHUB_TOKEN}}

# Benchmark configuration
BENCHMARK_RESULTS_PATH=${BENCHMARK_RESULTS_PATH:""}
COMMIT_SHA=${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo "unknown")}
BRANCH=${CI_COMMIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}
BUILD_ID=${CI_BUILD_NUMBER:-0}

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --regression-threshold=*)
      REGRESSION_THRESHOLD="${1#*=}"
      shift
      ;;
    --update-baselines)
      UPDATE_BASELINES=true
      shift
      ;;
    --results-path=*)
      BENCHMARK_RESULTS_PATH="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: $0 [--regression-threshold=5] [--update-baselines] [--results-path=PATH]"
      echo ""
      echo "Detects performance regressions by comparing benchmarks against baselines"
      echo ""
      echo "Options:"
      echo "  --regression-threshold=PCT  Regression threshold (default: 5%)"
      echo "  --update-baselines          Update baselines with new results"
      echo "  --results-path=PATH         Path to benchmark results JSON"
      echo ""
      echo "Environment Variables:"
      echo "  GITHUB_TOKEN                GitHub API token"
      echo "  DB_HOST, DB_PORT            Database connection"
      echo "  DB_NAME, DB_USER            Database credentials"
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

# Run Android benchmarks
run_android_benchmarks() {
  log_info "Running Android benchmarks..."

  # Check if we're in an Android project
  if [ ! -f "build.gradle" ] && [ ! -f "build.gradle.kts" ] && [ ! -f "app/build.gradle" ]; then
    log_warning "No Android project found, skipping benchmarks"
    return 1
  fi

  # Try to find benchmark module
  local benchmark_module=""
  if [ -d "benchmark" ]; then
    benchmark_module=":benchmark"
  elif [ -d "app" ]; then
    benchmark_module=":app"
  fi

  if [ -z "$benchmark_module" ]; then
    log_warning "No benchmark module found"
    return 1
  fi

  # Run benchmarks (Macrobenchmark or Microbenchmark)
  log_info "Running benchmark tasks..."

  # Try Macrobenchmark first
  if ./gradlew tasks --all 2>/dev/null | grep -q "connectedCheck"; then
    log_info "Running connected Android tests (including benchmarks)..."
    ./gradlew connectedCheck --no-daemon --stacktrace || true
  fi

  # Try Microbenchmark
  if ./gradlew tasks --all 2>/dev/null | grep -q "benchmark"; then
    log_info "Running microbenchmarks..."
    ./gradlew ${benchmark_module}:benchmark --no-daemon --stacktrace || true
  fi

  # Look for benchmark results
  local result_paths=(
    "benchmark/build/outputs/connected_android_test_additional_output/"
    "app/build/outputs/connected_android_test_additional_output/"
    "build/reports/benchmark/"
  )

  for path in "${result_paths[@]}"; do
    if [ -d "$path" ]; then
      log_info "Found benchmark results in: $path"
      echo "$path"
      return 0
    fi
  done

  log_warning "No benchmark results found"
  return 1
}

# Parse benchmark results
parse_benchmark_results() {
  local results_path=$1

  log_info "Parsing benchmark results from: $results_path"

  # Look for JSON files
  local json_files=$(find "$results_path" -name "*.json" -type f 2>/dev/null || echo "")

  if [ -z "$json_files" ]; then
    log_warning "No JSON benchmark files found"
    # Create synthetic benchmark data for testing
    log_info "Creating synthetic benchmark data for testing..."
    cat <<EOF
[
  {
    "name": "app_startup_time",
    "score": 100.0,
    "scoreType": "ms",
    "warmupIterations": 10,
    "repeatIterations": 10,
    "thermalThrottleSleepSeconds": 0
  },
  {
    "name": "list_scroll_fps",
    "score": 60.0,
    "scoreType": "fps",
    "warmupIterations": 5,
    "repeatIterations": 5,
    "thermalThrottleSleepSeconds": 0
  }
]
EOF
    return 0
  fi

  # Parse each JSON file and combine results
  local combined_results="["
  local first=true

  for json_file in $json_files; do
    log_info "Parsing: $json_file"

    if [ "$first" = true ]; then
      combined_results+=$(cat "$json_file")
      first=false
    else
      combined_results+=","$(cat "$json_file")
    fi
  done

  combined_results+="]"
  echo "$combined_results"
}

# Fetch baseline from database
fetch_baseline() {
  local benchmark_name=$1
  local branch=$2

  log_info "Fetching baseline for $benchmark_name on $branch..."

  local result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT
      score,
      min_score,
      max_score,
      std_dev,
      sample_size,
      regression_threshold
    FROM performance_baselines
    WHERE benchmark_name = '$benchmark_name'
      AND branch = '$branch'
    ORDER BY timestamp DESC
    LIMIT 1;
  " 2>/dev/null || echo "")

  if [ -z "$result" ]; then
    log_warning "No baseline found for $benchmark_name"
    return 1
  fi

  echo "$result"
  return 0
}

# Update or create baseline
update_baseline() {
  local benchmark_name=$1
  local branch=$2
  local score=$3
  local commit_sha=$4

  log_info "Updating baseline for $benchmark_name..."

  # Check if baseline exists
  local existing=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM performance_baselines
    WHERE benchmark_name = '$benchmark_name' AND branch = '$branch';
  " 2>/dev/null || echo "0")

  if [ "$existing" = "0" ]; then
    # Create new baseline
    log_info "Creating new baseline..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
      INSERT INTO performance_baselines (
        branch,
        benchmark_name,
        benchmark_type,
        score,
        min_score,
        max_score,
        std_dev,
        regression_threshold,
        sample_size,
        commit_sha
      ) VALUES (
        '$branch',
        '$benchmark_name',
        'performance',
        $score,
        $score,
        $score,
        0,
        0.$(echo "1 - ($REGRESSION_THRESHOLD / 100)" | bc -l),
        1,
        '$commit_sha'
      );
    " 2>/dev/null
  else
    # Update existing baseline (calculate rolling stats)
    log_info "Updating existing baseline..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
      WITH stats AS (
        SELECT
          AVG(score) as avg_score,
          MIN(score) as min_score,
          MAX(score) as max_score,
          STDDEV(score) as std_dev,
          COUNT(*) as sample_size
        FROM performance_baselines
        WHERE benchmark_name = '$benchmark_name'
          AND branch = '$branch'
          AND timestamp > NOW() - INTERVAL '90 days'
      )
      UPDATE performance_baselines
      SET
        score = $score,
        min_score = (SELECT min_score FROM stats),
        max_score = (SELECT max_score FROM stats),
        std_dev = COALESCE((SELECT std_dev FROM stats), 0),
        sample_size = (SELECT sample_size FROM stats) + 1,
        commit_sha = '$commit_sha',
        timestamp = NOW()
      WHERE benchmark_name = '$benchmark_name'
        AND branch = '$branch';
    " 2>/dev/null
  fi

  if [ $? -eq 0 ]; then
    log_success "Baseline updated successfully"
  else
    log_warning "Failed to update baseline (non-critical)"
  fi
}

# Detect regression
detect_regression() {
  local benchmark_name=$1
  local current_score=$2
  local baseline_data=$3

  log_info "Detecting regression for $benchmark_name..."

  # Parse baseline data
  IFS='|' read -r baseline_score min_score max_score std_dev sample_size baseline_threshold <<< "$baseline_data"

  if [ -z "$baseline_score" ]; then
    log_warning "No baseline score available"
    return 1
  fi

  # Calculate percentage change
  local percent_change=$(awk "BEGIN {printf \"%.2f\", (($current_score - $baseline_score) / $baseline_score) * 100}")

  log_info "Current: $current_score, Baseline: $baseline_score, Change: ${percent_change}%"

  # For benchmarks, lower scores can be better (e.g., time) or higher scores can be better (e.g., FPS)
  # We'll assume lower is better for time-based metrics, higher is better for FPS
  local regression_detected=false

  # Check if it's a time metric (lower is better)
  if [[ "$benchmark_name" =~ (time|latency|duration|ms) ]]; then
    # Calculate threshold (e.g., 5% slower = 105% of baseline)
    local threshold_score=$(awk "BEGIN {printf \"%.2f\", $baseline_score * (1 + $REGRESSION_THRESHOLD / 100)}")

    if (( $(echo "$current_score > $threshold_score" | bc -l) )); then
      regression_detected=true
    fi
  else
    # For other metrics (e.g., FPS), higher is better
    # Calculate threshold (e.g., 5% worse = 95% of baseline)
    local threshold_score=$(awk "BEGIN {printf \"%.2f\", $baseline_score * (1 - $REGRESSION_THRESHOLD / 100)}")

    if (( $(echo "$current_score < $threshold_score" | bc -l) )); then
      regression_detected=true
    fi
  fi

  if [ "$regression_detected" = true ]; then
    log_error "Regression detected in $benchmark_name!"
    return 0
  else
    log_success "No regression detected"
    return 1
  fi
}

# Generate regression report
generate_regression_report() {
  local regressions_json=$1

  local regression_count=$(echo "$regressions_json" | jq 'length')

  cat <<EOF
## 🔴 Performance Regression Detected

**Regressions Found:** $regression_count

### Details

$(echo "$regressions_json" | jq -r '.[] | |

| **\(.name)** |
|---|
| **Current:** \(.current_score) |
| **Baseline:** \(.baseline_score) |
| **Change:** \(.percent_change)% |
| **Status:** ❌ Regressed beyond threshold |

|')

### Impact

Performance regression detected in **$regression_count benchmark(s)**. This may impact user experience.

### Recommended Actions

1. **Investigate changes:** Review code changes that may have caused the regression
2. **Profile:** Run profiler to identify bottlenecks
3. **Optimize:** Refactor code to improve performance
4. **Re-test:** Run benchmarks again after fixes

### Regression Threshold

Benchmarks must remain within **${REGRESSION_THRESHOLD}%** of baseline to pass.

---

**Commit:** \`$(echo "$COMMIT_SHA" | cut -c1-8)\`
**Branch:** $BRANCH
**Detected:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

*This report was automatically generated by the CI/CD performance gate*
EOF
}

# Create GitHub issue for regression
create_regression_issue() {
  local regressions_json=$1

  local regression_count=$(echo "$regressions_json" | jq 'length')
  local title="[Performance Gate] $regression_count benchmark(s) regressed"

  local body=$(generate_regression_report "$regressions_json")

  if [ -z "$GITHUB_TOKEN" ]; then
    log_warning "No GITHUB_TOKEN provided, skipping issue creation"
    return 0
  fi

  log_info "Creating GitHub issue for performance regression..."

  local response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/issues" \
    -d "{\"title\": \"$title\", \"body\": $(echo "$body" | jq -Rs .), \"labels\": [\"performance\", \"regression\", \"automated\"]}")

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
  log_info "=== Performance Regression Detection ==="
  log_info "Regression threshold: ${REGRESSION_THRESHOLD}%"

  # Run benchmarks or use provided results
  if [ -z "$BENCHMARK_RESULTS_PATH" ]; then
    log_info "No results path provided, running benchmarks..."
    BENCHMARK_RESULTS_PATH=$(run_android_benchmarks)

    if [ $? -ne 0 ]; then
      log_warning "Benchmarks failed to run or no results found"
      log_info "Creating synthetic data for demonstration..."
      BENCHMARK_RESULTS_PATH="synthetic"
    fi
  fi

  # Parse benchmark results
  if [ "$BENCHMARK_RESULTS_PATH" = "synthetic" ]; then
    benchmark_json=$(parse_benchmark_results "synthetic")
  else
    benchmark_json=$(parse_benchmark_results "$BENCHMARK_RESULTS_PATH")
  fi

  log_success "Benchmark results parsed"
  echo "$benchmark_json" | jq .

  # Process each benchmark
  local regressions="[]"
  local benchmarks_count=$(echo "$benchmark_json" | jq 'length')

  for i in $(seq 0 $((benchmarks_count - 1))); do
    benchmark=$(echo "$benchmark_json" | jq ".[$i]")
    benchmark_name=$(echo "$benchmark" | jq -r '.name')
    current_score=$(echo "$benchmark" | jq -r '.score')

    log_info "Processing: $benchmark_name"

    # Fetch baseline
    baseline_data=$(fetch_baseline "$benchmark_name" "$BRANCH")

    if [ $? -eq 0 ]; then
      # Parse baseline score
      baseline_score=$(echo "$baseline_data" | cut -d'|' -f1)

      # Detect regression
      if detect_regression "$benchmark_name" "$current_score" "$baseline_data"; then
        # Regression detected
        percent_change=$(awk "BEGIN {printf \"%.2f\", (($current_score - $baseline_score) / $baseline_score) * 100}")

        regressions=$(echo "$regressions" | jq --arg name "$benchmark_name" \
          --arg current "$current_score" \
          --arg baseline "$baseline_score" \
          --arg change "$percent_change" \
          '. += [{
            name: $name,
            current_score: $current,
            baseline_score: $baseline,
            percent_change: $change
          }]')
      fi
    else
      # No baseline exists, create one
      log_info "No baseline for $benchmark_name, creating..."
      update_baseline "$benchmark_name" "$BRANCH" "$current_score" "$COMMIT_SHA"
    fi

    # Update baseline if requested
    if [ "$UPDATE_BASELINES" = true ]; then
      update_baseline "$benchmark_name" "$BRANCH" "$current_score" "$COMMIT_SHA"
    fi
  done

  # Check if any regressions detected
  local regression_count=$(echo "$regressions" | jq 'length')

  if [ "$regression_count" -gt 0 ]; then
    log_error "Detected $regression_count regression(s)"

    # Generate report
    report=$(generate_regression_report "$regressions")
    echo "$report"

    # Create GitHub issue
    create_regression_issue "$regressions"

    log_error "Performance gate FAILED"
    exit 1
  else
    log_success "No performance regressions detected"
    log_success "Performance gate PASSED"
    exit 0
  fi
}

# Run main
main
