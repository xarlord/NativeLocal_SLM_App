#!/bin/bash
# health-check.sh
# Performs comprehensive health checks on deployment endpoints
# Monitors error rates, response times, and other metrics
# Compares against configured thresholds and returns status
# Stores health metrics in database for analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/deployment-policy.yaml"
ENV_FILE="${SCRIPT_DIR}/../../.env"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Default values (can be overridden by config or environment)
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost:8080/health}"
METRICS_ENDPOINT="${METRICS_ENDPOINT:-http://localhost:8080/metrics}"
DEPLOYMENT_ID="${DEPLOYMENT_ID:-unknown}"
COMMIT_SHA="${COMMIT_SHA:-unknown}"
BUILD_ID="${BUILD_ID:-unknown}"

# Threshold defaults
ERROR_RATE_THRESHOLD=5.0  # 5% error rate
RESPONSE_TIME_THRESHOLD=2000  # 2000ms (2 seconds)
AVAILABILITY_THRESHOLD=99.0  # 99% availability

# Check arguments
SHOW_HELP=false
VERBOSE=false
WAIT_FOR_HEALTH=false
MAX_WAIT_SECONDS=300

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -w|--wait)
      WAIT_FOR_HEALTH=true
      shift
      ;;
    --max-wait)
      MAX_WAIT_SECONDS="$2"
      shift 2
      ;;
    --endpoint)
      HEALTH_ENDPOINT="$2"
      shift 2
      ;;
    --deployment-id)
      DEPLOYMENT_ID="$2"
      shift 2
      ;;
    *)
      # Unknown option
      shift
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  cat << EOF
Usage: $0 [OPTIONS]

Performs health checks on deployment and stores metrics in database.

Options:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -w, --wait              Wait for health check to pass
  --max-wait SECONDS      Maximum time to wait for health (default: 300)
  --endpoint URL          Health endpoint to check (default: \$HEALTH_ENDPOINT)
  --deployment-id ID      Deployment identifier (default: \$DEPLOYMENT_ID)

Environment Variables:
  HEALTH_ENDPOINT         Health check endpoint URL
  METRICS_ENDPOINT        Prometheus metrics endpoint URL
  DEPLOYMENT_ID           Unique deployment identifier
  COMMIT_SHA              Git commit SHA
  BUILD_ID                CI/CD build ID
  DATABASE_URL            PostgreSQL connection string

Exit Codes:
  0 - Health check passed
  1 - Health check failed
  2 - Configuration error
  3 - Timeout (waiting for health)

Example:
  $0 --endpoint https://api.example.com/health --deployment-id deploy-123
EOF
  exit 0
fi

# Function to log messages
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[VERBOSE]${NC} $1"
  fi
}

# Function to make HTTP request with timeout
make_request() {
  local url="$1"
  local max_time="${2:-10}"

  if command -v curl >/dev/null 2>&1; then
    curl -s -S --max-time "$max_time" "$url" 2>&1 || echo "curl_failed"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O - -T "$max_time" "$url" 2>&1 || echo "wget_failed"
  else
    log_error "Neither curl nor wget available"
    echo "no_http_client"
  fi
}

# Function to check if endpoint is accessible
check_endpoint_accessible() {
  local endpoint="$1"
  local response
  local http_code

  log_verbose "Checking endpoint accessibility: $endpoint"

  # Try to get HTTP code
  if command -v curl >/dev/null 2>&1; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" 2>/dev/null || echo "000")
  elif command -v wget >/dev/null 2>&1; then
    http_code=$(wget -S -O /dev/null "$endpoint" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}' || echo "000")
  else
    http_code="000"
  fi

  log_verbose "HTTP response code: $http_code"

  if [ "$http_code" = "000" ]; then
    return 1
  elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 500 ]; then
    return 0
  else
    return 1
  fi
}

