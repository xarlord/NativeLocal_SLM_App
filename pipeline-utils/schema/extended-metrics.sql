-- Extended Woodpecker CI Metrics Database Schema
-- Autonomous development features tracking
-- Adds 14 new tables for release management, pre-commit checks, automated PRs,
-- branch lifecycle, issue triage, visual regression, API contracts, test flakiness,
-- performance benchmarks, generated tests, code reviews, developer metrics,
-- risk assessments, and file risk predictions

-- ============================================
-- Release History Table
-- Tracks all releases with versioning, artifacts, and deployment status
-- ============================================
CREATE TABLE IF NOT EXISTS release_history (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Release identification
  version VARCHAR(50) NOT NULL,
  build_number VARCHAR(50),
  commit_sha VARCHAR(40),
  branch VARCHAR(100),

  -- Release classification
  release_type VARCHAR(20) NOT NULL CHECK (release_type IN ('major', 'minor', 'patch', 'hotfix')),

  -- Release details
  changelog TEXT,
  artifacts JSONB, -- {apk_url, aab_url, checksums, size_mb}

  -- Release URLs
  github_release_url TEXT,
  play_store_url TEXT,
  app_store_url TEXT,

  -- Release lifecycle
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'published', 'rolled_back', 'failed')),

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  published_at TIMESTAMP,
  rolled_back_at TIMESTAMP,

  CONSTRAINT unique_release_version UNIQUE (version)
);

CREATE INDEX idx_release_history_version ON release_history(version DESC);
CREATE INDEX idx_release_history_type ON release_history(release_type);
CREATE INDEX idx_release_history_status ON release_history(status);
CREATE INDEX idx_release_history_timestamp ON release_history(created_at DESC);
CREATE INDEX idx_release_history_build ON release_history(build_id);

-- ============================================
-- Pre-commit Checks Table
-- Tracks pre-commit hook execution results for quality gates
-- ============================================
CREATE TABLE IF NOT EXISTS pre_commit_checks (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Commit information
  developer VARCHAR(100) NOT NULL,
  commit_sha VARCHAR(40) NOT NULL,
  branch VARCHAR(100),

  -- Hook execution results
  hook_results JSONB NOT NULL, -- {format: {passed, duration_ms}, lint: {...}, tests: {...}, secrets: {...}}

  -- Summary metrics
  total_duration_ms INTEGER,
  hooks_passed INTEGER DEFAULT 0,
  hooks_failed INTEGER DEFAULT 0,
  hooks_total INTEGER DEFAULT 0,

  -- Overall status
  passed BOOLEAN NOT NULL DEFAULT TRUE,

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_pre_commit UNIQUE (commit_sha, developer)
);

CREATE INDEX idx_pre_commit_checks_timestamp ON pre_commit_checks(timestamp DESC);
CREATE INDEX idx_pre_commit_checks_developer ON pre_commit_checks(developer);
CREATE INDEX idx_pre_commit_checks_passed ON pre_commit_checks(passed);
CREATE INDEX idx_pre_commit_checks_commit ON pre_commit_checks(commit_sha);

-- ============================================
-- Automated PRs Table
-- Tracks auto-created pull requests for dependencies, refactoring, etc.
-- ============================================
CREATE TABLE IF NOT EXISTS automated_prs (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- PR identification
  pr_number INTEGER,
  title VARCHAR(500) NOT NULL,
  source_branch VARCHAR(100) NOT NULL,
  target_branch VARCHAR(100) DEFAULT 'main',

  -- PR classification
  pr_type VARCHAR(20) NOT NULL CHECK (pr_type IN ('dependency', 'refactor', 'docs', 'chore', 'security')),

  -- Automation details
  creator_script VARCHAR(100),
  creator_version VARCHAR(50),

  -- PR lifecycle
  status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'merged', 'closed', 'draft')),

  -- URLs and metadata
  github_url TEXT,
  metadata JSONB, -- {files_changed, insertions, deletions, dependencies_updated}

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  merged_at TIMESTAMP,
  closed_at TIMESTAMP,

  CONSTRAINT unique_automated_pr UNIQUE (pr_number)
);

