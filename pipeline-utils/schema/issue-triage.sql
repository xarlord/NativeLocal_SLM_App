-- Issue Triage Database Schema Extension
-- Adds tables for issue classification, duplicate detection, assignment, and complexity tracking

-- ============================================
-- Issue Classification Tracking
-- ============================================
CREATE TABLE IF NOT EXISTS issue_triage (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL UNIQUE,
    classification VARCHAR(50) NOT NULL,
    confidence NUMERIC(3,2),
    labels TEXT[],
    classified_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_triage_classification ON issue_triage(classification);
CREATE INDEX IF NOT EXISTS idx_issue_triage_classified_at ON issue_triage(classified_at DESC);

-- ============================================
-- Issue Duplicate Detection
-- ============================================
CREATE TABLE IF NOT EXISTS issue_duplicates (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    duplicate_of INTEGER NOT NULL,
    similarity_score NUMERIC(3,2) NOT NULL,
    detected_at TIMESTAMP DEFAULT NOW(),
    confirmed BOOLEAN DEFAULT NULL,
    confirmed_by VARCHAR(100),
    UNIQUE(issue_number, duplicate_of)
);

CREATE INDEX IF NOT EXISTS idx_issue_duplicates_issue_number ON issue_duplicates(issue_number);
CREATE INDEX IF NOT EXISTS idx_issue_duplicates_duplicate_of ON issue_duplicates(duplicate_of);
CREATE INDEX IF NOT EXISTS idx_issue_duplicates_similarity ON issue_duplicates(similarity_score DESC);
CREATE INDEX IF NOT EXISTS idx_issue_duplicates_detected_at ON issue_duplicates(detected_at DESC);

-- ============================================
-- Issue Assignment Tracking
-- ============================================
CREATE TABLE IF NOT EXISTS issue_assignments (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    assigned_to VARCHAR(100) NOT NULL,
    assignment_method VARCHAR(50) NOT NULL,
    file_pattern VARCHAR(500),
    assigned_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(issue_number, assigned_to)
);

CREATE INDEX IF NOT EXISTS idx_issue_assignments_issue_number ON issue_assignments(issue_number);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_assigned_to ON issue_assignments(assigned_to);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_method ON issue_assignments(assignment_method);
CREATE INDEX IF NOT EXISTS idx_issue_assignments_assigned_at ON issue_assignments(assigned_at DESC);

-- ============================================
-- Issue Complexity Estimation
-- ============================================
CREATE TABLE IF NOT EXISTS issue_complexity (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL UNIQUE,
    issue_title TEXT,
    complexity_score INTEGER NOT NULL,
    lines_estimate INTEGER,
    files_estimate INTEGER,
    keyword_score INTEGER,
    historical_avg INTEGER,
    estimated_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_complexity_score ON issue_complexity(complexity_score);
CREATE INDEX IF NOT EXISTS idx_issue_complexity_estimated_at ON issue_complexity(estimated_at DESC);

-- ============================================
-- Issue-Commit Linking
-- ============================================
CREATE TABLE IF NOT EXISTS issue_commits (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER NOT NULL,
    commit_hash VARCHAR(40) NOT NULL,
    commit_url TEXT,
    commit_message TEXT,
    commit_author VARCHAR(200),
    commit_date TIMESTAMP,
    closes_issue BOOLEAN DEFAULT FALSE,
    linked_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(issue_number, commit_hash)
);

CREATE INDEX IF NOT EXISTS idx_issue_commits_issue_number ON issue_commits(issue_number);
CREATE INDEX IF NOT EXISTS idx_issue_commits_commit_hash ON issue_commits(commit_hash);
CREATE INDEX IF NOT EXISTS idx_issue_commits_closes ON issue_commits(closes_issue) WHERE closes_issue = TRUE;
CREATE INDEX IF NOT EXISTS idx_issue_commits_linked_at ON issue_commits(linked_at DESC);

-- ============================================
-- Useful Views for Issue Triage
-- ============================================

-- Classification summary view
CREATE OR REPLACE VIEW v_issue_classification_summary AS
SELECT
    classification,
    COUNT(*) as total_issues,
    ROUND(AVG(confidence)::numeric, 2) as avg_confidence,
    MAX(classified_at) as last_classified
FROM issue_triage
WHERE classified_at > NOW() - INTERVAL '30 days'
GROUP BY classification
ORDER BY total_issues DESC;

-- Duplicate detection summary view
CREATE OR REPLACE VIEW v_duplicate_detection_summary AS
SELECT
    DATE_TRUNC('day', detected_at) as date,
    COUNT(*) as duplicates_found,
    ROUND(AVG(similarity_score)::numeric, 2) as avg_similarity,
    COUNT(*) FILTER (WHERE confirmed = TRUE) as confirmed_count
FROM issue_duplicates
WHERE detected_at > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', detected_at)
ORDER BY date DESC;

-- Assignment summary view
CREATE OR REPLACE VIEW v_assignment_summary AS
SELECT
    assigned_to,
    assignment_method,
    COUNT(*) as total_assignments,
    MAX(assigned_at) as last_assignment
FROM issue_assignments
WHERE assigned_at > NOW() - INTERVAL '30 days'
GROUP BY assigned_to, assignment_method
ORDER BY total_assignments DESC;

-- Complexity distribution view
CREATE OR REPLACE VIEW v_complexity_distribution AS
SELECT
    complexity_score,
    COUNT(*) as total_issues,
    ROUND(AVG(lines_estimate)) as avg_lines,
    ROUND(AVG(files_estimate), 1) as avg_files
FROM issue_complexity
WHERE estimated_at > NOW() - INTERVAL '30 days'
GROUP BY complexity_score
ORDER BY complexity_score;

-- Recent issue activity view
CREATE OR REPLACE VIEW v_recent_issue_activity AS
SELECT
    'classified' as activity_type,
    issue_number,
    classified_at as activity_date,
    classification as details
FROM issue_triage
UNION ALL
SELECT
    'assigned' as activity_type,
    issue_number,
    assigned_at as activity_date,
    assigned_to as details
FROM issue_assignments
UNION ALL
SELECT
    'complexity_estimated' as activity_type,
    issue_number,
    estimated_at as activity_date,
    'Complexity: ' || complexity_score as details
FROM issue_complexity
ORDER BY activity_date DESC
LIMIT 100;

-- ============================================
-- Maintenance Functions
# ============================================

-- Function to update issue_triage timestamp
CREATE OR REPLACE FUNCTION update_issue_triage_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for automatic timestamp updates
DROP TRIGGER IF EXISTS trigger_update_issue_triage_timestamp ON issue_triage;
CREATE TRIGGER trigger_update_issue_triage_timestamp
    BEFORE UPDATE ON issue_triage
    FOR EACH ROW
    EXECUTE FUNCTION update_issue_triage_timestamp();

DROP TRIGGER IF EXISTS trigger_update_complexity_timestamp ON issue_complexity;
CREATE TRIGGER trigger_update_complexity_timestamp
    BEFORE UPDATE ON issue_complexity
    FOR EACH ROW
    EXECUTE FUNCTION update_issue_triage_timestamp();

-- Function to cleanup old issue triage records
CREATE OR REPLACE FUNCTION cleanup_old_triage_records(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete old duplicate records (keep confirmed ones)
    DELETE FROM issue_duplicates
    WHERE detected_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND confirmed IS NULL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Delete old commit links (keep recent ones)
    DELETE FROM issue_commits
    WHERE linked_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND closes_issue = FALSE;

    -- Note: Don't delete classifications, assignments, or complexity estimates
    -- as they provide historical value

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Helper Functions
# ============================================

-- Function to get issue classification stats
CREATE OR REPLACE FUNCTION get_classification_stats(days INTEGER DEFAULT 7)
RETURNS TABLE (
    classification VARCHAR(50),
    count BIGINT,
    confidence NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        it.classification,
        COUNT(*) as count,
        ROUND(AVG(it.confidence)::numeric, 2) as confidence
    FROM issue_triage it
    WHERE it.classified_at > NOW() - (days || ' days')::INTERVAL
    GROUP BY it.classification
    ORDER BY count DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get top assignees
CREATE OR REPLACE FUNCTION get_top_assignees(days INTEGER DEFAULT 30, limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    assigned_to VARCHAR(100),
    assignment_count BIGINT,
    last_assignment TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ia.assigned_to,
        COUNT(*) as assignment_count,
        MAX(ia.assigned_at) as last_assignment
    FROM issue_assignments ia
    WHERE ia.assigned_at > NOW() - (days || ' days')::INTERVAL
    GROUP BY ia.assigned_to
    ORDER BY assignment_count DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Sample Data (Optional - for testing)
# ============================================

-- Insert sample classification (commented out by default)
-- INSERT INTO issue_triage (issue_number, classification, confidence, labels)
-- VALUES (1, 'bug', 0.85, ARRAY['bug', 'high-priority'])
-- ON CONFLICT (issue_number) DO NOTHING;

-- ============================================
-- Grants (adjust as needed)
# ============================================

-- Grant access to Woodpecker database user
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO woodpecker;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO woodpecker;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO woodpecker;
