# Issue Triage Fixes - Quick Reference

## Overview
Quick reference for the security and algorithmic fixes applied to Feature 5 - Issue Triage Automation scripts.

## Files Modified

### Core Security Library
- ✅ **`security-utils.sh`** - Enhanced with SQL escaping and validation functions

### Issue Triage Scripts
- ✅ **`classify-issue.sh`** - Fixed classification algorithm + SQL injection protection
- ✅ **`detect-duplicates.sh`** - Fixed broken duplicate detection algorithm + SQL injection protection
- ✅ **`assign-issue.sh`** - Assignee validation + SQL injection protection + dynamic module discovery
- ✅ **`estimate-complexity.sh`** - SQL injection protection

### Wrapper Scripts (No Changes Needed)
- ✅ **`link-issues-to-commits.sh`** - Already secure
- ✅ **`generate-issue-report.sh`** - Already secure
- ✅ **`classify-new-issues.sh`** - Inherits fixes from classify-issue.sh
- ✅ **`assign-unassigned-issues.sh`** - Inherits fixes from assign-issue.sh

## Critical Fixes

### 1. SQL Injection (CRITICAL)
**What was wrong:** User inputs directly inserted into SQL queries
**What was fixed:** All inputs now escaped using `psql_escape()`
**Scripts affected:** classify-issue.sh, detect-duplicates.sh, assign-issue.sh, estimate-complexity.sh

**Example Fix:**
```bash
# Before (vulnerable):
query="INSERT INTO table (col) VALUES ('$user_input')"

# After (safe):
escaped=$(psql_escape "$user_input")
query="INSERT INTO table (col) VALUES ('$escaped')"
```

### 2. Broken Duplicate Detection (CRITICAL)
**What was wrong:** Used `bc` calculator to compare text strings (always failed)
**What was fixed:** Proper Jaccard similarity calculation using `comm` and `wc`
**Script affected:** detect-duplicates.sh

**Algorithm:**
```
Jaccard Similarity = (Intersection / Union)

Where:
- Intersection = words in both texts
- Union = unique words in either text
- Threshold = 0.7 (70%)
```

### 3. Classification Keyword Overlap (HIGH)
**What was wrong:** Same keywords in multiple categories caused misclassification
**What was fixed:** Priority-based category selection
**Script affected:** classify-issue.sh

**Priorities:**
```
security:    10 (highest)
bug:          8
performance:  6
feature:      5
enhancement:  3
documentation: 2
question:     1 (lowest)
```

### 4. Missing Assignee Validation (MEDIUM)
**What was wrong:** Could assign to non-existent users
**What was fixed:** Username format validation + existence check
**Script affected:** assign-issue.sh

**Validations:**
```bash
# 1. Check format
is_valid_github_username "$username"

# 2. Check exists
github_user_exists "$username"

# 3. Then assign
gh issue edit "$number" --add-assignee "$username"
```

### 5. Floating-Point Arithmetic (LOW)
**What was wrong:** Bash doesn't handle floating-point well
**What was fixed:** Use integer scale (0-100 instead of 0-1)
**Script affected:** assign-issue.sh

**Example:**
```bash
# Before:
strength=0.85
if [[ $strength -gt 0.5 ]]; then  # Fails in bash

# After:
strength_int=$(awk "BEGIN {printf \"%d\", ${strength} * 100}")  # 85
if [[ $strength_int -gt 50 ]]; then  # Works
```

### 6. Hardcoded Module List (LOW)
**What was wrong:** MODULES=("app" "data" "domain" "ui") hardcoded
**What was fixed:** Dynamic discovery from config or build files
**Script affected:** assign-issue.sh

**Discovery:**
```bash
# 1. Check config file
if [[ -f "config/modules.txt" ]]; then
    read modules from file
else
    # 2. Auto-discover from build.gradle.kts
    find . -name "build.gradle.kts" -not -path "*/build/*"
fi
```

## Security Functions Added

All functions are in `security-utils.sh` and exported for use in other scripts:

```bash
# SQL Escaping
psql_escape "string"              # Escape for SQL queries
psql_escape_like "pattern"        # Escape for LIKE queries

# Validation
is_valid_github_username "user"   # Check username format
is_valid_issue_number "123"       # Check issue number format
validate_sql_int "42" "0"         # Validate integer
validate_sql_identifier "col"     # Validate SQL identifier

# GitHub
github_user_exists "username"     # Check if user exists on GitHub

# Sanitization
sanitize_github_label "label"     # Sanitize label for GitHub
sanitize_comment "text"           # Sanitize comment text
```

## Usage in Scripts

To use security functions in any script:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source security utilities
source "${SCRIPT_DIR}/security-utils.sh"

# Now use the functions
user_input="$1"
escaped=$(psql_escape "$user_input")

# Validate
if is_valid_github_username "$user_input"; then
    # Safe to use
    query="INSERT INTO users (name) VALUES ('$escaped')"
fi
```

## Testing Checklist

### SQL Injection Testing
- [ ] Test with input containing single quotes: `O'Reilly`
- [ ] Test with input containing semicolons: `test; DROP TABLE users;--`
- [ ] Test with input containing backslashes: `path\to\file`
- [ ] Test with input containing NULL bytes: `test\x00injection`

### Duplicate Detection Testing
- [ ] Create two issues with identical titles
- [ ] Create two issues with similar but different titles
- [ ] Create two issues with completely different titles
- [ ] Verify similarity scores are calculated correctly
- [ ] Verify threshold (0.7) works as expected

