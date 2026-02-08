#!/bin/bash
# auto-update-deps.sh
# Automatically checks for dependency updates and creates pull requests
# Part of Phase 5: Dependency Management Automation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR_TEMPLATE="$SCRIPT_DIR/../templates/dep-update-pr.md"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$REPO_ROOT/.dependency-update.log"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-woodpecker}"
DB_USER="${DB_USER:-woodpecker}"
DB_PASSWORD="${DB_PASSWORD:-woodpecker}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log "ERROR: GitHub CLI not found. Please install gh first."
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        log "ERROR: GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
}

# Get repository information
get_repo_info() {
    REPO_OWNER=$(git remote get-url origin | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
    REPO_NAME=$(git remote get-url origin | sed -n 's/.*github.com[:/][^/]*\/\(.*\)\.git/\1/p')

    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        log "ERROR: Could not determine repository owner/name"
        exit 1
    fi

    log "Repository: $REPO_OWNER/$REPO_NAME"
}

# Check for Gradle dependency updates
check_gradle_updates() {
    log "Checking for Gradle dependency updates..."

    cd "$REPO_ROOT"

    # Find Gradle project
    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        PROJECT_DIR="."
    elif [ -f "simpleGame/build.gradle" ] || [ -f "simpleGame/build.gradle.kts" ]; then
        PROJECT_DIR="simpleGame"
    else
        log "ERROR: No Gradle project found"
        exit 1
    fi

    cd "$PROJECT_DIR"

    # Check if Gradle wrapper exists
    if [ ! -f "gradlew" ]; then
        log "ERROR: Gradle wrapper not found"
        exit 1
    fi

    # Try to use gradle-use-latest-version plugin if available
    # Otherwise, check for updates manually
    log "Running dependency update check..."

    # Create a temporary file for results
    TEMP_RESULT=$(mktemp)

    # Check for updates using Gradle
    ./gradlew dependencyUpdates -Drevision=release \
        -DoutputFormatter=json \
        -DoutputFile="$TEMP_RESULT" \
        --no-daemon --quiet 2>&1 || true

    # Parse results
    if [ -f "$TEMP_RESULT" ] && [ -s "$TEMP_RESULT" ]; then
        UPDATES_FOUND=$(cat "$TEMP_RESULT" | grep -c '"current":' || echo "0")

        if [ "$UPDATES_FOUND" -gt 0 ]; then
            log "Found $UPDATES_FOUND dependency update(s)"

            # Extract update information
            jq -r '.[] | "\(.name) | \(.current) | \(.available)"' "$TEMP_RESULT" 2>/dev/null > "$REPO_ROOT/.deps-to-update.txt" || true

            rm -f "$TEMP_RESULT"
            return 0
        else
            log "No dependency updates found"
            rm -f "$TEMP_RESULT"
            return 1
        fi
    else
        # Fallback: manual check using gradle dependencies
        log "Using manual dependency check..."

        ./gradlew dependencies --no-daemon --quiet 2>&1 | tee "$REPO_ROOT/.gradle-deps.txt" | grep -i "FAILED" && {
            log "ERROR: Failed to check dependencies"
            exit 1
        }

        # Check if there are any outdated dependencies (simplified)
        # In production, use proper version comparison tools
        log "Manual check complete. Review .gradle-deps.txt for details."

        rm -f "$TEMP_RESULT"
        return 1
    fi
}

# Apply dependency updates
apply_updates() {
    log "Applying dependency updates..."

    cd "$REPO_ROOT"

    # Check if there are updates to apply
    if [ ! -f ".deps-to-update.txt" ] || [ ! -s ".deps-to-update.txt" ]; then
        log "No updates to apply"
        return 1
    fi

    # For each dependency, create a separate PR
    while IFS='|' read -r name current available; do
        # Trim whitespace
        name=$(echo "$name" | xargs)
        current=$(echo "$current" | xargs)
        available=$(echo "$available" | xargs)

        if [ -z "$name" ] || [ -z "$available" ]; then
            continue
        fi

        log "Processing update: $name ($current -> $available)"

        # Determine update type
        UPDATE_TYPE="patch"
        if [[ "$current" == *"."*"."* ]]; then
            CURRENT_MAJOR=$(echo "$current" | cut -d. -f1)
            AVAILABLE_MAJOR=$(echo "$available" | cut -d. -f1)

            if [ "$AVAILABLE_MAJOR" -gt "$CURRENT_MAJOR" ]; then
                UPDATE_TYPE="major"
            elif [ "$(echo "$available" | cut -d. -f2)" -gt "$(echo "$current" | cut -d. -f2)" ]; then
                UPDATE_TYPE="minor"
            fi
        fi

        log "Update type: $UPDATE_TYPE"

        # Create branch
        BRANCH_NAME="deps/update/$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr '/' '-')-$available"
        BRANCH_NAME=${BRANCH_NAME//[^a-zA-Z0-9-]/-}

        log "Creating branch: $BRANCH_NAME"

        # Checkout main first
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
            log "ERROR: Could not checkout main/master branch"
            continue
        }

        # Pull latest
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

        # Create and checkout new branch
        git checkout -b "$BRANCH_NAME" 2>/dev/null || {
            log "Branch $BRANCH_NAME already exists, skipping"
            continue
        }

        # Apply update (simplified - in production use proper Gradle plugins)
        log "Updating $name to $available..."

        # Find and replace version in build.gradle files
        find . -name "build.gradle*" -type f -exec sed -i "s/$name:$current/$name:$available/g" {} \; 2>/dev/null || true

        # Check if changes were made
        if git diff --quiet; then
            log "No changes made for $name, skipping"
            git checkout main 2>/dev/null || git checkout master 2>/dev/null
            git branch -D "$BRANCH_NAME" 2>/dev/null || true
            continue
        fi

        # Commit changes
        git add -A
        git commit -m "Update $name from $current to $available" || {
            log "Nothing to commit for $name"
            git checkout main 2>/dev/null || git checkout master 2>/dev/null
            git branch -D "$BRANCH_NAME" 2>/dev/null || true
            continue
        }

        # Push branch
        git push origin "$BRANCH_NAME" || {
            log "ERROR: Failed to push branch $BRANCH_NAME"
            git checkout main 2>/dev/null || git checkout master 2>/dev/null
            continue
        }

        # Create PR
        log "Creating pull request..."

        # Read PR template
        PR_BODY=""
        if [ -f "$PR_TEMPLATE" ]; then
            PR_BODY=$(cat "$PR_TEMPLATE")
            PR_BODY="${PR_BODY//{{DEPENDENCY_NAME}}/$name}"
            PR_BODY="${PR_BODY//{{OLD_VERSION}}/$current}"
            PR_BODY="${PR_BODY//{{NEW_VERSION}}/$available}"
            PR_BODY="${PR_BODY//{{UPDATE_TYPE}}/$UPDATE_TYPE}"
            PR_BODY="${PR_BODY//{{BRANCH_NAME}}/$BRANCH_NAME}"
        else
            PR_BODY="## Update $name

**Current version:** $current
**New version:** $available
**Update type:** $UPDATE_TYPE

### Changes
This PR updates $name to version $available.

### Testing
Please review and test the changes before merging."
        fi

        PR_URL=$(gh pr create \
            --title "deps: Update $name from $current to $available" \
            --body "$PR_BODY" \
            --base main \
            --head "$BRANCH_NAME" \
            --label "dependencies" \
            --label "automated" 2>&1 || echo "FAILED")

        if [[ "$PR_URL" == *"FAILED"* ]]; then
            log "WARNING: Failed to create PR for $name"
        else
            log "PR created: $PR_URL"

            # Extract PR number
            PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+' || echo "")

            # Store in database
            store_update_in_db "$name" "$current" "$available" "$UPDATE_TYPE" "$PR_NUMBER" "$PR_URL"
        fi

        # Return to main
        git checkout main 2>/dev/null || git checkout master 2>/dev/null

    done < ".deps-to-update.txt"

    return 0
}

# Store update information in database
store_update_in_db() {
    local dep_name="$1"
    local old_version="$2"
    local new_version="$3"
    local update_type="$4"
    local pr_number="$5"
    local pr_url="$6"

    log "Storing update in database..."

    PSQL_CMD="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c"

    $PSQL_CMD "INSERT INTO dependency_updates (
        dependency_name,
        old_version,
        new_version,
        update_type,
        status,
        pr_number,
        pr_url,
        created_at
    ) VALUES (
        '$dep_name',
        '$old_version',
        '$new_version',
        '$update_type',
        'pending',
        $pr_number,
        '$pr_url',
        NOW()
    );" 2>&1 || log "WARNING: Could not store in database"

    log "Database entry created"
}

# Main execution
main() {
    log "=== Starting Dependency Update Process ==="

    # Check prerequisites
    check_gh_cli
    get_repo_info

    # Check for updates
    if check_gradle_updates; then
        # Apply updates
        apply_updates

        log "=== Dependency Update Process Complete ==="
        log "Created PR(s) for dependency updates"
        log "Review and test before merging"
    else
        log "=== No Updates Found ==="
        log "All dependencies are up to date"
    fi

    # Cleanup
    rm -f "$REPO_ROOT/.deps-to-update.txt"
    rm -f "$REPO_ROOT/.gradle-deps.txt"

    log "Process finished at $(date)"
}

# Run main function
main "$@"
