# Phase 6: Dynamic Test Selection - Quick Start Guide

## Quick Start

### 1. Basic Usage

```bash
# Detect changes between commits
./pipeline-utils/scripts/detect-changes.sh HEAD~5..HEAD

# Run smart tests only for affected modules
./pipeline-utils/scripts/run-smart-tests.sh HEAD~5..HEAD

# With fallback to full test suite if needed
./pipeline-utils/scripts/run-smart-tests.sh HEAD~5..HEAD --fallback
```

### 2. In CI/CD Pipeline

```yaml
steps:
  detect-changes:
    image: android-ci:latest
    commands:
      - ./pipeline-utils/scripts/detect-changes.sh \
          ${CI_COMMIT_PREV} ${CI_COMMIT_SHA} \
          --format bash > .test-env

  smart-tests:
    image: android-ci:latest
    commands:
      - source .test-env
      - ./pipeline-utils/scripts/run-smart-tests.sh \
          ${CI_COMMIT_PREV} ${CI_COMMIT_SHA} \
          --fallback --verbose
```

### 3. Dry Run (See what would be tested)

```bash
./pipeline-utils/scripts/run-smart-tests.sh main..feature-branch --dry-run
```

### 4. Expected Output

```
==========================================
Change Detection Report
==========================================
Commit Range: main..feature-branch
Total Impact Score: 245

✓ app: 180 impact (3 file(s))
✓ data: 65 impact (2 file(s))

Affected Modules (impact >= 10):
  - app
  - data

Estimated: 6m 0s
Actual:    2m 30s
Saved:     3m 30s (58%)

✓ All tests passed
```

## Configuration

Edit `pipeline-utils/config/test-modules.yaml` to customize:

```yaml
modules:
  app:
    test_task: ":app:testDebugUnitTest"
    estimated_time: 120
    dependencies: ["data", "domain"]
```

## Time Savings

| Change Type | Modules | Time Saved |
|-------------|---------|------------|
| Small       | 1-2     | 50-70%     |
| Medium      | 3-5     | 40-60%     |
| Large       | 6+      | 20-40%     |

## Full Documentation

See `pipeline-utils/PHASE6_SUMMARY.md` for complete documentation.
