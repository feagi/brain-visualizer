#!/bin/bash
# Unix/macOS wrapper for the Python build script
# This allows users to continue running './build.sh' on Unix systems
#
# Usage:
#   ./build.sh                     # Build both debug and release
#   ./build.sh --release           # Build release only
#   ./build.sh --local-arch        # Build for local architecture only (faster)
#   ./build.sh --release --local-arch  # Combine options

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run the Python build script, passing through all command line arguments
python3 "$SCRIPT_DIR/build.py" "$@"
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "Build failed!"
    exit $exit_code
fi