### Classification Testing
- [ ] Test "optimize" keyword → should classify as `performance` not `enhancement`
- [ ] Test "crash" keyword → should classify as `bug`
- [ ] Test "security" keyword → should classify as `security` (highest priority)
- [ ] Test question format → should classify as `question`

### Assignee Validation Testing
- [ ] Test with invalid format: `user@bad#format`
- [ ] Test with non-existent user: `fake-user-xyz-123`
- [ ] Test with valid user: should assign successfully
- [ ] Test with multiple users: should assign all valid users

### Module Discovery Testing
- [ ] Test with `config/modules.txt` present → should use file
- [ ] Test without `config/modules.txt` → should auto-discover
- [ ] Test in non-Gradle project → should handle gracefully

## Common Patterns

### Pattern 1: Safe SQL Query
```bash
source "${SCRIPT_DIR}/security-utils.sh"

query_db() {
    local query="$1"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" \
        -d "${DB_NAME}" -t -A -c "${query}"
}

# Usage
user_input="O'Reilly"
escaped=$(psql_escape "$user_input")
query="SELECT * FROM users WHERE name = '$escaped'"
result=$(query_db "$query")
```

### Pattern 2: Validate and Use GitHub Username
```bash
source "${SCRIPT_DIR}/security-utils.sh"

assign_to_user() {
    local issue_number="$1"
    local username="$2"

    # Validate format
    if ! is_valid_github_username "$username"; then
        log_error "Invalid username format: $username"
        return 1
    fi

    # Check exists
    if ! github_user_exists "$username"; then
        log_error "User does not exist: $username"
        return 1
    fi

    # Safe to assign
    gh issue edit "$issue_number" --add-assignee "$username"
}
```

### Pattern 3: Safe Issue Number Handling
```bash
source "${SCRIPT_DIR}/security-utils.sh"

process_issue() {
    local issue_number="$1"

    # Validate
    if ! is_valid_issue_number "$issue_number"; then
        log_error "Invalid issue number: $issue_number"
        return 1
    fi

    # Safe to use in SQL (no escaping needed for integers)
    query="SELECT * FROM issues WHERE number = $issue_number"
    result=$(query_db "$query")
}
```

## Troubleshooting

### Issue: "Invalid GitHub username format"
**Cause:** Username contains invalid characters
**Solution:** GitHub usernames must be:
- 1-39 characters
- Alphanumeric and hyphens only
- Cannot start or end with hyphen

### Issue: "Duplicate detection not working"
**Cause:** Algorithm was broken, now fixed
**Solution:** Ensure you're using the updated `detect-duplicates.sh` script

### Issue: "Classification seems wrong"
**Cause:** Keyword overlap before priority system
**Solution:** Check category priorities in `classify-issue.sh`

### Issue: "Assignee validation fails"
**Cause:** User doesn't exist or format is invalid
**Solution:** Verify username exists on GitHub and has correct format

## Performance Notes

### SQL Escaping
- **Cost:** Minimal (string replacement)
- **Impact:** None (< 1ms per string)

### User Existence Check
- **Cost:** ~1 second per user (GitHub API call)
- **Impact:** Adds delay during assignment but prevents failures

### Duplicate Detection
- **Cost:** ~2-5 seconds per issue (depends on text length)
- **Impact:** Worth it for accuracy (was completely broken before)

### Module Discovery
- **Cost:** One-time at startup (~1 second)
- **Impact:** Negligible

## Security Best Practices

### 1. Always Escape SQL Input
```bash
# ❌ WRONG
query="INSERT INTO table (col) VALUES ('$user_input')"

# ✅ RIGHT
escaped=$(psql_escape "$user_input")
query="INSERT INTO table (col) VALUES ('$escaped')"
```

### 2. Validate Before Using
```bash
# ❌ WRONG
gh issue edit "$number" --add-assignee "$user"

# ✅ RIGHT
if is_valid_github_username "$user" && github_user_exists "$user"; then
    gh issue edit "$number" --add-assignee "$user"
fi
```

### 3. Use Integer Math When Possible
```bash
# ❌ WRONG
strength=0.85
if (( $(echo "$strength > 0.5" | bc -l) )); then

# ✅ RIGHT
strength_int=85
if [[ $strength_int -gt 50 ]]; then
```

## Migration Guide

### For Existing Scripts

1. **Source security-utils.sh**
```bash
source "${SCRIPT_DIR}/security-utils.sh"
```

2. **Replace direct SQL with escaped versions**
```bash
# Before
query="SELECT * FROM issues WHERE title = '$title'"

# After
escaped_title=$(psql_escape "$title")
query="SELECT * FROM issues WHERE title = '$escaped_title'"
```

3. **Add validation for user inputs**
```bash
# Before
assign_issue "$issue_number" "$username"

# After
if is_valid_github_username "$username"; then
    assign_issue "$issue_number" "$username"
fi
```

## Support

### Issues Found?
1. Check this quick reference first
2. Review `ISSUE_TRIAGE_SECURITY_FIXES.md` for detailed info
3. Check script comments for algorithm details
4. Verify you're using updated scripts

### Need Testing Help?
See "Testing Checklist" section above for step-by-step testing procedures.

---

**Last Updated:** 2026-02-08
**Version:** 1.0
**Status:** ✅ All Fixes Complete
