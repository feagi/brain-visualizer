#!/bin/bash
# Unix/macOS wrapper for the Python build script
# This allows users to continue running './build.sh' on Unix systems

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run the Python build script
python3 "$SCRIPT_DIR/build.py"
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "Build failed!"
    exit $exit_code
fi
