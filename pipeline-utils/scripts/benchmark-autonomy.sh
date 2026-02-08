#!/bin/bash
# benchmark-autonomy.sh
# Performance benchmarking script for CI/CD autonomy features
# Measures before/after metrics and compares build times

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BENCHMARK_DIR="$PROJECT_ROOT/benchmarks"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create benchmark directory
mkdir -p "$BENCHMARK_DIR"

BENCHMARK_REPORT="$BENCHMARK_DIR/benchmark-$TIMESTAMP.txt"
BENCHMARK_JSON="$BENCHMARK_DIR/benchmark-$TIMESTAMP.json"
BENCHMARK_DB="$BENCHMARK_DIR/benchmark-history.db"

# Database setup (simple SQLite-based tracking)
DB_CONNECTION="${DB_CONNECTION:-sqlite:$BENCHMARK_DB}"

# Function to format duration
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%dm %ds" $minutes $secs
}

# Function to run benchmark test
run_benchmark() {
    local test_name="$1"
    local command="$2"
    local description="$3"

    echo -e "${BLUE}Running: $test_name${NC}"
    echo "Description: $description"

    local start_time=$(date +%s)
    local start_cpu=$(grep '^cpu ' /proc/stat 2>/dev/null | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}' || echo "0")

    # Run the command and capture output
    local output
    local exit_code

    if output=$(eval "$command" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo "Duration: $(format_duration $duration)"
    echo "Exit Code: $exit_code"

    # Save to benchmark report
    {
        echo "========================================"
        echo "Test: $test_name"
        echo "========================================"
        echo "Description: $description"
        echo "Command: $command"
        echo "Start Time: $(date -d @$start_time 2>/dev/null || date -r $start_time)"
        echo "End Time: $(date -d @$end_time 2>/dev/null || date -r $end_time)"
        echo "Duration: $duration seconds"
        echo "Exit Code: $exit_code"
        echo ""
        echo "Output:"
        echo "$output"
        echo ""
    } >> "$BENCHMARK_REPORT"

    # Return duration for further processing
    echo "$duration|$exit_code"
}

# Function to benchmark with autonomy features
benchmark_with_autonomy() {
    local test_name="$1"
    local command="$2"

    echo -e "${BLUE}Benchmarking with autonomy: $test_name${NC}"

    # Measure with retry logic
    local result
    result=$(run_benchmark "$test_name (with autonomy)" "$command" "Testing with autonomous retry and diagnosis")

    local duration=$(echo "$result" | cut -d'|' -f1)
    local exit_code=$(echo "$result" | cut -d'|' -f2)

    echo "$duration|$exit_code"
}

# Function to benchmark without autonomy features
benchmark_without_autonomy() {
    local test_name="$1"
    local command="$2"

    echo -e "${BLUE}Benchmarking without autonomy: $test_name${NC}"

    # Measure without retry logic
    local result
    result=$(run_benchmark "$test_name (without autonomy)" "$command" "Testing without autonomy features")

    local duration=$(echo "$result" | cut -d'|' -f1)
    local exit_code=$(echo "$result" | cut -d'|' -f2)

    echo "$duration|$exit_code"
}

# Function to calculate improvement
calculate_improvement() {
    local before=$1
    local after=$2

    if [ $before -eq 0 ]; then
        echo "N/A"
        return
    fi

    local improvement=$((before - after))
    local percentage=$((improvement * 100 / before))

    if [ $improvement -gt 0 ]; then
        echo -e "${GREEN}+${improvement}s (${percentage}% faster)${NC}"
    elif [ $improvement -lt 0 ]; then
        echo -e "${RED}${improvement}s (${percentage}% slower)${NC}"
    else
        echo "No change"
    fi
}

# Function to save benchmark to database
save_to_database() {
    local test_name="$1"
    local baseline_time="$2"
    local autonomy_time="$3"
    local improvement="$4"

    # Simple CSV-based "database" for portability
    local csv_file="$BENCHMARK_DIR/benchmark-history.csv"

    # Create CSV with header if it doesn't exist
    if [ ! -f "$csv_file" ]; then
        echo "timestamp,test_name,baseline_time,autonomy_time,improvement,improvement_percent" > "$csv_file"
    fi

    # Calculate improvement percentage
    local improvement_percent=0
    if [ $baseline_time -gt 0 ]; then
        improvement_percent=$(( (baseline_time - autonomy_time) * 100 / baseline_time ))
    fi

    # Append to CSV
    echo "$TIMESTAMP,$test_name,$baseline_time,$autonomy_time,$improvement,$improvement_percent" >> "$csv_file"
}

# Function to generate JSON report
generate_json_report() {
    local json_data="$1"

    cat > "$BENCHMARK_JSON" <<EOF
{
  "benchmark_timestamp": "$TIMESTAMP",
  "benchmark_date": "$(date)",
  "project_root": "$PROJECT_ROOT",
  "results": [
$json_data
  ]
}
EOF

    echo "JSON report saved to: $BENCHMARK_JSON"
}

# Main benchmark execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}CI/CD Autonomy Performance Benchmark${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Benchmark started: $(date)"
    echo "Project root: $PROJECT_ROOT"
    echo "Report file: $BENCHMARK_REPORT"
    echo ""

    # Initialize benchmark report
    {
        echo "========================================"
        echo "CI/CD Autonomy Performance Benchmark"
        echo "========================================"
        echo ""
        echo "Started: $(date)"
        echo "Project: $PROJECT_ROOT"
        echo ""
    } > "$BENCHMARK_REPORT"

    # Change to project root for tests
    cd "$PROJECT_ROOT"

    # ============================================
    # Benchmark 1: Clean Build
    # ============================================
    echo -e "${YELLOW}=== Benchmark 1: Clean Build ===${NC}"
    echo ""

    if [ -d "simpleGame" ]; then
        cd simpleGame

        # Without autonomy
        baseline_result=$(benchmark_without_autonomy "Clean Build" "./gradlew clean assembleDebug --no-daemon --stacktrace")
        baseline_duration=$(echo "$baseline_result" | cut -d'|' -f1)
        baseline_exit=$(echo "$baseline_result" | cut -d'|' -f2)

        echo ""

        # With autonomy (using retry script)
        autonomy_result=$(benchmark_with_autonomy "Clean Build" "../pipeline-utils/scripts/retry-command.sh --max-retries=2 ./gradlew clean assembleDebug --no-daemon --stacktrace")
        autonomy_duration=$(echo "$autonomy_result" | cut -d'|' -f1)
        autonomy_exit=$(echo "$autonomy_result" | cut -d'|' -f2)

        echo ""
        echo -e "${BLUE}Comparison: Clean Build${NC}"
        echo "Baseline (without autonomy):  $(format_duration $baseline_duration)"
        echo "With autonomy:                $(format_duration $autonomy_duration)"
        echo -n "Improvement:                   "
        calculate_improvement $baseline_duration $autonomy_duration
        echo ""

        # Save to database
        save_to_database "clean_build" $baseline_duration $autonomy_duration $((baseline_duration - autonomy_duration))

        cd ..
    else
        echo -e "${YELLOW}Skipping clean build benchmark (simpleGame directory not found)${NC}"
        echo ""
    fi

    # ============================================
    # Benchmark 2: Unit Tests
    # ============================================
    echo -e "${YELLOW}=== Benchmark 2: Unit Tests ===${NC}"
    echo ""

    if [ -d "simpleGame" ]; then
        cd simpleGame

        # Without autonomy
        baseline_result=$(benchmark_without_autonomy "Unit Tests" "./gradlew testStandardDebugUnitTest --no-daemon --stacktrace")
        baseline_duration=$(echo "$baseline_result" | cut -d'|' -f1)
        baseline_exit=$(echo "$baseline_result" | cut -d'|' -f2)

        echo ""

        # With autonomy
        autonomy_result=$(benchmark_with_autonomy "Unit Tests" "../pipeline-utils/scripts/retry-command.sh --max-retries=2 ./gradlew testStandardDebugUnitTest --no-daemon --stacktrace")
        autonomy_duration=$(echo "$autonomy_result" | cut -d'|' -f1)
        autonomy_exit=$(echo "$autonomy_result" | cut -d'|' -f2)

        echo ""
        echo -e "${BLUE}Comparison: Unit Tests${NC}"
        echo "Baseline (without autonomy):  $(format_duration $baseline_duration)"
        echo "With autonomy:                $(format_duration $autonomy_duration)"
        echo -n "Improvement:                   "
        calculate_improvement $baseline_duration $autonomy_duration
        echo ""

        # Save to database
        save_to_database "unit_tests" $baseline_duration $autonomy_duration $((baseline_duration - autonomy_duration))

        cd ..
    else
        echo -e "${YELLOW}Skipping unit test benchmark (simpleGame directory not found)${NC}"
        echo ""
    fi

    # ============================================
    # Benchmark 3: Cache Freshness Check
    # ============================================
    echo -e "${YELLOW}=== Benchmark 3: Cache Freshness Check ===${NC}"
    echo ""

    # Measure cache check performance
    cache_result=$(run_benchmark "Cache Freshness Check" "pipeline-utils/scripts/check-cache-freshness.sh" "Testing cache freshness detection")
    cache_duration=$(echo "$cache_result" | cut -d'|' -f1)

    echo ""
    echo -e "${GREEN}Cache check completed in: $(format_duration $cache_duration)${NC}"
    echo ""

    # ============================================
    # Benchmark 4: Project Size Analysis
    # ============================================
    echo -e "${YELLOW}=== Benchmark 4: Project Size Analysis ===${NC}"
    echo ""

    # Measure project analysis performance
    analysis_result=$(run_benchmark "Project Size Analysis" "pipeline-utils/scripts/analyze-project-size.sh --yaml" "Testing project size analysis")
    analysis_duration=$(echo "$analysis_result" | cut -d'|' -f1)

    echo ""
    echo -e "${GREEN}Project analysis completed in: $(format_duration $analysis_duration)${NC}"
    echo ""

    # ============================================
    # Benchmark 5: Failure Diagnosis
    # ============================================
    echo -e "${YELLOW}=== Benchmark 5: Failure Diagnosis ===${NC}"
    echo ""

    # Create a test log file
    local test_log=$(mktemp)
    cat > "$test_log" <<EOF
FAILURE: Build failed with error
* What went wrong:
Execution failed for task ':app:compileStandardDebugKotlin'.
> A failure occurred while executing org.jetbrains.kotlin.compilerRunner.GradleCompilerRunner
   > OutOfMemoryError: Java heap space
EOF

    # Measure diagnosis performance
    diagnosis_result=$(run_benchmark "Failure Diagnosis" "pipeline-utils/scripts/diagnose-failure.sh $test_log" "Testing failure diagnosis")
    diagnosis_duration=$(echo "$diagnosis_result" | cut -d'|' -f1)

    rm -f "$test_log"

    echo ""
    echo -e "${GREEN}Failure diagnosis completed in: $(format_duration $diagnosis_duration)${NC}"
    echo ""

    # ============================================
    # Generate Summary Report
    # ============================================
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Benchmark Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Read benchmark history
    if [ -f "$BENCHMARK_DIR/benchmark-history.csv" ]; then
        echo "Historical Benchmark Data:"
        echo ""
        column -t -s',' "$BENCHMARK_DIR/benchmark-history.csv" | sed 's/^/  /'
        echo ""
    fi

    # Calculate aggregate statistics
    echo "Aggregate Statistics:"
    echo ""

    # Count total benchmarks
    local total_benchmarks=0
    local total_improvement=0

    if [ -f "$BENCHMARK_DIR/benchmark-history.csv" ]; then
        total_benchmarks=$(tail -n +2 "$BENCHMARK_DIR/benchmark-history.csv" | wc -l)
        total_improvement=$(tail -n +2 "$BENCHMARK_DIR/benchmark-history.csv" | awk -F',' '{sum+=$5} END {print int(sum)}')
    fi

    echo "  Total Benchmarks: $total_benchmarks"
    echo "  Total Time Saved: $(format_duration $total_improvement)"
    echo ""

    # Generate performance recommendations
    echo -e "${BLUE}Performance Recommendations:${NC}"
    echo ""

    if [ -f "$BENCHMARK_DIR/benchmark-history.csv" ]; then
        # Check if autonomy is helping
        local avg_improvement=$(tail -n +2 "$BENCHMARK_DIR/benchmark-history.csv" | awk -F',' '{sum+=$6; count++} END {print int(sum/count)}')

        if [ $avg_improvement -gt 10 ]; then
            echo -e "  ${GREEN}✓${NC} Autonomy features are improving performance by ${avg_improvement}% on average"
        elif [ $avg_improvement -gt 0 ]; then
            echo -e "  ${YELLOW}⚠${NC} Autonomy features show minimal improvement (${avg_improvement}%)"
            echo "    Consider tuning retry thresholds and cache settings"
        else
            echo -e "  ${RED}✗${NC} Autonomy features are not improving performance"
            echo "    Review configuration and consider disabling costly features"
        fi
    else
        echo "  No historical data available for comparison"
    fi

    echo ""

    # Save summary to report
    {
        echo "========================================"
        echo "Benchmark Summary"
        echo "========================================"
        echo ""
        echo "Completed: $(date)"
        echo "Total Benchmarks: $total_benchmarks"
        echo "Total Time Saved: $(format_duration $total_improvement)"
        echo ""
        echo "See benchmark-history.csv for detailed data"
    } >> "$BENCHMARK_REPORT"

    echo "Benchmark report saved to: $BENCHMARK_REPORT"
    echo "Benchmark history: $BENCHMARK_DIR/benchmark-history.csv"
    echo ""
    echo -e "${GREEN}Benchmark completed successfully!${NC}"
    echo ""

    exit 0
}

# Run main function
main "$@"
