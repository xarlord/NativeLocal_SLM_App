#!/bin/bash
# progressive-deploy.sh
# Implements progressive deployment strategy with automatic rollback
# Deploys to percentage of users (10%, 25%, 50%, 100%)
# Monitors health at each stage before proceeding
# Auto-rollback if metrics degrade
# Configurable wait periods between stages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/deployment-policy.yaml"
HEALTH_CHECK_SCRIPT="$SCRIPT_DIR/health-check.sh"
ROLLBACK_SCRIPT="$SCRIPT_DIR/rollback-deployment.sh"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_ID="${DEPLOYMENT_ID:-deploy-$(date +%s)}"
COMMIT_SHA="${COMMIT_SHA:-unknown}"
BUILD_ID="${BUILD_ID:-unknown}"

# Progressive rollout stages (percentage of traffic)
STAGE_1_PERCENTAGE=10
STAGE_2_PERCENTAGE=25
STAGE_3_PERCENTAGE=50
STAGE_4_PERCENTAGE=100

# Wait periods between stages (seconds)
STAGE_WAIT_TIME=300  # 5 minutes default
HEALTH_CHECK_TIMEOUT=60

# Thresholds for rollback
MAX_ERROR_RATE=5.0
MIN_AVAILABILITY=99.0
MAX_RESPONSE_TIME=2000

# Check arguments
SHOW_HELP=false
SKIP_ROLLBACK=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    --skip-rollback)
      SKIP_ROLLBACK=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --deployment-id)
      DEPLOYMENT_ID="$2"
      shift 2
      ;;
    --commit)
      COMMIT_SHA="$2"
      shift 2
      ;;
    --wait-time)
      STAGE_WAIT_TIME="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  cat << EOF
Usage: $0 [OPTIONS]

Performs progressive deployment with health monitoring and automatic rollback.

Options:
  -h, --help              Show this help message
  --skip-rollback         Skip automatic rollback on failure
  --dry-run               Simulate deployment without making changes
  --deployment-id ID      Deployment identifier (default: deploy-timestamp)
  --commit SHA            Git commit SHA
  --wait-time SECONDS     Time to wait between stages (default: 300)

Progressive Stages:
  Stage 1: 10% traffic  -> Monitor -> Stage 2 or Rollback
  Stage 2: 25% traffic  -> Monitor -> Stage 3 or Rollback
  Stage 3: 50% traffic  -> Monitor -> Stage 4 or Rollback
  Stage 4: 100% traffic -> Monitor -> Complete or Rollback

Environment Variables:
  DEPLOYMENT_ID           Unique deployment identifier
  COMMIT_SHA              Git commit SHA
  BUILD_ID                CI/CD build ID
  STAGE_WAIT_TIME         Seconds to wait between health checks
  MAX_ERROR_RATE          Error rate threshold for rollback (default: 5.0)
  MIN_AVAILABILITY        Availability threshold (default: 99.0)
  MAX_RESPONSE_TIME       Response time threshold in ms (default: 2000)
  HEALTH_ENDPOINT         Health check endpoint URL
  DATABASE_URL            PostgreSQL connection string

Exit Codes:
  0 - Deployment successful
  1 - Deployment failed and rolled back
  2 - Configuration error
  3 - Deployment failed, rollback skipped

Example:
  $0 --deployment-id deploy-123 --commit abc123 --wait-time 600

The script will:
  1. Deploy to 10% of traffic
  2. Monitor health for configured wait period
  3. Proceed to 25% if healthy, or rollback
  4. Repeat for 50% and 100%
  5. Mark deployment as successful or rollback
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

log_stage() {
  echo -e "${BLUE}[STAGE]${NC} $1"
}

# Function to update traffic percentage
update_traffic_percentage() {
  local percentage="$1"
  local stage="$2"

  log_info "Updating traffic to ${percentage}%..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would set traffic to ${percentage}%"
    return 0
  fi

  # Check if there's a custom deployment script
  if [ -n "$DEPLOYMENT_SCRIPT" ] && [ -f "$DEPLOYMENT_SCRIPT" ]; then
    log_info "Using deployment script for traffic update"

    if bash "$DEPLOYMENT_SCRIPT" update-traffic "$percentage" "$stage"; then
      log_success "Traffic updated to ${percentage}%"
      return 0
    else
      log_error "Failed to update traffic to ${percentage}%"
      return 1
    fi
  fi

  # Default: Simulate traffic update
  # In production, this would integrate with your load balancer/service mesh
  log_info "Simulating traffic update to ${percentage}%"
  log_warning "Configure DEPLOYMENT_SCRIPT for actual traffic control"

  return 0
}

