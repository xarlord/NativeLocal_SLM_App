# Feature 3: Automated PR Creation - Implementation Summary

## Overview

Feature 3 implements automated PR creation scripts for the Woodpecker CI/CD pipeline. This feature enables autonomous creation and management of pull requests for dependency updates, refactoring, and other automated tasks.

## Created Scripts

### 1. create-branch.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\create-branch.sh`

**Purpose:** Create feature branches with naming convention validation and database logging.

**Usage:**
```bash
./create-branch.sh feature/update-dependency-name
./create-branch.sh bugfix/login-error develop
./create-branch.sh refactor/rename-class
```

**Features:**
- Validates branch name format (supports: feature/*, bugfix/*, hotfix/*, release/*, refactor/*)
- Auto-detects branch type from name
- Determines base branch (main/develop/master)
- Checks for existing branches
- Fetches latest changes before creating
- Logs to `branch_history` table
- Supports custom base branches

**Database Schema:**
- Table: `branch_history`
- Tracks: branch_name, branch_type, base_branch, creator, status, PR info

---

### 2. apply-dependency-update.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\apply-dependency-update.sh`

**Purpose:** Apply dependency updates to build.gradle.kts files with database logging.

**Usage:**
```bash
./apply-dependency-update.sh com.google.code.gson:gson 2.8.9 2.10.1
./apply-dependency-update.sh org.junit.jupiter:junit-jupiter 5.8.2 5.9.0 minor
```

**Features:**
- Updates build.gradle.kts files
- Handles multiple version declaration formats
- Runs `./gradlew dependencies` to refresh
- Auto-detects update type (major/minor/patch)
- Commits with formatted message
- Logs to `dependency_updates` table
- Creates backups during update

**Supported Formats:**
- `implementation("group:name:version")`
- `version = "version"`
- Variable declarations

---

### 3. apply-refactoring.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\apply-refactoring.sh`

**Purpose:** Apply automated refactoring from YAML/JSON specifications.

**Usage:**
```bash
./apply-refactoring.sh refactor-spec.yaml
./apply-refactoring.sh refactor-spec.json
```

**Supported Refactorings:**
- `rename_class` - Rename a class and update file name
- `rename_method` - Rename a method and update references
- `rename_variable` - Rename a variable
- `move_file` - Move file to new location
- `extract_constant` - Extract magic value to constant
- `inline_constant` - Inline constant value

**Spec File Format (YAML):**
```yaml
type: rename_class
old_name: OldClassName
new_name: NewClassName
file_path: app/src/main/java/com/example/OldClassName.kt
```

**Features:**
- Parses YAML or JSON specifications
- Validates refactoring type (safe transformations only)
- Determines risk level automatically
- Creates backups before changes
- Tests compilation after refactoring
- Commits changes if successful
- Logs to `refactoring_history` table

---

### 4. create-pr.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\create-pr.sh`

**Purpose:** Create pull requests using gh CLI with template loading and label assignment.

**Usage:**
```bash
./create-pr.sh "Add new feature" "This adds a feature" feature/new-feature main
./create-pr.sh "Update dependency" "AUTO" deps/update-lib-1.0 main
CREATE_DRAFT_PR=true ./create-pr.sh "WIP: Feature" "Body" feature/wip main
```

**Features:**
- Auto-detects PR type from branch name
- Loads appropriate PR template
- Determines risk level
- Assigns labels based on type and risk
- Assigns default reviewers
- Supports draft PRs
- Uses retry-command.sh for API calls
- Logs to `automated_prs` table

**PR Type Detection:**
- `feature/*` → type: feature
- `bugfix/*`, `fix/*` → type: fix
- `hotfix/*` → type: hotfix
- `release/*` → type: release
- `refactor/*` → type: refactor
- `deps/*` → type: dependency

**Labels Applied:**
- Type label (e.g., "feature", "refactor")
- "automated"
- Risk level (e.g., "risk:medium", "risk:high")
- Type-specific labels (e.g., "dependencies", "urgent")

---

### 5. request-review.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\request-review.sh`

**Purpose:** Auto-assign reviewers based on code ownership database queries.

**Usage:**
```bash
./request-review.sh 123
./request-review.sh 123 user1 user2
DEFAULT_REVIEWERS=user1,user2 ./request-review.sh 123
```

**Features:**
- Queries `code_ownership` table for changed files
- Matches file patterns to owners
- Falls back to default reviewers
- Supports team assignments
- Avoids duplicate reviewer assignments
- Checks current PR state
- Updates `automated_prs` table

**Database Query:**
```sql
SELECT github_username, owner_name, ownership_strength
FROM code_ownership
WHERE 'file/path' LIKE file_pattern
ORDER BY ownership_strength DESC;
```

**Environment Variables:**
- `DEFAULT_REVIEWERS` - Comma-separated default reviewers
- `FALLBACK_REVIEWERS` - Fallback if defaults not set
- `TEAM_REVIEWERS` - Team names to assign

---

### 6. auto-merge-check.sh
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\scripts\auto-merge-check.sh`

**Purpose:** Check if PR is auto-mergeable with comprehensive validation.

**Usage:**
```bash
./auto-merge-check.sh 123
REQUIRED_APPROVALS=2 ./auto-merge-check.sh 123
REQUIRED_STATUS_CHECKS=ci/test,ci/build ./auto-merge-check.sh 123
```

**Checks Performed:**
1. ✓ All status checks passing
2. ✓ Required status checks present (if configured)
3. ✓ Required approvals granted
4. ✓ Reviews not stale (configurable age limit)
5. ✓ PR is up to date with target branch
6. ✓ No merge conflicts
7. ✓ No unresolved conversations (warning only)

**Exit Codes:**
- `0` - All checks passed (auto-mergeable)
- `1` - One or more checks failed

**Environment Variables:**
- `REQUIRED_APPROVALS` - Minimum required approvals (default: 1)
- `REQUIRED_STATUS_CHECKS` - Comma-separated list of required checks
- `ALLOW_STALE_REVIEW` - Allow stale reviews (default: false)
- `MAX_CONVERSATION_AGE_DAYS` - Max review age in days (default: 7)

**Database Updates:**
Updates `automated_prs` table with check results:
- `auto_mergeable` - boolean
- `checks_passed` - boolean

---

## PR Template

### refactor-pr.md
**Location:** `C:\Users\plner\claudePlayground\pipeline-utils\templates\refactor-pr.md`

**Purpose:** Template for automated refactoring PRs.

**Template Variables:**
- `{{type}}` - Refactoring type
- `{{risk_level}}` - Risk assessment
- `{{source_branch}}` - Source branch name
- `{{target_branch}}` - Target branch name
- `{{change_list}}` - List of changes
- `{{CURRENT_DATE}}` - Creation date

**Sections:**
- Summary
- Changes
- Refactoring Details
- Testing Checklist
- Risk Assessment
- Rollback Plan
- Review Notes
- Merge Requirements

---

## Database Schema Updates

Added three new tables to `pipeline-utils/schema/metrics.sql`:

### branch_history
Tracks all branch creation events.

```sql
CREATE TABLE branch_history (
    id SERIAL PRIMARY KEY,
    branch_name VARCHAR(200) NOT NULL,
    branch_type VARCHAR(50),
    base_branch VARCHAR(100) NOT NULL,
    creator VARCHAR(100),
    created_by_script BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active',
    commits_count INTEGER DEFAULT 0,
    pr_number INTEGER,
    pr_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    last_commit_at TIMESTAMP,
    merged_at TIMESTAMP,
    closed_at TIMESTAMP
);
```

### automated_prs
Tracks all automated pull requests.

```sql
CREATE TABLE automated_prs (
    id SERIAL PRIMARY KEY,
    pr_number INTEGER NOT NULL,
    pr_url TEXT NOT NULL,
    title VARCHAR(500) NOT NULL,
    body TEXT,
    source_branch VARCHAR(200) NOT NULL,
    target_branch VARCHAR(100) NOT NULL,
    pr_type VARCHAR(50),
    risk_level VARCHAR(20),
    status VARCHAR(20) DEFAULT 'open',
    mergeable BOOLEAN,
    draft BOOLEAN DEFAULT FALSE,
    reviewers JSONB,
    required_reviewers INTEGER DEFAULT 1,
    approval_count INTEGER DEFAULT 0,
    labels JSONB,
    checks_passed BOOLEAN,
    auto_mergeable BOOLEAN,
    created_by_script VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    merged_at TIMESTAMP,
    closed_at TIMESTAMP
);
```

### refactoring_history
Tracks all refactoring operations.

```sql
CREATE TABLE refactoring_history (
    id SERIAL PRIMARY KEY,
    refactoring_type VARCHAR(100) NOT NULL,
    description TEXT,
    affected_files JSONB,
    lines_changed INTEGER,
    risk_level VARCHAR(20) DEFAULT 'low',
    safe_transformation BOOLEAN DEFAULT TRUE,
    branch_name VARCHAR(200),
    pr_number INTEGER,
    pr_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    compilation_success BOOLEAN,
    tests_passed BOOLEAN,
    spec_file TEXT,
    created_by_script VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    applied_at TIMESTAMP,
    merged_at TIMESTAMP
);
```

---

## Workflow Examples

### Example 1: Dependency Update Workflow
```bash
# 1. Create branch
./create-branch.sh deps/update-gson-2.10.1

# 2. Apply update
./apply-dependency-update.sh com.google.code.gson:gson 2.8.9 2.10.1

# 3. Push branch
git push origin deps/update-gson-2.10.1

# 4. Create PR
./create-pr.sh "Update gson to 2.10.1" "AUTO" deps/update-gson-2.10.1 main

# 5. Request review
./request-review.sh 12345

# 6. Check mergeability
./auto-merge-check.sh 12345
```

### Example 2: Refactoring Workflow
```bash
# 1. Create refactoring spec (refactor-spec.yaml)
cat > refactor-spec.yaml << EOF
type: rename_class
old_name: UserManager
new_name: UserService
file_path: app/src/main/java/com/example/UserManager.kt
EOF

# 2. Create branch
./create-branch.sh refactor/rename-user-manager

# 3. Apply refactoring
./apply-refactoring.sh refactor-spec.yaml

# 4. Push and test
git push origin refactor/rename-user-manager
./gradlew test

# 5. Create PR
./create-pr.sh "Refactor: Rename UserManager to UserService" "AUTO" refactor/rename-user-manager main

# 6. Request review
./request-review.sh 12346
```

### Example 3: Bug Fix Workflow
```bash
# 1. Create branch
./create-branch.sh bugfix/login-timeout

# 2. Make changes manually
# ... edit files ...

# 3. Commit and push
git add -A
git commit -m "Fix login timeout issue"
git push origin bugfix/login-timeout

# 4. Create PR
./create-pr.sh "Fix login timeout" "Fixes #123" bugfix/login-timeout main

# 5. Request review from code owners
./request-review.sh 12347

# 6. Monitor and merge when ready
./auto-merge-check.sh 12347 && gh pr merge 12347 --merge
```

---

## Integration with Existing Scripts

The new scripts integrate with existing pipeline utilities:

- **retry-command.sh** - Used for all GitHub API calls with retry logic
- **send-notification.sh** - Can be used to notify on PR events
- **detect-owners.sh** - Used by request-review.sh to find code owners

---

## Environment Configuration

### Database Connection
```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=woodpecker
export DB_USER=woodpecker
export DB_PASSWORD=woodpecker
```

### GitHub Configuration
```bash
export GIT_REMOTE=origin
export DEFAULT_BASE_BRANCH=main
export GITHUB_TOKEN=ghp_xxx
```

### Reviewer Configuration
```bash
export DEFAULT_REVIEWERS=user1,user2,user3
export FALLBACK_REVIEWERS=default-user
export TEAM_REVIEWERS=team-backend,team-frontend
```

### Merge Check Configuration
```bash
export REQUIRED_APPROVALS=2
export REQUIRED_STATUS_CHECKS=ci/test,ci/build,ci/lint
export ALLOW_STALE_REVIEW=false
export MAX_CONVERSATION_AGE_DAYS=7
```

---

## GitHub CLI Requirements

All scripts require `gh` CLI to be installed and authenticated:

```bash
# Install gh CLI
# https://cli.github.com/

# Authenticate
gh auth login

# Verify
gh auth status
```

---

## Script Dependencies

### Required Tools
- `bash` - Script execution
- `gh` - GitHub CLI for PR operations
- `git` - Version control
- `psql` - PostgreSQL client for database operations
- `jq` - JSON parsing
- `sed`, `grep`, `find` - Text processing

### Optional Tools
- `yq` - YAML parsing (for apply-refactoring.sh)
- `gradlew` - Gradle wrapper (for dependency updates)

---

## Error Handling

All scripts follow consistent error handling patterns:

1. **Validation** - Check prerequisites before execution
2. **Logging** - Detailed logging with timestamps
3. **Exit Codes** - Standard exit codes (0 = success, 1 = error)
4. **Rollback** - Backup files created before modifications
5. **Database Logging** - All operations logged to database
6. **GitHub API Retry** - Uses retry-command.sh for API calls

---

## Security Considerations

1. **Database Credentials** - Stored in environment variables, not in scripts
2. **GitHub Tokens** - Use fine-grained tokens with minimal permissions
3. **Refactoring Safety** - Only safe transformations supported
4. **Backup Files** - Created before any destructive operations
5. **Commit Messages** - Include attribution to automated scripts
6. **Review Required** - All automated PRs require human review

---

## Future Enhancements

Potential improvements for future iterations:

1. **Advanced Refactoring**
   - Support for complex refactoring chains
   - IDE integration (IntelliJ, Android Studio)
   - Cross-language refactoring

2. **Smart Reviewer Assignment**
   - Machine learning-based reviewer suggestions
   - Load balancing across team members
   - Expertise detection

3. **Automated Testing**
   - Automated test generation for refactoring
   - Differential testing
   - Regression detection

4. **PR Automation**
   - Auto-merge when all checks pass
   - Automatic rebasing of stale branches
   - PR dependency management

5. **Analytics**
   - Merge time tracking
   - Review efficiency metrics
   - Refactoring success rates

---

## Troubleshooting

### Common Issues

**Issue:** "GitHub CLI not authenticated"
**Solution:** Run `gh auth login`

**Issue:** "Cannot connect to database"
**Solution:** Verify DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

**Issue:** "Branch already exists"
**Solution:** The script will log to database and allow you to checkout existing branch

**Issue:** "Compilation failed after refactoring"
**Solution:** Check logs, restore backups: `find . -name '*.backup' -exec sh -c 'mv "$1" "${1%.backup}"' _ {} \;`

**Issue:** "PR creation failed"
**Solution:** Check branch exists, is pushed, and you have permissions

---

## Quick Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| create-branch.sh | Create feature branch | `./create-branch.sh feature/name` |
| apply-dependency-update.sh | Update dependencies | `./script.sh name old new` |
| apply-refactoring.sh | Apply refactoring | `./script.sh spec.yaml` |
| create-pr.sh | Create pull request | `./script.sh "Title" "Body" src tgt` |
| request-review.sh | Assign reviewers | `./script.sh 123` |
| auto-merge-check.sh | Check mergeability | `./script.sh 123` |

---

## Conclusion

Feature 3 provides a comprehensive automated PR creation system that integrates seamlessly with the existing Woodpecker CI/CD pipeline. The scripts follow established patterns, include robust error handling, and maintain detailed audit trails in the database.

All scripts are production-ready and can be integrated into CI/CD workflows immediately.