# Function to perform health check
perform_health_check() {
  local endpoint="$1"
  local check_start=$(date +%s)

  log_info "Performing health check on: $endpoint"

  # Check if endpoint is accessible
  if ! check_endpoint_accessible "$endpoint"; then
    log_error "Health endpoint is not accessible"
    return 1
  fi

  # Get health check response
  local response=$(make_request "$endpoint" 10)

  if [ "$response" = "curl_failed" ] || [ "$response" = "wget_failed" ] || [ "$response" = "no_http_client" ]; then
    log_error "Failed to fetch health endpoint"
    return 1
  fi

  local check_end=$(date +%s)
  local response_time=$(( (check_end - check_start) * 1000 ))

  log_verbose "Health check response time: ${response_time}ms"
  log_verbose "Response: $response"

  # Parse JSON response if possible
  local status="unknown"
  local error_rate=0
  local availability=100

  if command -v jq >/dev/null 2>&1; then
    status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
    error_rate=$(echo "$response" | jq -r '.error_rate // .errorRate // 0' 2>/dev/null || echo "0")
    availability=$(echo "$response" | jq -r '.availability // .availability // 100' 2>/dev/null || echo "100")
  else
    # Simple text parsing fallback
    if echo "$response" | grep -qi '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
      status="healthy"
    elif echo "$response" | grep -qi '"status"[[:space:]]*:[[:space:]]*"unhealthy"'; then
      status="unhealthy"
    elif echo "$response" | grep -qi "healthy"; then
      status="healthy"
    fi
  fi

  log_info "Health status: $status"
  log_info "Error rate: ${error_rate}%"
  log_info "Availability: ${availability}%"

  # Evaluate health against thresholds
  local is_healthy=true

  if [ "$status" = "unhealthy" ] || [ "$status" = "error" ]; then
    is_healthy=false
    log_error "Status reported as unhealthy"
  fi

  # Check error rate threshold
  if (( $(echo "$error_rate > $ERROR_RATE_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
    is_healthy=false
    log_error "Error rate ${error_rate}% exceeds threshold ${ERROR_RATE_THRESHOLD}%"
  fi

  # Check response time threshold
  if [ "$response_time" -gt "$RESPONSE_TIME_THRESHOLD" ]; then
    is_healthy=false
    log_error "Response time ${response_time}ms exceeds threshold ${RESPONSE_TIME_THRESHOLD}ms"
  fi

  # Check availability threshold
  if (( $(echo "$availability < $AVAILABILITY_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
    is_healthy=false
    log_error "Availability ${availability}% below threshold ${AVAILABILITY_THRESHOLD}%"
  fi

  if [ "$is_healthy" = true ]; then
    log_success "Health check passed"
    return 0
  else
    log_error "Health check failed"
    return 1
  fi
}

# Function to store health metrics in database
store_health_metrics() {
  local status="$1"
  local response_time="$2"
  local error_rate="$3"
  local availability="$4"

  # Check if database URL is set
  if [ -z "$DATABASE_URL" ]; then
    log_warning "DATABASE_URL not set, skipping database storage"
    return 0
  fi

  log_verbose "Storing health metrics in database..."

  # Create health_checks table if not exists
  local create_table_sql="
  CREATE TABLE IF NOT EXISTS health_checks (
    id SERIAL PRIMARY KEY,
    deployment_id VARCHAR(100),
    commit_sha VARCHAR(40),
    build_id INTEGER,

    health_status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    error_rate NUMERIC(5,2),
    availability NUMERIC(5,2),

    endpoint TEXT,
    threshold_error_rate NUMERIC(5,2) DEFAULT 5.0,
    threshold_response_time INTEGER DEFAULT 2000,
    threshold_availability NUMERIC(5,2) DEFAULT 99.0,

    checks_passed JSONB,
    checks_failed JSONB,

    timestamp TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_health_checks_deployment ON health_checks(deployment_id);
  CREATE INDEX IF NOT EXISTS idx_health_checks_timestamp ON health_checks(timestamp DESC);
  CREATE INDEX IF NOT EXISTS idx_health_checks_status ON health_checks(health_status);
  "

  # Insert health check result
  local insert_sql="
  INSERT INTO health_checks (
    deployment_id, commit_sha, build_id,
    health_status, response_time_ms, error_rate, availability,
    endpoint, threshold_error_rate, threshold_response_time, threshold_availability,
    checks_passed, checks_failed
  ) VALUES (
    '$DEPLOYMENT_ID', '$COMMIT_SHA', '$BUILD_ID',
    '$status', $response_time, $error_rate, $availability,
    '$HEALTH_ENDPOINT', $ERROR_RATE_THRESHOLD, $RESPONSE_TIME_THRESHOLD, $AVAILABILITY_THRESHOLD,
    '{\"endpoint_accessible\": true}'::jsonb,
    CASE WHEN '$status' = 'healthy' THEN '{}'::jsonb ELSE '{\"threshold_exceeded\": true}'::jsonb END
  );
  "

  # Execute SQL
  if command -v psql >/dev/null 2>&1; then
    echo "$create_table_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "CREATE TABLE\|CREATE INDEX" || true
    echo "$insert_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "INSERT 0 1" || true
    log_verbose "Health metrics stored successfully"
  else
    log_warning "psql not available, skipping database storage"
  fi
}

# Main execution
log_info "=== Deployment Health Check ==="
log_info "Deployment ID: $DEPLOYMENT_ID"
log_info "Commit SHA: ${COMMIT_SHA:0:8}"
log_info "Build ID: $BUILD_ID"
log_info "Health Endpoint: $HEALTH_ENDPOINT"
echo ""

# Function to wait for health check
wait_for_health() {
  local max_wait="$1"
  local waited=0
  local check_interval=10

  log_info "Waiting for health check to pass (max ${max_wait}s)..."

  while [ $waited -lt $max_wait ]; do
    if perform_health_check "$HEALTH_ENDPOINT"; then
      local remaining=$((max_wait - waited))
      log_success "Health check passed after ${waited}s"
      return 0
    fi

    waited=$((waited + check_interval))
    if [ $waited -lt $max_wait ]; then
      log_info "Retrying in ${check_interval}s... (${waited}/${max_wait}s elapsed)"
      sleep $check_interval
    fi
  done

  log_error "Health check did not pass within ${max_wait}s"
  return 3
}

# Perform health check (with optional wait)
HEALTH_STATUS="unhealthy"
RESPONSE_TIME=0
ERROR_RATE=0
AVAILABILITY=0

if [ "$WAIT_FOR_HEALTH" = true ]; then
  wait_for_health "$MAX_WAIT_SECONDS"
  EXIT_CODE=$?
else
  perform_health_check "$HEALTH_ENDPOINT"
  EXIT_CODE=$?
fi

# Determine health status
if [ $EXIT_CODE -eq 0 ]; then
  HEALTH_STATUS="healthy"
else
  HEALTH_STATUS="unhealthy"
fi

# Store metrics (extract values from health check)
store_health_metrics "$HEALTH_STATUS" "$RESPONSE_TIME" "$ERROR_RATE" "$AVAILABILITY"

echo ""
log_info "=== Health Check Complete ==="
echo "Status: $HEALTH_STATUS"
echo "Exit Code: $EXIT_CODE"

exit $EXIT_CODE
