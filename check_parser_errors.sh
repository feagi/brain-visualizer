#!/bin/bash
# Script to check Godot parser errors via CLI

GODOT="/Applications/Godot45.app/Contents/MacOS/Godot"
PROJECT_PATH="/Users/nadji/code/FEAGI-2.0/brain-visualizer"

echo "=== Checking Godot Parser Errors ==="
echo "Project: $PROJECT_PATH"
echo ""

# Check if specific file was provided
if [ "$1" != "" ]; then
    echo "Checking specific file: $1"
    cd "$PROJECT_PATH"
    "$GODOT" --headless --script "$1" --check-only 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|ERROR)" | head -50
else
    echo "Checking entire project..."
    "$GODOT" --headless --path "$PROJECT_PATH" --editor --quit 2>&1 | grep -E "(SCRIPT ERROR|Parse Error|ERROR)" | head -100
fi

echo ""
echo "=== Done ==="


