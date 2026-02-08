-- Woodpecker CI Metrics Database Schema
-- Stores build metrics, failure patterns, and performance baselines
-- for autonomous CI/CD features

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ============================================
-- Build Metrics Table
-- ============================================
CREATE TABLE IF NOT EXISTS build_metrics (
  id SERIAL PRIMARY KEY,
  build_id INTEGER NOT NULL,
  pipeline_id INTEGER,
  commit_sha VARCHAR(40),
  commit_message TEXT,
  branch VARCHAR(100),
  event_type VARCHAR(20), -- push, pull_request, tag

  -- Resource usage
  duration_seconds INTEGER,
  memory_gb NUMERIC(5,2),
  cpu_cores INTEGER,

  -- Build results
  success BOOLEAN NOT NULL,
  exit_code INTEGER,
  failure_stage VARCHAR(50),

  -- Quality metrics
  code_coverage NUMERIC(5,2),
  test_count INTEGER,
  test_passed INTEGER,
  test_failed INTEGER,

  -- Performance metrics
  benchmark_score NUMERIC(10,2),

  -- Metadata
  timestamp TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_build UNIQUE (build_id, commit_sha)
);

-- Index for common queries
CREATE INDEX idx_build_metrics_timestamp ON build_metrics(timestamp DESC);
CREATE INDEX idx_build_metrics_branch ON build_metrics(branch);
CREATE INDEX idx_build_metrics_success ON build_metrics(success);
CREATE INDEX idx_build_metrics_commit ON build_metrics(commit_sha);

-- ============================================
-- Failure Patterns Table
-- ============================================
CREATE TABLE IF NOT EXISTS failure_patterns (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,
  commit_sha VARCHAR(40),
  branch VARCHAR(100),

  -- Failure classification
  pattern_type VARCHAR(50) NOT NULL, -- OutOfMemoryError, NetworkTimeout, TestFailure, etc.
  severity VARCHAR(20) NOT NULL, -- critical, high, medium, low
  stage VARCHAR(50), -- build, test, lint, etc.

  -- Analysis
  error_message TEXT,
  stack_trace TEXT,
  file_path VARCHAR(500),
  line_number INTEGER,

  -- Remediation
  remediation TEXT,
  auto_fixable BOOLEAN DEFAULT FALSE,
  fix_applied BOOLEAN DEFAULT FALSE,

  -- Occurrence tracking
  first_seen TIMESTAMP DEFAULT NOW(),
  last_seen TIMESTAMP DEFAULT NOW(),
  occurrence_count INTEGER DEFAULT 1,

  created_at TIMESTAMP DEFAULT NOW()
);

-- Index for failure analysis
CREATE INDEX idx_failure_patterns_type ON failure_patterns(pattern_type);
CREATE INDEX idx_failure_patterns_severity ON failure_patterns(severity);
CREATE INDEX idx_failure_patterns_seen ON failure_patterns(last_seen DESC);
CREATE INDEX idx_failure_patterns_auto_fixable ON failure_patterns(auto_fixable) WHERE auto_fixable = TRUE;

-- ============================================
-- Performance Baselines Table
-- ============================================
CREATE TABLE IF NOT EXISTS performance_baselines (
  id SERIAL PRIMARY KEY,
  branch VARCHAR(100) NOT NULL DEFAULT 'main',
  benchmark_name VARCHAR(100) NOT NULL,
  benchmark_type VARCHAR(50), -- startup, ui, database, etc.

  -- Baseline values
  score NUMERIC(10,2) NOT NULL,
  min_score NUMERIC(10,2),
  max_score NUMERIC(10,2),
  std_dev NUMERIC(10,2),

  -- Threshold settings
  regression_threshold NUMERIC(5,2) DEFAULT 0.95, -- 5% degradation allowed
  improvement_threshold NUMERIC(5,2) DEFAULT 1.05,

  -- Metadata
  sample_size INTEGER DEFAULT 1,
  commit_sha VARCHAR(40),
  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_baseline UNIQUE (branch, benchmark_name)
);

CREATE INDEX idx_performance_baselines_branch ON performance_baselines(branch);
CREATE INDEX idx_performance_baselines_timestamp ON performance_baselines(timestamp DESC);

-- ============================================
-- Code Coverage History Table
-- ============================================
CREATE TABLE IF NOT EXISTS coverage_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,
  commit_sha VARCHAR(40),
  branch VARCHAR(100),

  -- Coverage metrics
  overall_coverage NUMERIC(5,2) NOT NULL,
  line_coverage NUMERIC(5,2),
  branch_coverage NUMERIC(5,2),
  method_coverage NUMERIC(5,2),

  -- Module breakdown (JSON)
  module_coverage JSONB,

  -- Threshold comparison
  threshold_met BOOLEAN,
  threshold_value NUMERIC(5,2) DEFAULT 80.0,

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_coverage_history_timestamp ON coverage_history(timestamp DESC);
CREATE INDEX idx_coverage_history_branch ON coverage_history(branch);
CREATE INDEX idx_coverage_history_coverage ON coverage_history(overall_coverage);

