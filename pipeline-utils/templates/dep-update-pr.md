# Dependency Update: {{DEPENDENCY_NAME}}

## Overview
This PR updates **{{DEPENDENCY_NAME}}** from version `{{OLD_VERSION}}` to `{{NEW_VERSION}}`.

## Update Type
- **Type:** {{UPDATE_TYPE}}
- **Risk Level:**
  - `major`: High - May contain breaking changes
  - `minor`: Medium - New features, backward compatible
  - `patch`: Low - Bug fixes only

## Changes

### What's Updated
- **Dependency:** {{DEPENDENCY_NAME}}
- **Previous Version:** {{OLD_VERSION}}
- **New Version:** {{NEW_VERSION}}
- **Branch:** {{BRANCH_NAME}}

## Why This Update?

### Changelog
Please review the official changelog for details on what's new:
- Check the dependency's GitHub releases page
- Review the documentation for migration guides
- Look for breaking changes if this is a major update

### Security Fixes
If this update includes security fixes, they will be prioritized for merging.

## Testing Instructions

### 1. Review the Changes
```bash
# View the changes
git diff main...{{BRANCH_NAME}}

# Check the modified build.gradle files
git diff main...{{BRANCH_NAME}} -- build.gradle*
```

### 2. Build the Project
```bash
# Clean build
./gradlew clean

# Build the project
./gradlew assembleDebug

# Verify no compilation errors
```

### 3. Run Tests
```bash
# Run unit tests
./gradlew test

# Run instrumentation tests (if applicable)
./gradlew connectedAndroidTest

# Check test results
./gradlew jacocoTestReport
```

### 4. Manual Testing
- [ ] Build succeeds without errors
- [ ] All unit tests pass
- [ ] All instrumentation tests pass
- [ ] App launches successfully
- [ ] Basic functionality works as expected
- [ ] No crashes or ANRs

### 5. Check for Breaking Changes
If this is a **major** version update, pay special attention to:
- API changes
- Deprecated methods removed
- Configuration changes
- Behavioral changes

## Rollback Plan
If issues are discovered:
```bash
# Revert this PR
git revert <merge-commit-sha>

# Or close this PR and stay on the previous version
```

## Automated Checks
This PR was created automatically by the dependency update system. The following checks were performed:

- [x] Dependency update identified
- [x] Version comparison completed
- [x] Update type classified
- [x] Branch created
- [x] Changes committed
- [x] PR created with template

## Next Steps

1. **Review:** Please review the changes carefully
2. **Test:** Run the testing instructions above
3. **Merge:** If all tests pass, merge this PR
4. **Monitor:** Watch for any issues after deployment

## Questions or Concerns?
If you have concerns about this update:
- Comment on this PR with specific issues
- Check the dependency's release notes
- Consult with the team before merging

## Additional Information
- **Automated by:** CI/CD Dependency Management System
- **Created on:** {{CURRENT_DATE}}
- **Priority:** Normal (unless security fix is included)

---

**Note:** This is an automated pull request. Please review and test before merging.
