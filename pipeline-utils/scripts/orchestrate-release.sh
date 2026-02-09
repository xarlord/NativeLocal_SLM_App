#!/bin/bash
set -euo pipefail

# Automated Release Orchestration Script
# Coordinates the entire release process: version bump, changelog, build, sign, deploy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${MAGENTA}[STEP]${NC} $*"; }

# Configuration
AUTO_BUMP="${AUTO_BUMP:-true}"
CREATE_GITHUB_RELEASE="${CREATE_GITHUB_RELEASE:-true}"
DEPLOY_PLAY_STORE="${DEPLOY_PLAY_STORE:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"

cd "$PROJECT_ROOT"

# Step 1: Pre-flight checks
step_1_preflight() {
    log_step "1/7: Pre-flight Checks"
    echo ""

    # Check if we're on main branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        log_warning "Not on main/master branch (current: $CURRENT_BRANCH)"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Release cancelled"
            exit 0
        fi
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_error "Uncommitted changes detected"
        git status --short
        exit 1
    fi

    # Check if scripts exist
    if [ ! -f "${SCRIPT_DIR}/bump-version.sh" ]; then
        log_error "bump-version.sh not found"
        exit 1
    fi

    if [ ! -f "${SCRIPT_DIR}/generate-changelog.sh" ]; then
        log_error "generate-changelog.sh not found"
        exit 1
    fi

    log_success "Pre-flight checks passed"
    echo ""
}

# Step 2: Run tests
step_2_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_step "2/7: Tests (SKIPPED)"
        echo ""
        return
    fi

    log_step "2/7: Running Tests"
    echo ""

    log_info "Running unit tests..."
    if ./gradlew test --stacktrace; then
        log_success "Tests passed"
    else
        log_error "Tests failed"
        exit 1
    fi
    echo ""
}

# Step 3: Bump version
step_3_version() {
    log_step "3/7: Version Bump"
    echo ""

    if [ "$AUTO_BUMP" = "true" ]; then
        NEW_VERSION=$("${SCRIPT_DIR}/bump-version.sh" --auto)
    else
        CURRENT_VERSION=$(cat .version 2>/dev/null || echo "0.0.0")
        log_info "Current version: $CURRENT_VERSION"
        read -p "Bump type (major/minor/patch): " bump_type
        NEW_VERSION=$("${SCRIPT_DIR}/bump-version.sh" "$bump_type")
    fi

    log_success "Version bumped to: $NEW_VERSION"
    echo ""
}

# Step 4: Generate changelog
step_4_changelog() {
    log_step "4/7: Changelog Generation"
    echo ""

    "${SCRIPT_DIR}/generate-changelog.sh" "$NEW_VERSION"
    log_success "Changelog generated"
    echo ""
}

# Step 5: Build APK
step_5_build() {
    log_step "5/7: Building APK"
    echo ""

    log_info "Building release APK..."
    ./gradlew assembleRelease --stacktrace

    APK=$(find . -name "*-release.apk" -type f | head -n 1)
    if [ -z "$APK" ]; then
        log_error "APK not found"
        exit 1
    fi

    log_success "APK built: $APK"
    echo ""
}

# Step 6: Sign APK
step_6_sign() {
    log_step "6/7: Signing APK"
    echo ""

    if [ -z "${KEYSTORE_PATH:-}" ]; then
        log_warning "KEYSTORE_PATH not set, skipping signing"
        return
    fi

    SIGNED_APK=$("${SCRIPT_DIR}/sign-apk.sh" "$APK")
    log_success "APK signed: $SIGNED_APK"
    echo ""
}

# Step 7: Deploy
step_7_deploy() {
    log_step "7/7: Deployment"
    echo ""

    # Commit version and changelog
    log_info "Committing version and changelog..."
    git add .version CHANGELOG.md
    git commit -m "chore: release v$NEW_VERSION"
    git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

    # Create GitHub release
    if [ "$CREATE_GITHUB_RELEASE" = "true" ] && [ -n "${SIGNED_APK:-$APK}" ]; then
        log_info "Creating GitHub release..."
        "${SCRIPT_DIR}/create-github-release.sh" "v$NEW_VERSION" "${SIGNED_APK:-$APK}"
    fi

    # Deploy to Play Store
    if [ "$DEPLOY_PLAY_STORE" = "true" ] && [ -n "${SIGNED_APK:-}" ]; then
        log_info "Deploying to Play Store..."
        "${SCRIPT_DIR}/deploy-play-store.sh" "$SIGNED_APK"
    fi

    # Push to GitHub
    log_info "Pushing to GitHub..."
    git push origin "$CURRENT_BRANCH"
    git push origin "v$NEW_VERSION"

    log_success "Deployment complete"
    echo ""
}

# Main orchestration
main() {
    log_info "=== Automated Release Orchestration ==="
    echo ""

    step_1_preflight
    step_2_tests
    step_3_version
    step_4_changelog
    step_5_build
    step_6_sign
    step_7_deploy

    log_success "=== Release Complete ==="
    log_info "Version: $NEW_VERSION"
    log_info "Artifacts: ${SIGNED_APK:-$APK}"
}

# Execute
main "$@"
