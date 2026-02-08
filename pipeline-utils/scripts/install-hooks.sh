#!/bin/bash
# install-hooks.sh
# Installs pre-commit hooks to .git/hooks directory
# Supports Windows (Git Bash), macOS, and Linux

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

# Detect OS
detect_os() {
    local os_name=""
    case "$(uname -s)" in
        Linux*)     os_name="linux" ;;
        Darwin*)    os_name="macos" ;;
        MINGW*|MSYS*|CYGWIN*) os_name="windows" ;;
        *)          os_name="unknown" ;;
    esac
    echo "$os_name"
}

# Detect .git/hooks directory
detect_git_hooks_dir() {
    log "Detecting Git hooks directory..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not a Git repository"
        log "Initialize with: git init"
        return 1
    fi

    # Get .git directory (handles worktree cases)
    local git_dir
    git_dir=$(git rev-parse --git-dir)

    GIT_HOOKS_DIR="${git_dir}/hooks"
    log_success "Found hooks directory: ${GIT_HOOKS_DIR}"

    # Create hooks directory if it doesn't exist
    if [[ ! -d "${GIT_HOOKS_DIR}" ]]; then
        log "Creating hooks directory..."
        mkdir -p "${GIT_HOOKS_DIR}"
        log_success "Created hooks directory"
    fi

    return 0
}