-- ============================================
-- Dependency Updates Table
-- ============================================
CREATE TABLE IF NOT EXISTS dependency_updates (
  id SERIAL PRIMARY KEY,
  update_id INTEGER, -- GitHub PR number

  -- Update details
  dependency_name VARCHAR(200) NOT NULL,
  old_version VARCHAR(50),
  new_version VARCHAR(50),
  update_type VARCHAR(20), -- major, minor, patch

  -- Status tracking
  status VARCHAR(20) DEFAULT 'pending', -- pending, testing, passed, failed, merged, closed
  pr_number INTEGER,
  pr_url TEXT,

  -- Testing results
  tests_passed INTEGER,
  tests_failed INTEGER,
  build_success BOOLEAN,

  -- Security implications
  has_security_fix BOOLEAN DEFAULT FALSE,
  vulnerability_severity VARCHAR(20),

  created_at TIMESTAMP DEFAULT NOW(),
  merged_at TIMESTAMP,
  closed_at TIMESTAMP
);

CREATE INDEX idx_dependency_updates_status ON dependency_updates(status);
CREATE INDEX idx_dependency_updates_security ON dependency_updates(has_security_fix) WHERE has_security_fix = TRUE;
CREATE INDEX idx_dependency_updates_created ON dependency_updates(created_at DESC);