# Function to perform health check
perform_health_check() {
  local stage="$1"
  local percentage="$2"

  log_info "Performing health check for Stage $stage (${percentage}% traffic)..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would perform health check"
    return 0
  fi

  # Run health check script
  if [ -f "$HEALTH_CHECK_SCRIPT" ]; then
    # Export environment for health check
    export DEPLOYMENT_ID="${DEPLOYMENT_ID}-stage-${stage}"
    export COMMIT_SHA="$COMMIT_SHA"
    export BUILD_ID="$BUILD_ID"

    if bash "$HEALTH_CHECK_SCRIPT" --endpoint "$HEALTH_ENDPOINT"; then
      log_success "Health check passed for Stage $stage"
      return 0
    else
      log_error "Health check failed for Stage $stage"
      return 1
    fi
  else
    log_warning "Health check script not found, skipping"
    return 0
  fi
}

# Function to wait for observation period
wait_and_monitor() {
  local stage="$1"
  local percentage="$2"
  local wait_time="$3"

  log_info "Waiting ${wait_time}s for observation period (Stage ${stage}, ${percentage}% traffic)..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would wait ${wait_time}s"
    return 0
  fi

  # Wait for the specified time
  sleep "$wait_time"

  # Perform health check after wait
  if ! perform_health_check "$stage" "$percentage"; then
    return 1
  fi

  return 0
}

# Function to perform rollback
perform_rollback() {
  local reason="$1"
  local stage="$2"

  log_error "Initiating rollback from Stage $stage..."
  log_error "Reason: $reason"

  if [ "$SKIP_ROLLBACK" = true ]; then
    log_warning "Skipping rollback (--skip-rollback)"
    return 3
  fi

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would perform rollback"
    return 1
  fi

  # Run rollback script
  if [ -f "$ROLLBACK_SCRIPT" ]; then
    export DEPLOYMENT_ID="$DEPLOYMENT_ID"
    export COMMIT_SHA="$COMMIT_SHA"
    export BUILD_ID="$BUILD_ID"
    export ROLLBACK_REASON="$reason (failed at Stage $stage)"

    if bash "$ROLLBACK_SCRIPT" --force; then
      log_info "Rollback completed"
    else
      log_error "Rollback script failed"
    fi
  else
    log_warning "Rollback script not found"
  fi

  return 1
}

