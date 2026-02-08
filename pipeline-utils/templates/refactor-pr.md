## Automated Refactoring PR

**Type:** {{type}}
**Risk Level:** {{risk_level}}
**Branch:** {{source_branch}} → {{target_branch}}

### Summary

This PR contains automated refactoring changes created by the CI/CD pipeline.

### Changes

{{change_list}}

### Refactoring Details

- **Type:** {{type}}
- **Risk Level:** {{risk_level}}
- **Affected Files:** See diff below
- **Generated:** {{CURRENT_DATE}}

### Testing Checklist

Please complete the following testing steps before merging:

#### 1. Automated Tests
- [ ] Unit tests pass: `./gradlew test`
- [ ] Integration tests pass: `./gradlew integrationTest`
- [ ] Build succeeds: `./gradlew build`

#### 2. Code Review
- [ ] Review the refactoring changes
- [ ] Verify no unintended side effects
- [ ] Check for breaking changes
- [ ] Validate API changes (if any)

#### 3. Manual Testing
- [ ] Application launches successfully
- [ ] Core functionality works as expected
- [ ] No performance degradation
- [ ] No crashes or errors in logs

### Risk Assessment

#### Low Risk
- Simple renames (classes, methods, variables)
- Code formatting changes
- Comment updates
- Import reorganization

#### Medium Risk
- File moves or reorganizations
- Constant extraction
- Method extraction
- Minor structural changes

#### High Risk
- Complex refactoring chains
- Interface changes
- Public API modifications
- Cross-file reorganizations

**Current Risk Level:** {{risk_level}}

### Rollback Plan

If issues are discovered after merging:

```bash
# Option 1: Revert the merge commit
git revert <merge-commit-sha>

# Option 2: Rollback to previous commit
git revert HEAD

# Option 3: Close this PR and create fix
# Create a new PR to address the issues
```

### Review Notes

This PR was created by the automated refactoring system. Please review:

1. **Correctness:** Does the code still behave the same way?
2. **Style:** Does the refactoring improve code quality?
3. **Completeness:** Were all necessary changes made?
4. **Side Effects:** Are there any unintended consequences?

### Merge Requirements

- [ ] All automated checks pass
- [ ] At least one approval from a code owner
- [ ] No unresolved conversations
- [ ] Manual testing completed
- [ ] Risk assessment accepted

### Additional Information

- **Created by:** Automated Refactoring System
- **Script:** `apply-refactoring.sh`
- **Configuration:** See refactoring spec file

### Questions or Concerns?

If you have concerns about this refactoring:

1. **Comment on this PR** with specific issues
2. **Request changes** if you need modifications
3. **Close the PR** if the refactoring should not proceed
4. **Contact the team** for complex discussions

---

**Note:** This is an automated pull request. While the changes have been tested, please review carefully before merging.

**Risk Level Legend:**
- 🟢 **Low:** Safe to merge with basic review
- 🟡 **Medium:** Requires careful review and testing
- 🔴 **High:** Requires thorough review and additional testing
