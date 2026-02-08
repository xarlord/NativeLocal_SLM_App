# Feature 3: Automated PR Creation - Quick Start Guide

## Scripts Created

### 1. Branch Management
**create-branch.sh** - Create feature branches with validation
```bash
./create-branch.sh feature/update-dependency-name
./create-branch.sh bugfix/login-error develop
```

### 2. Dependency Updates
**apply-dependency-update.sh** - Update dependencies in build.gradle.kts
```bash
./apply-dependency-update.sh com.google.code.gson:gson 2.8.9 2.10.1
```

### 3. Automated Refactoring
**apply-refactoring.sh** - Apply refactoring from YAML/JSON spec
```bash
./apply-refactoring.sh refactor-spec.yaml
```

**Spec format:**
```yaml
type: rename_class
old_name: OldClassName
new_name: NewClassName
file_path: app/src/main/java/com/example/OldClassName.kt
```

### 4. PR Creation
**create-pr.sh** - Create pull requests with templates
```bash
./create-pr.sh "Title" "AUTO" source-branch target-branch
./create-pr.sh "Update dependency" "AUTO" deps/update-gson-2.10 main
```

### 5. Review Assignment
**request-review.sh** - Auto-assign reviewers based on code ownership
```bash
./request-review.sh 12345
DEFAULT_REVIEWERS=user1,user2 ./request-review.sh 12345
```

### 6. Merge Checks
**auto-merge-check.sh** - Validate PR is ready to merge
```bash
./auto-merge-check.sh 12345
REQUIRED_APPROVALS=2 ./auto-merge-check.sh 12345
```

## Complete Workflow Example

### Dependency Update Workflow
```bash
# 1. Create branch
./create-branch.sh deps/update-gson-2.10.1

# 2. Apply update
./apply-dependency-update.sh com.google.code.gson:gson 2.8.9 2.10.1

# 3. Push branch
git push origin deps/update-gson-2.10.1

# 4. Create PR
./create-pr.sh "Update gson to 2.10.1" "AUTO" deps/update-gson-2.10.1 main

# 5. Request review (returns PR number from previous step)
./request-review.sh 12345

# 6. Check if ready to merge
./auto-merge-check.sh 12345

# 7. Merge if checks pass
if [ $? -eq 0 ]; then
    gh pr merge 12345 --merge
fi
```

### Refactoring Workflow
```bash
# 1. Create spec
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
./create-pr.sh "Refactor: Rename UserManager to UserService" "AUTO" \
    refactor/rename-user-manager main

# 6. Request review
./request-review.sh 12346
```

## Environment Variables

### Database
```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=woodpecker
export DB_USER=woodpecker
export DB_PASSWORD=woodpecker
```

### Git/GitHub
```bash
export GIT_REMOTE=origin
export DEFAULT_BASE_BRANCH=main
export GITHUB_TOKEN=ghp_xxx
```

### Reviewers
```bash
export DEFAULT_REVIEWERS=user1,user2,user3
export FALLBACK_REVIEWERS=default-user
export TEAM_REVIEWERS=team-backend,team-frontend
```

### Merge Requirements
```bash
export REQUIRED_APPROVALS=2
export REQUIRED_STATUS_CHECKS=ci/test,ci/build,ci/lint
export ALLOW_STALE_REVIEW=false
export MAX_CONVERSATION_AGE_DAYS=7
```

## PR Types Detection

| Branch Pattern | PR Type | Risk Level | Labels |
|---------------|---------|------------|--------|
| `feature/*` | feature | medium | feature, automated, risk:medium |
| `bugfix/*`, `fix/*` | fix | low | fix, automated, risk:low |
| `hotfix/*` | hotfix | high | hotfix, automated, urgent, priority:high |
| `release/*` | release | medium | release, automated, risk:medium |
| `refactor/*` | refactor | medium | refactor, automated, refactoring |
| `deps/*` | dependency | varies | dependency, automated, dependencies |

## Database Tables

### branch_history
Tracks all branch creation events
- branch_name, branch_type, base_branch, creator, status
- PR tracking (pr_number, pr_url)
- Timestamps (created, last_commit, merged, closed)

### automated_prs
Tracks all automated pull requests
- PR details (number, url, title, body)
- Branch info (source, target)
- Type and risk assessment
- Reviewers and labels
- Merge status

### refactoring_history
Tracks all refactoring operations
- Refactoring type and description
- Affected files and lines changed
- Risk level and safety assessment
- PR tracking
- Testing results

## Code Ownership

For automatic reviewer assignment, populate the `code_ownership` table:

```sql
INSERT INTO code_ownership (file_pattern, owner_type, owner_name, github_username, ownership_strength)
VALUES
    ('app/src/main/java/com/auth/*', 'user', 'Alice', 'alice', 1.0),
    ('app/src/main/java/com/auth/*', 'team', 'backend-team', 'team-backend', 0.8),
    ('app/src/main/java/**/*User*.kt', 'user', 'Bob', 'bob', 0.9);
```

## Exit Codes

All scripts use standard exit codes:
- `0` - Success
- `1` - Error or failure
- `124` - Timeout (for gradle commands)

## Script Locations

All scripts in: `C:\Users\plner\claudePlayground\pipeline-utils\scripts\`

- create-branch.sh (299 lines)
- apply-dependency-update.sh (356 lines)
- apply-refactoring.sh (585 lines)
- create-pr.sh (484 lines)
- request-review.sh (394 lines)
- auto-merge-check.sh (470 lines)

Templates in: `C:\Users\plner\claudePlayground\pipeline-utils\templates\`

- refactor-pr.md - Refactoring PR template

## Troubleshooting

### GitHub CLI Issues
```bash
# Install gh CLI
# https://cli.github.com/

# Authenticate
gh auth login

# Verify
gh auth status
```

### Database Connection Issues
```bash
# Test connection
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME

# Check tables
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\dt"
```

### Branch Already Exists
The script will log to database and allow you to checkout:
```bash
git checkout existing-branch-name
```

### Compilation Failed After Refactoring
Restore backups:
```bash
find . -name '*.backup' -exec sh -c 'mv "$1" "${1%.backup}"' _ {} \;
```

## Integration with CI/CD

Add to Woodpecker CI pipeline:

```yaml
pipeline:
  dependency-update:
    image: alpine:latest
    commands:
      - ./pipeline-utils/scripts/create-branch.sh deps/update-$DEP_NAME-$VERSION
      - ./pipeline-utils/scripts/apply-dependency-update.sh $DEP_NAME $OLD_VERSION $NEW_VERSION
      - git push origin deps/update-$DEP_NAME-$VERSION
      - PR_NUMBER=$(./pipeline-utils/scripts/create-pr.sh "Update $DEP_NAME" "AUTO" deps/update-$DEP_NAME-$VERSION main)
      - ./pipeline-utils/scripts/request-review.sh $PR_NUMBER
    secrets: [ github_token, db_password ]
    when:
      event: cron
      cron: daily
```

## Next Steps

1. **Setup Database**
   - Run schema/metrics.sql to create tables
   - Populate code_ownership table

2. **Configure Environment**
   - Set database credentials
   - Configure GitHub CLI
   - Set default reviewers

3. **Test Workflow**
   - Run through dependency update example
   - Verify database logging
   - Check PR creation

4. **Customize**
   - Add your own refactoring types
   - Create custom PR templates
   - Configure merge requirements

5. **Integrate**
   - Add to CI/CD pipeline
   - Set up scheduled tasks
   - Configure notifications

## Support

For detailed documentation, see: `pipeline-utils/FEATURE3_SUMMARY.md`
