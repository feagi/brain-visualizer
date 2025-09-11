#!/bin/bash

set -euo pipefail

# Absolute project paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$PROJECT_DIR/addons/feagi_rust_deserializer"
GDE_FILE="$ADDON_DIR/feagi_data_deserializer.gdextension"
GDE_FILE_OFF="$GDE_FILE.off"
TMP_BASE="/tmp"
TMP_STEM="brainviz-export--temp.$(date +%s)"
TMP_DIR="$TMP_BASE/$TMP_STEM"
TMP_PROJ="$TMP_DIR/project"

# Require explicit Godot binary path (no fallbacks)
GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  echo "ERROR: Set GODOT_BIN to your Godot 4 binary (e.g., /Applications/Godot.app/Contents/MacOS/Godot)." >&2
  exit 1
fi

# Output path: arg1 or default matching export preset location
OUT_PATH="${1:-$PROJECT_DIR/../../playground/public/static/godot/index.html}"
mkdir -p "$(dirname "$OUT_PATH")"

# Create a clean temp project copy excluding the native addon entirely
mkdir -p "$TMP_PROJ"
echo "Creating temp export project at $TMP_PROJ (excluding native addon)..."
rsync -a --delete \
  --exclude "addons/feagi_rust_deserializer/**" \
  "$PROJECT_DIR/" "$TMP_PROJ/"

set +e
"$GODOT_BIN" --headless --path "$TMP_PROJ" --export-release "Web" "$OUT_PATH"
EXPORT_STATUS=$?
set -e

# Cleanup temp project
rm -rf "$TMP_DIR"

# Also copy wasm assets alongside index.html so the browser can fetch them
OUT_DIR="$(dirname "$OUT_PATH")"
# Read the wasm dir from project settings; default to wasm/
WASM_DIR_SETTING=$(grep -E '^wasm_dir=' "$PROJECT_DIR/project.godot" | sed -E 's/^wasm_dir="(.*)"/\1/')
WASM_DIR_REL=${WASM_DIR_SETTING:-wasm/}
# Normalize trailing slash
case "$WASM_DIR_REL" in
  */) : ;;
  *) WASM_DIR_REL="$WASM_DIR_REL/" ;;
esac
SRC_WASM_DIR="$PROJECT_DIR/$WASM_DIR_REL"
DEST_WASM_DIR="$OUT_DIR/$WASM_DIR_REL"
if [[ -d "$SRC_WASM_DIR" ]]; then
  mkdir -p "$DEST_WASM_DIR"
  cp -f "$SRC_WASM_DIR/feagi_wasm_processing.js" "$DEST_WASM_DIR/" 2>/dev/null || true
  cp -f "$SRC_WASM_DIR/feagi_wasm_processing_bg.wasm" "$DEST_WASM_DIR/" 2>/dev/null || true
fi

exit $EXPORT_STATUS


