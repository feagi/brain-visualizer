#!/bin/bash
# Wrapper script to launch FEAGI subprocess from Brain Visualizer.app

# Get the directory where Brain Visualizer.app is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # Contents directory
RESOURCES_DIR="$APP_DIR/Resources"

# FEAGI binary location
FEAGI_BIN="$RESOURCES_DIR/bin/feagi"

# Log file location
LOG_FILE="/tmp/feagi_subprocess.log"

# Check if FEAGI binary exists
if [ ! -f "$FEAGI_BIN" ]; then
    echo "ERROR: FEAGI binary not found at: $FEAGI_BIN" | tee -a "$LOG_FILE" >&2
    exit 1
fi

# Change to /tmp so FEAGI can create its log directories
cd /tmp

# Launch FEAGI with logging
echo "========================================" >> "$LOG_FILE"
echo "🚀 FEAGI Launch: $(date)" >> "$LOG_FILE"
echo "   Binary: $FEAGI_BIN" >> "$LOG_FILE"
echo "   Args: $@" >> "$LOG_FILE"
echo "   Working Dir: $(pwd)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Just pass through all arguments - BV already handles --config
# Redirect stdout/stderr to log file
exec "$FEAGI_BIN" "$@" >> "$LOG_FILE" 2>&1
