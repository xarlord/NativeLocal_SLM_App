#!/bin/bash
# retry-command.sh
# Executes a command with exponential backoff retry logic
# Usage: retry-command.sh [--max-retries=N] [--backoff=exponential|linear] [--delay=SECONDS] <command>

set -e

# Default values
MAX_RETRIES=${MAX_RETRIES:-3}
BACKOFF_TYPE=${BACKOFF_TYPE:-exponential}
INITIAL_DELAY=${INITIAL_DELAY:-5}
MAX_DELAY=${MAX_DELAY:-300}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --max-retries=*)
      MAX_RETRIES="${1#*=}"
      shift
      ;;
    --backoff=*)
      BACKOFF_TYPE="${1#*=}"
      shift
      ;;
    --delay=*)
      INITIAL_DELAY="${1#*=}"
      shift
      ;;
    *)
      COMMAND="$@"
      break
      ;;
  esac
done

if [ -z "$COMMAND" ]; then
  echo "Error: No command specified"
  echo "Usage: $0 [--max-retries=N] [--backoff=exponential|linear] [--delay=SECONDS] <command>"
  exit 1
fi

# Check if we should retry based on exit code
is_transient_error() {
  local exit_code=$1

  # Common transient error codes
  # 1: General errors
  # 2: Misuse of shell builtins
  # 124: Timeout
  # 130: SIGINT (Ctrl+C)
  # 255: Unknown error

  case $exit_code in
    1|124|130|255)
      return 0  # Transient
      ;;
    *)
      return 1  # Non-transient
      ;;
  esac
}

# Execute with retry
attempt=1
current_delay=$INITIAL_DELAY

while true; do
  echo "[Attempt $attempt/$MAX_RETRIES] Executing: $COMMAND"

  # Execute command
  if eval "$COMMAND"; then
    echo "✅ Command succeeded on attempt $attempt"
    exit 0
  else
    exit_code=$?

    # Check if error is transient
    if ! is_transient_error $exit_code; then
      echo "❌ Non-transient error (exit code: $exit_code), not retrying"
      exit $exit_code
    fi

    # Check if we've exhausted retries
    if [ $attempt -ge $MAX_RETRIES ]; then
      echo "❌ Command failed after $MAX_RETRIES attempts (exit code: $exit_code)"
      exit $exit_code
    fi

    # Calculate delay
    case $BACKOFF_TYPE in
      exponential)
        delay=$((current_delay))
        current_delay=$((current_delay * 2))
        ;;
      linear)
        delay=$((current_delay))
        current_delay=$((current_delay + INITIAL_DELAY))
        ;;
      *)
        delay=$INITIAL_DELAY
        ;;
    esac

    # Cap delay at max
    if [ $delay -gt $MAX_DELAY ]; then
      delay=$MAX_DELAY
    fi

    echo "⚠️  Command failed (exit code: $exit_code), retrying in ${delay}s..."
    sleep $delay
    attempt=$((attempt + 1))
  fi
done