CREATE INDEX idx_automated_prs_pr_number ON automated_prs(pr_number);
CREATE INDEX idx_automated_prs_type ON automated_prs(pr_type);
CREATE INDEX idx_automated_prs_status ON automated_prs(status);
CREATE INDEX idx_automated_prs_timestamp ON automated_prs(created_at DESC);

-- ============================================
-- Branch History Table
-- Tracks branch lifecycle, activity, and status
-- ============================================
CREATE TABLE IF NOT EXISTS branch_history (
  id SERIAL PRIMARY KEY,

  -- Branch identification
  branch_name VARCHAR(100) NOT NULL,
  creator VARCHAR(100),
  created_from_branch VARCHAR(100),
  created_from_commit VARCHAR(40),

  -- Branch activity
  commit_count INTEGER DEFAULT 0,
  last_commit_sha VARCHAR(40),
  last_commit_date TIMESTAMP,

  -- Contributors
  contributors JSONB, -- [{username, commits_count}]

  -- Branch lifecycle
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'stale', 'merged', 'deleted')),

  -- Merge information
  merged_into VARCHAR(100),
  merged_at TIMESTAMP,
  merged_by VARCHAR(100),

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_branch UNIQUE (branch_name)
);

CREATE INDEX idx_branch_history_name ON branch_history(branch_name);
CREATE INDEX idx_branch_history_status ON branch_history(status);
CREATE INDEX idx_branch_history_creator ON branch_history(creator);
CREATE INDEX idx_branch_history_timestamp ON branch_history(timestamp DESC);

-- ============================================
-- Issue Triage Table
-- Tracks issue classification, labeling, and assignment
-- ============================================
CREATE TABLE IF NOT EXISTS issue_triage (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Issue identification
  issue_number INTEGER NOT NULL,
  title VARCHAR(500) NOT NULL,
  issue_url TEXT,

  -- Triage information
  classifier VARCHAR(100), -- bot or username who performed triage
  classifier_version VARCHAR(50),

  -- Labels and categorization
  labels JSONB, -- {bug, enhancement, documentation, priority:high, area:ui}

  -- Duplicate detection
  duplicate_of_issue INTEGER,
  duplicate_confidence NUMERIC(3,2),

  -- Assignment
  assigned_to VARCHAR(100),
  assignment_confidence NUMERIC(3,2),

  -- Complexity estimation
  complexity_estimate VARCHAR(20) CHECK (complexity_estimate IN ('trivial', 'low', 'medium', 'high', 'complex')),
  complexity_score NUMERIC(3,2), -- 0.0 to 1.0

  -- Status
  status VARCHAR(20) DEFAULT 'triaged' CHECK (status IN ('pending', 'triaged', 'assigned', 'closed')),

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_issue UNIQUE (issue_number)
);

CREATE INDEX idx_issue_triage_issue_number ON issue_triage(issue_number);
CREATE INDEX idx_issue_triage_status ON issue_triage(status);
CREATE INDEX idx_issue_triage_assigned ON issue_triage(assigned_to);
CREATE INDEX idx_issue_triage_complexity ON issue_triage(complexity_estimate);
CREATE INDEX idx_issue_triage_timestamp ON issue_triage(timestamp DESC);