# Get pre-commit hook template
get_hook_template() {
    cat <<'EOF'
#!/bin/bash
# Pre-commit hook installed by pipeline-utils
# Runs format, lint, test, and secrets checks before commit

set -e

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/pipeline-utils/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Running Pre-commit Checks ===${NC}"
echo ""

# Track overall status
ALL_PASSED=true
CHECK_START_TIME=$(date +%s)

# Run format check
if [ -f "${HOOKS_DIR}/pre-commit-format.sh" ]; then
    echo -e "${BLUE}[1/5] Running format check...${NC}"
    if "${HOOKS_DIR}/pre-commit-format.sh"; then
        echo -e "${GREEN}✓ Format check passed${NC}"
    else
        echo -e "${RED}✗ Format check failed${NC}"
        ALL_PASSED=false
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Format check script not found, skipping${NC}"
    echo ""
fi

# Run lint check
if [ -f "${HOOKS_DIR}/pre-commit-lint.sh" ]; then
    echo -e "${BLUE}[2/5] Running lint check...${NC}"
    if "${HOOKS_DIR}/pre-commit-lint.sh"; then
        echo -e "${GREEN}✓ Lint check passed${NC}"
    else
        echo -e "${RED}✗ Lint check failed${NC}"
        ALL_PASSED=false
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Lint check script not found, skipping${NC}"
    echo ""
fi

# Run tests
if [ -f "${HOOKS_DIR}/pre-commit-tests.sh" ]; then
    echo -e "${BLUE}[3/5] Running tests...${NC}"
    if "${HOOKS_DIR}/pre-commit-tests.sh"; then
        echo -e "${GREEN}✓ Tests passed${NC}"
    else
        echo -e "${RED}✗ Tests failed${NC}"
        ALL_PASSED=false
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Test script not found, skipping${NC}"
    echo ""
fi

# Run secrets scan
if [ -f "${HOOKS_DIR}/pre-commit-secrets.sh" ]; then
    echo -e "${BLUE}[4/5] Scanning for secrets...${NC}"
    if "${HOOKS_DIR}/pre-commit-secrets.sh"; then
        echo -e "${GREEN}✓ Secrets scan passed${NC}"
    else
        echo -e "${RED}✗ Secrets scan failed${NC}"
        ALL_PASSED=false
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Secrets scan script not found, skipping${NC}"
    echo ""
fi

# Generate summary
if [ -f "${HOOKS_DIR}/pre-commit-summary.sh" ]; then
    echo -e "${BLUE}[5/5] Generating summary...${NC}"
    "${HOOKS_DIR}/pre-commit-summary.sh"
    echo ""
fi

# Calculate duration
CHECK_END_TIME=$(date +%s)
CHECK_DURATION=$((CHECK_END_TIME - CHECK_START_TIME))

# Final status
echo ""
echo -e "${BLUE}=== Pre-commit Checks Complete ===${NC}"
echo -e "Duration: ${CHECK_DURATION}s"

if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✓ All checks passed! Committing...${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some checks failed. Commit blocked.${NC}"
    echo ""
    echo "To bypass these checks (not recommended):"
    echo "  git commit --no-verify"
    echo ""
    echo "To fix formatting issues:"
    echo "  ./gradlew ktlintFormat"
    echo ""
    exit 1
fi
EOF
}

# Create pre-commit hook
create_pre_commit_hook() {
    log "Creating pre-commit hook..."

    local hook_file="${GIT_HOOKS_DIR}/pre-commit"

    # Backup existing hook if present
    if [[ -f "${hook_file}" ]]; then
        local backup_file="${hook_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Existing pre-commit hook found, backing up to: ${backup_file}"
        cp "${hook_file}" "${backup_file}"
    fi

    # Write new hook
    get_hook_template > "${hook_file}"

    # Make hook executable (skip on Windows as chmod doesn't work there)
    if [[ "$(detect_os)" != "windows" ]]; then
        chmod +x "${hook_file}" 2>/dev/null || true
    fi

    log_success "Pre-commit hook created at: ${hook_file}"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."

    local hook_file="${GIT_HOOKS_DIR}/pre-commit"

    # Check if hook exists
    if [[ ! -f "${hook_file}" ]]; then
        log_error "Hook file not found: ${hook_file}"
        return 1
    fi

    # Check if hook is executable (skip on Windows)
    if [[ "$(detect_os)" != "windows" ]]; then
        if [[ ! -x "${hook_file}" ]]; then
            log_error "Hook file is not executable: ${hook_file}"
            return 1
        fi
    fi

    # Check if hook contains expected content
    if ! grep -q "pipeline-utils/scripts" "${hook_file}"; then
        log_error "Hook file does not contain expected content"
        return 1
    fi

    log_success "Installation verified successfully"

    # List installed hooks
    echo ""
    log "Installed pre-commit hooks:"
    echo "  - pre-commit"

    return 0
}

# Create .pre-commit-config.yaml
create_config_file() {
    log "Creating .pre-commit-config.yaml..."

    local config_file="${PROJECT_ROOT}/.pre-commit-config.yaml"

    # Backup existing config if present
    if [[ -f "${config_file}" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Existing config file found, backing up to: ${backup_file}"
        cp "${config_file}" "${backup_file}"
    fi

    cat > "${config_file}" <<'EOF'
# Pre-commit hooks configuration
# This file defines which checks run before commits

hooks:
  - name: format
    script: pipeline-utils/scripts/pre-commit-format.sh
    description: Check code formatting with ktlint
    pass_fail: true

  - name: lint
    script: pipeline-utils/scripts/pre-commit-lint.sh
    description: Run Android lint checks
    pass_fail: true

  - name: tests
    script: pipeline-utils/scripts/pre-commit-tests.sh
    description: Run quick unit tests
    pass_fail: true

  - name: secrets
    script: pipeline-utils/scripts/pre-commit-secrets.sh
    description: Scan for secrets with trufflehog
    pass_fail: true

# Configuration options
options:
  # Skip hooks (use git commit --no-verify to bypass)
  skip_on_merge: false

  # Timeout for each hook (in seconds)
  timeout: 300

  # Minimum log level (debug, info, warn, error)
  log_level: info
EOF

    log_success "Configuration file created at: ${config_file}"
}

# Print usage instructions
print_usage() {
    echo ""
    log "=== Usage Instructions ==="
    echo ""
    echo "The pre-commit hooks are now installed and will run automatically"
    echo "when you run 'git commit'."
    echo ""
    echo "To bypass the hooks (not recommended):"
    echo "  git commit --no-verify -m 'Your commit message'"
    echo ""
    echo "To manually run all checks:"
    echo "  .git/hooks/pre-commit"
    echo ""
    echo "To uninstall:"
    echo "  rm .git/hooks/pre-commit"
    echo ""
    echo "Individual checks can be run directly:"
    echo "  ./pipeline-utils/scripts/pre-commit-format.sh"
    echo "  ./pipeline-utils/scripts/pre-commit-lint.sh"
    echo "  ./pipeline-utils/scripts/pre-commit-tests.sh"
    echo "  ./pipeline-utils/scripts/pre-commit-secrets.sh"
    echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
    echo ""
    log "=== Pre-commit Hooks Installation ==="
    echo ""

    # Detect OS
    local os_type
    os_type=$(detect_os)
    log "Detected OS: ${os_type}"

    # Detect git hooks directory
    if ! detect_git_hooks_dir; then
        log_error "Failed to detect Git hooks directory"
        exit 1
    fi

    echo ""

    # Create pre-commit hook
    create_pre_commit_hook

    # Create config file
    create_config_file

    echo ""

    # Verify installation
    if verify_installation; then
        echo ""
        log_success "Pre-commit hooks installed successfully!"
        print_usage
        exit 0
    else
        echo ""
        log_error "Installation verification failed"
        exit 1
    fi
}

# Run main function
main "$@"
