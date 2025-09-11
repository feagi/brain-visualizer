#!/bin/bash

set -euo pipefail

# Absolute project paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$PROJECT_DIR/addons/feagi_rust_deserializer"
GDE_FILE="$ADDON_DIR/feagi_data_deserializer.gdextension"
GDE_FILE_OFF="$GDE_FILE.off"
TMP_BASE="/tmp"
TMP_STEM="feagi_rust_deserializer--temp.$(date +%s)"
TMP_DIR="$TMP_BASE/$TMP_STEM"

# Require explicit Godot binary path (no fallbacks)
GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  echo "ERROR: Set GODOT_BIN to your Godot 4 binary (e.g., /Applications/Godot.app/Contents/MacOS/Godot)." >&2
  exit 1
fi

# Output path: arg1 or default matching export preset location
OUT_PATH="${1:-$PROJECT_DIR/../playground/public/static/godot/index.html}"
mkdir -p "$(dirname "$OUT_PATH")"

# Rename the .gdextension to prevent early scan warnings
RENAMED=0
if [[ -f "$GDE_FILE" ]]; then
  echo "Temporarily renaming $GDE_FILE -> $GDE_FILE_OFF ..."
  mv "$GDE_FILE" "$GDE_FILE_OFF"
  RENAMED=1
fi

# Also move the entire addon directory out so it cannot be packed into the PCK
MOVED=0
if [[ -d "$ADDON_DIR" ]]; then
  mkdir -p "$TMP_DIR"
  echo "Temporarily moving addon dir to $TMP_DIR ..."
  mv "$ADDON_DIR" "$TMP_DIR/"
  MOVED=1
fi

set +e
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$OUT_PATH"
EXPORT_STATUS=$?
set -e

if [[ "$RENAMED" -eq 1 ]]; then
  mv "$GDE_FILE_OFF" "$GDE_FILE"
fi

if [[ "$MOVED" -eq 1 ]]; then
  mv "$TMP_DIR/feagi_rust_deserializer" "$PROJECT_DIR/addons/"
  rmdir "$TMP_DIR" || true
fi

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


