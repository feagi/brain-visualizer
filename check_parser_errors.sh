#!/bin/bash
# Script to check Godot parser errors via CLI
# Usage: ./check_parser_errors.sh [res://path/to/script.gd]
# Without a path: editor scan of the project (only covers scripts the editor loads).
# With a path: --check-only on that script. Checked on its own, a script can't see the autoloads
# (BV, FeagiCore, ...), so "Identifier not found: <autoload>" and the "depended scripts" errors it
# causes are dropped; every other error is shown.

GODOT="${GODOT:-/Applications/Godot 4.7.app/Contents/MacOS/Godot}"
PROJECT_PATH="$(cd "$(dirname "$0")/godot_source" && pwd)"

echo "=== Checking Godot Parser Errors ==="
echo "Project: $PROJECT_PATH"
echo ""

if [ "$1" != "" ]; then
    echo "Checking specific file: $1"
    AUTOLOADS="$(sed -n '/^\[autoload\]/,/^\[/p' "$PROJECT_PATH/project.godot" | grep -E '^[A-Za-z_]+=' | cut -d= -f1 | paste -sd'|' -)"
    # Godot prints each error on one line and where it came from on the next.
    "$GODOT" --headless --path "$PROJECT_PATH" --check-only --script "$1" 2>&1 \
        | grep -E -A1 "(SCRIPT ERROR|Parse Error|ERROR)" \
        | grep -v -E "Identifier not found: ($AUTOLOADS)\$|Failed to compile depended scripts|Failed to load script .* with error \"Compilation failed\"|^ +at: |^--\$" \
        | head -50
else
    echo "Checking entire project..."
    "$GODOT" --headless --path "$PROJECT_PATH" --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|ERROR)" | head -100
fi

echo ""
echo "=== Done ==="