-- ============================================
-- Visual Regression Tests Table
-- Tracks screenshot comparison results for UI testing
-- ============================================
CREATE TABLE IF NOT EXISTS visual_regression_tests (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Test identification
  test_name VARCHAR(200) NOT NULL,
  screen_name VARCHAR(200) NOT NULL,

  -- Image paths
  screenshot_path TEXT NOT NULL,
  baseline_path TEXT NOT NULL,
  diff_path TEXT,

  -- Comparison metrics
  diff_score NUMERIC(5,2), -- 0.0 to 100.0 (percentage difference)
  pixel_diff_count INTEGER,
  pixel_diff_threshold INTEGER DEFAULT 100,

  -- Test result
  passed BOOLEAN NOT NULL DEFAULT TRUE,
  failure_reason TEXT,

  -- Environment
  device VARCHAR(100), -- pixel_6, iphone_14, tablet, etc.
  screen_density VARCHAR(50), -- xxxhdpi, xxhdpi, etc.
  theme VARCHAR(20), -- light, dark
  orientation VARCHAR(10), -- portrait, landscape

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_visual_regression_tests_build ON visual_regression_tests(build_id);
CREATE INDEX idx_visual_regression_tests_passed ON visual_regression_tests(passed);
CREATE INDEX idx_visual_regression_tests_screen ON visual_regression_tests(screen_name);
CREATE INDEX idx_visual_regression_tests_diff_score ON visual_regression_tests(diff_score);
CREATE INDEX idx_visual_regression_tests_timestamp ON visual_regression_tests(timestamp DESC);

-- ============================================
-- API Contracts Table
-- Tracks API contract changes and breaking changes detection
-- ============================================
CREATE TABLE IF NOT EXISTS api_contracts (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Contract identification
  contract_id VARCHAR(100) NOT NULL,
  endpoint VARCHAR(500) NOT NULL,
  method VARCHAR(10) NOT NULL CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')),

  -- Contract versions
  old_hash VARCHAR(64), -- SHA256 of old contract
  new_hash VARCHAR(64), -- SHA256 of new contract

  -- Change detection
  breaking_change BOOLEAN DEFAULT FALSE,
  breaking_change_details TEXT,
  severity VARCHAR(20) CHECK (severity IN ('critical', 'major', 'minor', 'patch')),

  -- Change classification
  change_type VARCHAR(50), -- endpoint_added, endpoint_removed, parameter_added, etc.
  changes_summary JSONB, -- {parameters, response_body, authentication, headers}

  -- Status
  status VARCHAR(20) DEFAULT 'detected' CHECK (status IN ('detected', 'approved', 'rejected', 'deployed')),

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_api_contracts_contract_id ON api_contracts(contract_id);
CREATE INDEX idx_api_contracts_endpoint ON api_contracts(endpoint, method);
CREATE INDEX idx_api_contracts_breaking ON api_contracts(breaking_change) WHERE breaking_change = TRUE;
CREATE INDEX idx_api_contracts_severity ON api_contracts(severity);
CREATE INDEX idx_api_contracts_timestamp ON api_contracts(timestamp DESC);

-- ============================================
-- Test Flakiness Table
-- Tracks flaky test detection and quarantine status
-- ============================================
CREATE TABLE IF NOT EXISTS test_flakiness (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Test identification
  test_name VARCHAR(200) NOT NULL,
  test_class VARCHAR(200),
  test_file VARCHAR(500),
  test_suite VARCHAR(100),

  -- Flakiness metrics
  flakiness_score NUMERIC(5,2) NOT NULL, -- 0.0 to 100.0 (percentage of non-deterministic failures)
  failure_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  total_runs INTEGER DEFAULT 0,

  -- Failure analysis
  last_failure_reason TEXT,
  last_failure_stack_trace TEXT,
  last_failure_date TIMESTAMP,

  -- Failure patterns
  failure_modes JSONB, -- [{reason, count, first_seen}]

  -- Quarantine management
  quarantine_status VARCHAR(20) DEFAULT 'none' CHECK (quarantine_status IN ('none', 'investigating', 'quarantined', 'fixed')),
  quarantine_reason TEXT,
  quarantine_since TIMESTAMP,

  -- Related issues
  bug_issue_number INTEGER,

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_flaky_test UNIQUE (test_name, test_class)
);

CREATE INDEX idx_test_flakiness_score ON test_flakiness(flakiness_score DESC);
CREATE INDEX idx_test_flakiness_quarantine ON test_flakiness(quarantine_status);
CREATE INDEX idx_test_flakiness_name ON test_flakiness(test_name);
CREATE INDEX idx_test_flakiness_timestamp ON test_flakiness(timestamp DESC);

-- ============================================
-- Performance Benchmarks Table
-- Tracks performance benchmark results and regression detection
-- ============================================
CREATE TABLE IF NOT EXISTS performance_benchmarks (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE CASCADE,

  -- Benchmark identification
  benchmark_name VARCHAR(100) NOT NULL,
  benchmark_category VARCHAR(50), -- startup, ui_rendering, database, api, memory

  -- Branch context
  branch VARCHAR(100) NOT NULL,
  commit_sha VARCHAR(40),

  -- Performance metrics
  score NUMERIC(10,2) NOT NULL, -- primary metric (e.g., time in ms, operations per second)
  unit VARCHAR(20), -- ms, ops/sec, MB, etc.

  -- Comparison to baseline
  baseline_score NUMERIC(10,2),
  baseline_commit_sha VARCHAR(40),

  -- Change detection
  regression_detected BOOLEAN DEFAULT FALSE,
  regression_percentage NUMERIC(5,2),
  improvement_detected BOOLEAN DEFAULT FALSE,
  improvement_percentage NUMERIC(5,2),

  -- Threshold settings
  regression_threshold NUMERIC(5,2) DEFAULT 10.0, -- percentage
  improvement_threshold NUMERIC(5,2) DEFAULT 5.0,

  -- Additional metrics
  metrics_data JSONB, -- {min, max, median, p95, p99, std_dev}

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_performance_benchmarks_name ON performance_benchmarks(benchmark_name);
CREATE INDEX idx_performance_benchmarks_branch ON performance_benchmarks(branch);
CREATE INDEX idx_performance_benchmarks_regression ON performance_benchmarks(regression_detected) WHERE regression_detected = TRUE;
CREATE INDEX idx_performance_benchmarks_timestamp ON performance_benchmarks(timestamp DESC);

-- ============================================
-- Generated Tests Table
-- Tracks AI-generated tests and review status
-- ============================================
CREATE TABLE IF NOT EXISTS generated_tests (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Test identification
  test_name VARCHAR(200) NOT NULL,
  test_class VARCHAR(200),
  source_file VARCHAR(500) NOT NULL,

  -- Generation details
  generator_version VARCHAR(50) NOT NULL, -- AI model version
  generator_type VARCHAR(50), -- unit_test, integration_test, ui_test

  -- Test generation metrics
  confidence_score NUMERIC(3,2), -- 0.0 to 1.0
  coverage_targeted NUMERIC(5,2), -- percentage of code coverage targeted

  -- Generated code
  code TEXT NOT NULL,
  language VARCHAR(20), -- kotlin, java, python, etc.
  framework VARCHAR(50), -- junit, pytest, espresso, etc.

  -- Review status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'accepted', 'rejected', 'modified')),

  -- Review information
  reviewed_by VARCHAR(100),
  review_comments TEXT,
  modified_code TEXT,

  -- Integration
  integrated BOOLEAN DEFAULT FALSE,
  integration_commit_sha VARCHAR(40),

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_generated_tests_status ON generated_tests(status);
CREATE INDEX idx_generated_tests_source_file ON generated_tests(source_file);
CREATE INDEX idx_generated_tests_confidence ON generated_tests(confidence_score DESC);
CREATE INDEX idx_generated_tests_timestamp ON generated_tests(timestamp DESC);

-- ============================================
-- Code Reviews Table
-- Tracks AI and human code review metrics
-- ============================================
CREATE TABLE IF NOT EXISTS code_reviews (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- PR identification
  pr_number INTEGER NOT NULL,
  pr_title VARCHAR(500),
  pr_author VARCHAR(100),

  -- Reviewer information
  reviewer_type VARCHAR(10) NOT NULL CHECK (reviewer_type IN ('ai', 'human')),
  reviewer_name VARCHAR(100),

  -- Review metrics
  quality_score NUMERIC(3,2), -- 0.0 to 1.0
  complexity_score NUMERIC(3,2),
  maintainability_score NUMERIC(3,2),

  -- Review activity
  suggestions_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  blocking_issues_count INTEGER DEFAULT 0,

  -- Review outcome
  approval_status VARCHAR(20) CHECK (approval_status IN ('approved', 'requested_changes', 'commented', 'pending')),

  -- Review details
  review_comments JSONB, -- [{file_path, line, comment, severity, type}]
  files_reviewed INTEGER,
  lines_added INTEGER,
  lines_deleted INTEGER,

  -- Time metrics
  review_duration_minutes INTEGER,

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_review UNIQUE (pr_number, reviewer_type, reviewer_name)
);

CREATE INDEX idx_code_reviews_pr_number ON code_reviews(pr_number);
CREATE INDEX idx_code_reviews_reviewer_type ON code_reviews(reviewer_type);
CREATE INDEX idx_code_reviews_approval ON code_reviews(approval_status);
CREATE INDEX idx_code_reviews_quality ON code_reviews(quality_score);
CREATE INDEX idx_code_reviews_timestamp ON code_reviews(timestamp DESC);

-- ============================================
-- Developer Metrics Table
-- Tracks developer productivity and contribution metrics
-- ============================================
CREATE TABLE IF NOT EXISTS developer_metrics (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Developer identification
  developer VARCHAR(100) NOT NULL,

  -- Period
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  period_type VARCHAR(20) DEFAULT 'weekly', -- daily, weekly, monthly, sprint

  -- Contribution metrics
  commits_count INTEGER DEFAULT 0,
  prs_created INTEGER DEFAULT 0,
  prs_reviewed INTEGER DEFAULT 0,
  prs_merged INTEGER DEFAULT 0,
  issues_closed INTEGER DEFAULT 0,
  issues_opened INTEGER DEFAULT 0,

  -- Code quality metrics
  code_velocity INTEGER DEFAULT 0, -- lines of code added/removed
  test_coverage_delta NUMERIC(5,2), -- change in test coverage percentage
  code_churn INTEGER DEFAULT 0, -- percentage of code rewritten

  -- Review metrics
  avg_review_time_hours NUMERIC(5,2),
  review_comments_given INTEGER DEFAULT 0,
  review_comments_received INTEGER DEFAULT 0,

  -- Additional metrics
  metrics_data JSONB, -- {languages_used, modules_touched, bug_introductions, bug_fixes}

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_developer_period UNIQUE (developer, period_start, period_end, period_type)
);

CREATE INDEX idx_developer_metrics_developer ON developer_metrics(developer);
CREATE INDEX idx_developer_metrics_period ON developer_metrics(period_start, period_end);
CREATE INDEX idx_developer_metrics_commits ON developer_metrics(commits_count DESC);
CREATE INDEX idx_developer_metrics_timestamp ON developer_metrics(timestamp DESC);

-- ============================================
-- Risk Assessments Table
-- Tracks overall risk predictions for branches and deployments
-- ============================================
CREATE TABLE IF NOT EXISTS risk_assessments (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- Assessment context
  assessment_date DATE NOT NULL,
  branch VARCHAR(100) NOT NULL,
  commit_sha VARCHAR(40),
  commit_count_since_base INTEGER DEFAULT 0,

  -- Overall risk
  overall_risk_score NUMERIC(3,2) NOT NULL, -- 0.0 to 1.0
  risk_level VARCHAR(20) CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),

  -- Risk factors
  risk_factors JSONB NOT NULL, -- {code_churn, new_contributors, test_coverage, complexity, security_issues}
  factor_scores JSONB, -- {code_churn: 0.8, test_coverage: 0.3, ...}

  -- Specific risks
  breaking_changes_count INTEGER DEFAULT 0,
  failing_tests_count INTEGER DEFAULT 0,
  security_issues_count INTEGER DEFAULT 0,
  flaky_tests_count INTEGER DEFAULT 0,

  -- Mitigation
  mitigation_suggestions JSONB, -- [{type, description, priority}]
  requires_review BOOLEAN DEFAULT FALSE,
  blocked BOOLEAN DEFAULT FALSE,
  block_reason TEXT,

  -- Model information
  model_version VARCHAR(50),
  model_confidence NUMERIC(3,2),

  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_risk_assessments_branch ON risk_assessments(branch);
CREATE INDEX idx_risk_assessments_date ON risk_assessments(assessment_date DESC);
CREATE INDEX idx_risk_assessments_score ON risk_assessments(overall_risk_score DESC);
CREATE INDEX idx_risk_assessments_level ON risk_assessments(risk_level);
CREATE INDEX idx_risk_assessments_blocked ON risk_assessments(blocked) WHERE blocked = TRUE;

-- ============================================
-- File Risk Predictions Table
-- Tracks file-level bug risk predictions
-- ============================================
CREATE TABLE IF NOT EXISTS file_risk_predictions (
  id SERIAL PRIMARY KEY,
  build_id INTEGER REFERENCES build_metrics(id) ON DELETE SET NULL,

  -- File identification
  file_path VARCHAR(500) NOT NULL,
  file_hash VARCHAR(64), -- SHA256 hash of file content
  file_type VARCHAR(50), -- kotlin, java, xml, etc.
  module VARCHAR(100),

  -- Branch context
  branch VARCHAR(100) NOT NULL,
  commit_sha VARCHAR(40),

  -- Risk prediction
  risk_score NUMERIC(3,2) NOT NULL, -- 0.0 to 1.0
  bug_probability NUMERIC(3,2) NOT NULL, -- 0.0 to 1.0

  -- Risk factors
  factors JSONB, -- {complexity, churn, authors, age, test_coverage, dependencies}

  -- Code metrics
  lines_of_code INTEGER,
  cyclomatic_complexity INTEGER,
  function_count INTEGER,
  class_count INTEGER,

  -- Change metrics
  authors_count INTEGER,
  commit_count INTEGER,
  last_commit_date TIMESTAMP,
  days_since_last_change INTEGER,

  -- Test coverage
  test_coverage NUMERIC(5,2),
  has_tests BOOLEAN DEFAULT FALSE,

  -- Related issues
  linked_bugs INTEGER[], -- Array of issue numbers
  bug_count INTEGER DEFAULT 0,

  -- Model information
  model_version VARCHAR(50),
  model_confidence NUMERIC(3,2),

  timestamp TIMESTAMP DEFAULT NOW(),

  CONSTRAINT unique_file_branch UNIQUE (file_path, branch, commit_sha)
);

CREATE INDEX idx_file_risk_predictions_file_path ON file_risk_predictions(file_path);
CREATE INDEX idx_file_risk_predictions_branch ON file_risk_predictions(branch);
CREATE INDEX idx_file_risk_predictions_score ON file_risk_predictions(risk_score DESC);
CREATE INDEX idx_file_risk_predictions_probability ON file_risk_predictions(bug_probability DESC);
CREATE INDEX idx_file_risk_predictions_timestamp ON file_risk_predictions(timestamp DESC);
CREATE INDEX idx_file_risk_predictions_bug_count ON file_risk_predictions(bug_count DESC);

-- ============================================
-- Summary Views for Reporting
-- ============================================

-- Release history summary
CREATE OR REPLACE VIEW v_release_summary AS
SELECT
  DATE_TRUNC('month', created_at) AS month,
  release_type,
  COUNT(*) AS release_count,
  COUNT(*) FILTER (WHERE status = 'published') AS published_count,
  COUNT(*) FILTER (WHERE status = 'rolled_back') AS rolled_back_count,
  MAX(version) AS latest_version
FROM release_history
GROUP BY DATE_TRUNC('month', created_at), release_type
ORDER BY month DESC, release_type;

-- Pre-commit checks summary
CREATE OR REPLACE VIEW v_pre_commit_summary AS
SELECT
  developer,
  DATE_TRUNC('day', timestamp) AS date,
  COUNT(*) AS total_checks,
  COUNT(*) FILTER (WHERE passed = TRUE) AS passed_checks,
  COUNT(*) FILTER (WHERE passed = FALSE) AS failed_checks,
  ROUND(AVG(total_duration_ms), 2) AS avg_duration_ms,
  ROUND(AVG(hooks_passed)::numeric, 2) AS avg_hooks_passed
FROM pre_commit_checks
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY developer, DATE_TRUNC('day', timestamp)
ORDER BY date DESC, developer;

-- Automated PRs summary
CREATE OR REPLACE VIEW v_automated_pr_summary AS
SELECT
  pr_type,
  status,
  COUNT(*) AS pr_count,
  COUNT(*) FILTER (WHERE status = 'merged') AS merged_count,
  COUNT(*) FILTER (WHERE status = 'open') AS open_count,
  MIN(created_at) AS oldest_open,
  MAX(created_at) AS latest_created
FROM automated_prs
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY pr_type, status
ORDER BY pr_type, status;

-- Branch lifecycle summary
CREATE OR REPLACE VIEW v_branch_lifecycle_summary AS
SELECT
  status,
  COUNT(*) AS branch_count,
  AVG(commit_count) AS avg_commits,
  MAX(last_commit_date) AS most_recent_activity
FROM branch_history
WHERE timestamp > NOW() - INTERVAL '60 days'
GROUP BY status
ORDER BY status;

-- Issue triage summary
CREATE OR REPLACE VIEW v_issue_triage_summary AS
SELECT
  DATE_TRUNC('week', timestamp) AS week,
  complexity_estimate,
  COUNT(*) AS issue_count,
  COUNT(*) FILTER (WHERE status = 'assigned') AS assigned_count,
  COUNT(*) FILTER (WHERE status = 'closed') AS closed_count
FROM issue_triage
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY DATE_TRUNC('week', timestamp), complexity_estimate
ORDER BY week DESC, complexity_estimate;

-- Visual regression summary
CREATE OR REPLACE VIEW v_visual_regression_summary AS
SELECT
  DATE_TRUNC('day', timestamp) AS date,
  screen_name,
  device,
  COUNT(*) AS test_count,
  COUNT(*) FILTER (WHERE passed = FALSE) AS failed_count,
  ROUND(AVG(diff_score), 2) AS avg_diff_score
FROM visual_regression_tests
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', timestamp), screen_name, device
ORDER BY date DESC, screen_name;

-- API contracts summary
CREATE OR REPLACE VIEW v_api_contracts_summary AS
SELECT
  DATE_TRUNC('week', timestamp) AS week,
  breaking_change,
  severity,
  COUNT(*) AS change_count,
  COUNT(DISTINCT endpoint) AS unique_endpoints
FROM api_contracts
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY DATE_TRUNC('week', timestamp), breaking_change, severity
ORDER BY week DESC, breaking_change, severity;

-- Test flakiness summary
CREATE OR REPLACE VIEW v_test_flakiness_summary AS
SELECT
  quarantine_status,
  COUNT(*) AS test_count,
  ROUND(AVG(flakiness_score), 2) AS avg_flakiness_score,
  AVG(failure_count) AS avg_failure_count,
  MAX(last_failure_date) AS most_recent_failure
FROM test_flakiness
WHERE timestamp > NOW() - INTERVAL '60 days'
GROUP BY quarantine_status
ORDER BY quarantine_status;

-- Performance benchmarks summary
CREATE OR REPLACE VIEW v_performance_benchmarks_summary AS
SELECT
  benchmark_name,
  branch,
  COUNT(*) AS run_count,
  ROUND(AVG(score), 2) AS avg_score,
  MIN(score) AS min_score,
  MAX(score) AS max_score,
  COUNT(*) FILTER (WHERE regression_detected = TRUE) AS regression_count,
  COUNT(*) FILTER (WHERE improvement_detected = TRUE) AS improvement_count
FROM performance_benchmarks
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY benchmark_name, branch
ORDER BY benchmark_name, branch;

-- Generated tests summary
CREATE OR REPLACE VIEW v_generated_tests_summary AS
SELECT
  generator_version,
  status,
  COUNT(*) AS test_count,
  ROUND(AVG(confidence_score), 2) AS avg_confidence,
  COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_count,
  COUNT(*) FILTER (WHERE integrated = TRUE) AS integrated_count
FROM generated_tests
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY generator_version, status
ORDER BY generator_version, status;

-- Code reviews summary
CREATE OR REPLACE VIEW v_code_reviews_summary AS
SELECT
  reviewer_type,
  DATE_TRUNC('week', timestamp) AS week,
  COUNT(*) AS review_count,
  ROUND(AVG(quality_score), 2) AS avg_quality_score,
  AVG(suggestions_count) AS avg_suggestions,
  COUNT(*) FILTER (WHERE approval_status = 'approved') AS approved_count,
  ROUND(AVG(review_duration_minutes), 2) AS avg_duration_minutes
FROM code_reviews
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY reviewer_type, DATE_TRUNC('week', timestamp)
ORDER BY week DESC, reviewer_type;

-- Developer metrics summary
CREATE OR REPLACE VIEW v_developer_metrics_summary AS
SELECT
  developer,
  period_start,
  period_end,
  commits_count,
  prs_created,
  prs_reviewed,
  code_velocity,
  test_coverage_delta
FROM developer_metrics
WHERE timestamp > NOW() - INTERVAL '120 days'
ORDER BY period_start DESC, commits_count DESC;

-- Risk assessments summary
CREATE OR REPLACE VIEW v_risk_assessments_summary AS
SELECT
  DATE_TRUNC('week', assessment_date) AS week,
  branch,
  AVG(overall_risk_score) AS avg_risk_score,
  COUNT(*) AS assessment_count,
  COUNT(*) FILTER (WHERE risk_level = 'high') AS high_risk_count,
  COUNT(*) FILTER (WHERE risk_level = 'critical') AS critical_risk_count,
  COUNT(*) FILTER (WHERE blocked = TRUE) AS blocked_count
FROM risk_assessments
WHERE timestamp > NOW() - INTERVAL '90 days'
GROUP BY DATE_TRUNC('week', assessment_date), branch
ORDER BY week DESC, branch;

-- File risk predictions summary
CREATE OR REPLACE VIEW v_file_risk_summary AS
SELECT
  file_type,
  branch,
  COUNT(*) AS file_count,
  ROUND(AVG(risk_score), 2) AS avg_risk_score,
  ROUND(AVG(bug_probability), 2) AS avg_bug_probability,
  SUM(bug_count) AS total_bugs,
  AVG(lines_of_code) AS avg_loc
FROM file_risk_predictions
WHERE timestamp > NOW() - INTERVAL '60 days'
GROUP BY file_type, branch
ORDER BY avg_risk_score DESC, file_type, branch;

-- ============================================
-- Helpful Functions
-- ============================================

-- Function to calculate flakiness score
CREATE OR REPLACE FUNCTION calculate_flakiness_score(
  p_failure_count INTEGER,
  p_total_runs INTEGER
)
RETURNS NUMERIC AS $$
BEGIN
  IF p_total_runs = 0 THEN
    RETURN 0.0;
  END IF;
  RETURN ROUND((p_failure_count::NUMERIC / p_total_runs::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql;

-- Function to update branch status based on last commit date
CREATE OR REPLACE FUNCTION update_branch_status()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE branch_history
  SET
    status = CASE
      WHEN NEW.last_commit_date < NOW() - INTERVAL '30 days' THEN 'stale'
      WHEN NEW.last_commit_date >= NOW() - INTERVAL '30 days' THEN 'active'
      ELSE status
    END
  WHERE branch_name = NEW.branch_name;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Grants (adjust as needed)
-- ============================================

-- Grant access to Woodpecker database user
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO woodpecker;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO woodpecker;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO woodpecker;