-- ============================================
-- Security Scan Results Table
-- ============================================
CREATE TABLE IF NOT EXISTS security_scans (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,
  commit_sha VARCHAR(40),
  branch VARCHAR(100),

  -- Scan details
  scan_type VARCHAR(50) NOT NULL, -- secret, license, dependency, etc.
  scanner_version VARCHAR(50),

  -- Results
  findings_count INTEGER DEFAULT 0,
  critical_count INTEGER DEFAULT 0,
  high_count INTEGER DEFAULT 0,
  medium_count INTEGER DEFAULT 0,
  low_count INTEGER DEFAULT 0,

  -- Detailed findings (JSON)
  findings JSONB,

  -- Action taken
  action_taken VARCHAR(50), -- blocked, warning, passed
  issue_url TEXT,

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_security_scans_type ON security_scans(scan_type);
CREATE INDEX idx_security_scans_severity ON security_scans(critical_count, high_count);
CREATE INDEX idx_security_scans_timestamp ON security_scans(timestamp DESC);

-- ============================================
-- Resource Usage History Table
-- ============================================
CREATE TABLE IF NOT EXISTS resource_usage (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Resource allocation
  allocated_memory_gb NUMERIC(5,2),
  allocated_cpu_cores INTEGER,

  -- Actual usage
  peak_memory_gb NUMERIC(5,2),
  average_memory_gb NUMERIC(5,2),
  peak_cpu_percent NUMERIC(5,2),
  average_cpu_percent NUMERIC(5,2),

  -- Efficiency metrics
  memory_efficiency NUMERIC(5,2), -- used/allocated ratio
  cpu_efficiency NUMERIC(5,2),

  -- Project characteristics
  lines_of_code INTEGER,
  module_count INTEGER,
  test_count INTEGER,

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_resource_usage_timestamp ON resource_usage(timestamp DESC);
CREATE INDEX idx_resource_usage_efficiency ON resource_usage(memory_efficiency, cpu_efficiency);

-- ============================================
-- Code Ownership Table
-- ============================================
CREATE TABLE IF NOT EXISTS code_ownership (
  id SERIAL PRIMARY KEY,

  -- Code location
  file_pattern VARCHAR(500) NOT NULL, -- glob pattern: app/src/**/*.kt
  module VARCHAR(100),

  -- Owner information
  owner_type VARCHAR(20) NOT NULL, -- user, team, service
  owner_name VARCHAR(100) NOT NULL,
  github_username VARCHAR(100),

  -- Ownership strength (0.0 to 1.0)
  ownership_strength NUMERIC(3,2) DEFAULT 1.0,

  -- Metadata
  last_verified TIMESTAMP DEFAULT NOW(),
  notes TEXT,

  CONSTRAINT unique_owner UNIQUE (file_pattern, owner_name)
);

CREATE INDEX idx_code_ownership_pattern ON code_ownership(file_pattern);
CREATE INDEX idx_code_ownership_owner ON code_ownership(owner_name);

-- ============================================
-- Notification History Table
-- ============================================
CREATE TABLE IF NOT EXISTS notification_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Notification details
  notification_type VARCHAR(50) NOT NULL, -- failure, success, warning, security
  channel VARCHAR(50) NOT NULL, -- slack, github, email
  recipient VARCHAR(200),

  -- Content
  title VARCHAR(500),
  message TEXT,
  metadata JSONB,

  -- Status
  sent BOOLEAN DEFAULT FALSE,
  sent_at TIMESTAMP,
  delivery_status VARCHAR(50), -- sent, failed, pending
  error_message TEXT,

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notification_history_type ON notification_history(notification_type);
CREATE INDEX idx_notification_history_status ON notification_history(sent, delivery_status);
CREATE INDEX idx_notification_history_timestamp ON notification_history(created_at DESC);

-- ============================================
-- Useful Views for Reporting
-- ============================================

-- Build summary view
CREATE OR REPLACE VIEW v_build_summary AS
SELECT
  DATE_TRUNC('day', timestamp) AS date,
  COUNT(*) AS total_builds,
  COUNT(*) FILTER (WHERE success = TRUE) AS successful_builds,
  COUNT(*) FILTER (WHERE success = FALSE) AS failed_builds,
  ROUND(AVG(duration_seconds), 2) AS avg_duration_seconds,
  ROUND(AVG(code_coverage), 2) AS avg_coverage_percent
FROM build_metrics
GROUP BY DATE_TRUNC('day', timestamp)
ORDER BY date DESC;

-- Failure pattern summary view
CREATE OR REPLACE VIEW v_failure_summary AS
SELECT
  pattern_type,
  severity,
  COUNT(*) AS occurrence_count,
  MAX(last_seen) AS most_recent,
  COUNT(*) FILTER (WHERE auto_fixable = TRUE) AS fixable_count
FROM failure_patterns
WHERE last_seen > NOW() - INTERVAL '30 days'
GROUP BY pattern_type, severity
ORDER BY occurrence_count DESC;

-- Performance trend view
CREATE OR REPLACE VIEW v_performance_trend AS
SELECT
  benchmark_name,
  branch,
  AVG(score) AS avg_score,
  MIN(score) AS min_score,
  MAX(score) AS max_score,
  STDDEV(score) AS std_dev_score,
  COUNT(*) AS sample_count
FROM performance_baselines
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY benchmark_name, branch
ORDER BY benchmark_name, branch;

-- ============================================
-- Maintenance Functions
-- ============================================

-- Function to update failure pattern occurrence count
CREATE OR REPLACE FUNCTION update_failure_occurrence()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE failure_patterns
  SET
    occurrence_count = occurrence_count + 1,
    last_seen = NOW()
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for automatic count updates
-- CREATE TRIGGER trigger_update_failure_occurrence
--   AFTER INSERT ON failure_patterns
--   FOR EACH ROW
--   EXECUTE FUNCTION update_failure_occurrence();

-- Function to cleanup old records
CREATE OR REPLACE FUNCTION cleanup_old_records(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Delete old build metrics
  DELETE FROM build_metrics
  WHERE timestamp < NOW() - (days_to_keep || ' days')::INTERVAL;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  -- Delete old security scans
  DELETE FROM security_scans
  WHERE timestamp < NOW() - (days_to_keep || ' days')::INTERVAL;

  -- Delete old notifications
  DELETE FROM notification_history
  WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Sample Data for Testing (Optional)
-- ============================================

-- Insert a baseline for testing
INSERT INTO performance_baselines (branch, benchmark_name, benchmark_type, score, min_score, max_score, std_dev, sample_size)
VALUES
  ('main', 'app_startup_time', 'startup', 100.0, 95.0, 105.0, 3.5, 50)
ON CONFLICT (branch, benchmark_name) DO NOTHING;

-- ============================================
-- Branch History Table
-- ============================================
CREATE TABLE IF NOT EXISTS branch_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Branch details
  branch_name VARCHAR(200) NOT NULL,
  branch_type VARCHAR(50), -- feature, bugfix, hotfix, release, refactor
  base_branch VARCHAR(100) NOT NULL,

  -- Creator information
  creator VARCHAR(100),
  created_by_script BOOLEAN DEFAULT FALSE,

  -- Status
  status VARCHAR(20) DEFAULT 'active', -- active, merged, closed, stale
  commits_count INTEGER DEFAULT 0,

  -- PR tracking
  pr_number INTEGER,
  pr_url TEXT,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  last_commit_at TIMESTAMP,
  merged_at TIMESTAMP,
  closed_at TIMESTAMP,

  CONSTRAINT unique_branch UNIQUE (branch_name)
);

CREATE INDEX idx_branch_history_name ON branch_history(branch_name);
CREATE INDEX idx_branch_history_status ON branch_history(status);
CREATE INDEX idx_branch_history_created ON branch_history(created_at DESC);
CREATE INDEX idx_branch_history_type ON branch_history(branch_type);

-- ============================================
-- Automated PRs Table
-- ============================================
CREATE TABLE IF NOT EXISTS automated_prs (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- PR details
  pr_number INTEGER NOT NULL,
  pr_url TEXT NOT NULL,
  title VARCHAR(500) NOT NULL,
  body TEXT,

  -- Branch information
  source_branch VARCHAR(200) NOT NULL,
  target_branch VARCHAR(100) NOT NULL,

  -- PR type
  pr_type VARCHAR(50), -- dependency, refactor, fix, feature, release
  risk_level VARCHAR(20), -- low, medium, high, critical

  -- Status tracking
  status VARCHAR(20) DEFAULT 'open', -- open, merged, closed, draft
  mergeable BOOLEAN,
  draft BOOLEAN DEFAULT FALSE,

  -- Review tracking
  reviewers JSONB, -- Array of reviewer usernames
  required_reviewers INTEGER DEFAULT 1,
  approval_count INTEGER DEFAULT 0,

  -- Labels
  labels JSONB, -- Array of label strings

  -- Automated checks
  checks_passed BOOLEAN,
  auto_mergeable BOOLEAN,

  -- Metadata
  created_by_script VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  merged_at TIMESTAMP,
  closed_at TIMESTAMP,

  CONSTRAINT unique_pr_number UNIQUE (pr_number)
);

CREATE INDEX idx_automated_prs_number ON automated_prs(pr_number);
CREATE INDEX idx_automated_prs_status ON automated_prs(status);
CREATE INDEX idx_automated_prs_type ON automated_prs(pr_type);
CREATE INDEX idx_automated_prs_created ON automated_prs(created_at DESC);
CREATE INDEX idx_automated_prs_branch ON automated_prs(source_branch);

-- ============================================
-- Refactoring History Table
-- ============================================
CREATE TABLE IF NOT EXISTS refactoring_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Refactoring details
  refactoring_type VARCHAR(100) NOT NULL, -- rename, move, extract, inline, etc.
  description TEXT,

  -- Scope
  affected_files JSONB, -- Array of file paths
  lines_changed INTEGER,

  -- Safety assessment
  risk_level VARCHAR(20) DEFAULT 'low', -- low, medium, high
  safe_transformation BOOLEAN DEFAULT TRUE,

  -- PR tracking
  branch_name VARCHAR(200),
  pr_number INTEGER,
  pr_url TEXT,

  -- Status
  status VARCHAR(20) DEFAULT 'pending', -- pending, applied, tested, merged, failed
  compilation_success BOOLEAN,
  tests_passed BOOLEAN,

  -- Metadata
  spec_file TEXT, -- Path to YAML/JSON spec file
  created_by_script VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  applied_at TIMESTAMP,
  merged_at TIMESTAMP
);

CREATE INDEX idx_refactoring_history_type ON refactoring_history(refactoring_type);
CREATE INDEX idx_refactoring_history_status ON refactoring_history(status);
CREATE INDEX idx_refactoring_history_created ON refactoring_history(created_at DESC);

-- ============================================
-- Pre-commit Checks Table
-- ============================================
CREATE TABLE IF NOT EXISTS pre_commit_checks (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Git information
  commit_sha VARCHAR(40) NOT NULL,
  branch VARCHAR(100) NOT NULL,

  -- Check details
  check_type VARCHAR(50) NOT NULL, -- format, lint, tests, secrets
  status VARCHAR(20) NOT NULL, -- passed, failed, skipped

  -- Performance metrics
  duration_ms INTEGER,
  exit_code INTEGER,

  -- Results
  output TEXT,
  findings JSONB,

  -- Timestamp
  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_pre_commit_check UNIQUE (commit_sha, branch, check_type)
);

CREATE INDEX idx_pre_commit_checks_commit ON pre_commit_checks(commit_sha);
CREATE INDEX idx_pre_commit_checks_branch ON pre_commit_checks(branch);
CREATE INDEX idx_pre_commit_checks_type ON pre_commit_checks(check_type);
CREATE INDEX idx_pre_commit_checks_status ON pre_commit_checks(status);
CREATE INDEX idx_pre_commit_checks_timestamp ON pre_commit_checks(timestamp DESC);

-- ============================================
-- Grants (adjust as needed)
-- ============================================

-- Grant access to Woodpecker database user
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO woodpecker;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO woodpecker;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO woodpecker;
