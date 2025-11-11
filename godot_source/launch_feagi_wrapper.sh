#!/bin/bash
# FEAGI launch wrapper - ensures writable working directory

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create a writable working directory for FEAGI logs
# Use ~/Library/Application Support which is standard for macOS apps
FEAGI_WORK_DIR="$HOME/Library/Application Support/BrainVisualizer/feagi"
mkdir -p "$FEAGI_WORK_DIR"

# Change to writable directory before launching FEAGI
cd "$FEAGI_WORK_DIR" || exit 1

# Log file for debugging
LOG_FILE="$HOME/Library/Logs/BrainVisualizer/feagi_launch.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log the launch attempt
{
    echo "=== FEAGI Launch Attempt ===" 
    echo "Time: $(date)"
    echo "Working dir: $(pwd)"
    echo "Args: $*"
    echo ""
} >> "$LOG_FILE" 2>&1

# Execute FEAGI from writable directory
"$SCRIPT_DIR/../Resources/bin/feagi" "$@" >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

# Log the result
{
    echo "Exit code: $EXIT_CODE"
    echo "==========================="
    echo ""
} >> "$LOG_FILE" 2>&1

exit $EXIT_CODE