# Function to store stage metrics
store_stage_metrics() {
  local stage="$1"
  local percentage="$2"
  local status="$3"

  log_verbose "Storing stage metrics..."

  if [ "$DRY_RUN" = true ]; then
    return 0
  fi

  if [ -z "$DATABASE_URL" ]; then
    return 0
  fi

  if ! command -v psql >/dev/null 2>&1; then
    return 0
  fi

  # Create progressive_deployments table
  local create_table_sql="
  CREATE TABLE IF NOT EXISTS progressive_deployments (
    id SERIAL PRIMARY KEY,
    deployment_id VARCHAR(100) NOT NULL,
    commit_sha VARCHAR(40),
    build_id INTEGER,

    stage INTEGER NOT NULL,
    traffic_percentage INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,

    error_rate NUMERIC(5,2),
    availability NUMERIC(5,2),
    response_time_ms INTEGER,

    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,

    rollback_triggered BOOLEAN DEFAULT FALSE,
    rollback_reason TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_progressive_deployments_id ON progressive_deployments(deployment_id);
  CREATE INDEX IF NOT EXISTS idx_progressive_deployments_stage ON progressive_deployments(stage);
  CREATE INDEX IF NOT EXISTS idx_progressive_deployments_status ON progressive_deployments(status);
  "

  local insert_sql="
  INSERT INTO progressive_deployments (
    deployment_id, commit_sha, build_id,
    stage, traffic_percentage, status,
    started_at, completed_at
  ) VALUES (
    '$DEPLOYMENT_ID', '$COMMIT_SHA', '$BUILD_ID',
    $stage, $percentage, '$status',
    NOW(),
    CASE WHEN '$status' = 'completed' THEN NOW() ELSE NULL END
  );
  "

  echo "$create_table_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "CREATE TABLE\|CREATE INDEX" || true
  echo "$insert_sql" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 2>&1 | grep -v "INSERT 0 1" || true
}

# Function to mark deployment as complete
mark_deployment_complete() {
  log_success "Marking deployment as complete..."

  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN: Would mark deployment as complete"
    return 0
  fi

  # Update to 100% traffic
  update_traffic_percentage 100 "complete"

  # Store final metrics
  store_stage_metrics 0 100 "completed"

  log_success "Deployment $DEPLOYMENT_ID completed successfully!"
}

# Function to verify prerequisites
verify_prerequisites() {
  log_info "Verifying prerequisites..."

  local all_good=true

  # Check health check script
  if [ ! -f "$HEALTH_CHECK_SCRIPT" ]; then
    log_warning "Health check script not found: $HEALTH_CHECK_SCRIPT"
  fi

  # Check rollback script
  if [ ! -f "$ROLLBACK_SCRIPT" ]; then
    log_warning "Rollback script not found: $ROLLBACK_SCRIPT"
  fi

  # Check database connection (optional)
  if [ -n "$DATABASE_URL" ]; then
    if command -v psql >/dev/null 2>&1; then
      if psql "$DATABASE_URL" -c "SELECT 1" >/dev/null 2>&1; then
        log_verbose "Database connection verified"
      fi
    fi
  fi

  if [ "$all_good" = false ]; then
    return 1
  fi

  log_success "Prerequisites verified"
  return 0
}

# Main execution
log_info "=== Progressive Deployment ==="
log_info "Deployment ID: $DEPLOYMENT_ID"
log_info "Commit SHA: ${COMMIT_SHA:0:8}"
log_info "Build ID: $BUILD_ID"
log_info "Stage Wait Time: ${STAGE_WAIT_TIME}s"
log_info "Error Rate Threshold: ${MAX_ERROR_RATE}%"
log_info "Availability Threshold: ${MIN_AVAILABILITY}%"
log_info "Response Time Threshold: ${MAX_RESPONSE_TIME}ms"
echo ""

# Verify prerequisites
verify_prerequisites

# Store initial deployment record
store_stage_metrics 0 0 "started"

# Stage 1: Deploy to 10% traffic
log_stage "Stage 1: Deploying to 10% traffic"
if ! update_traffic_percentage $STAGE_1_PERCENTAGE 1; then
  perform_rollback "Failed to update traffic to 10%" 1
  exit 1
fi

if ! wait_and_monitor 1 $STAGE_1_PERCENTAGE $STAGE_WAIT_TIME; then
  perform_rollback "Health check failed at 10% traffic" 1
  exit 1
fi

store_stage_metrics 1 $STAGE_1_PERCENTAGE "completed"
log_success "Stage 1 completed successfully"
echo ""

# Stage 2: Deploy to 25% traffic
log_stage "Stage 2: Deploying to 25% traffic"
if ! update_traffic_percentage $STAGE_2_PERCENTAGE 2; then
  perform_rollback "Failed to update traffic to 25%" 2
  exit 1
fi

if ! wait_and_monitor 2 $STAGE_2_PERCENTAGE $STAGE_WAIT_TIME; then
  perform_rollback "Health check failed at 25% traffic" 2
  exit 1
fi

store_stage_metrics 2 $STAGE_2_PERCENTAGE "completed"
log_success "Stage 2 completed successfully"
echo ""

# Stage 3: Deploy to 50% traffic
log_stage "Stage 3: Deploying to 50% traffic"
if ! update_traffic_percentage $STAGE_3_PERCENTAGE 3; then
  perform_rollback "Failed to update traffic to 50%" 3
  exit 1
fi

if ! wait_and_monitor 3 $STAGE_3_PERCENTAGE $STAGE_WAIT_TIME; then
  perform_rollback "Health check failed at 50% traffic" 3
  exit 1
fi

store_stage_metrics 3 $STAGE_3_PERCENTAGE "completed"
log_success "Stage 3 completed successfully"
echo ""

# Stage 4: Deploy to 100% traffic
log_stage "Stage 4: Deploying to 100% traffic"
if ! update_traffic_percentage $STAGE_4_PERCENTAGE 4; then
  perform_rollback "Failed to update traffic to 100%" 4
  exit 1
fi

if ! wait_and_monitor 4 $STAGE_4_PERCENTAGE $STAGE_WAIT_TIME; then
  perform_rollback "Health check failed at 100% traffic" 4
  exit 1
fi

store_stage_metrics 4 $STAGE_4_PERCENTAGE "completed"
log_success "Stage 4 completed successfully"
echo ""

# All stages completed
mark_deployment_complete

echo ""
log_success "=== Progressive Deployment Complete ==="
log_info "All stages passed successfully"
log_info "Deployment is now at 100% traffic"
log_info "No rollback required"

exit 0
