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
ROOT_GDE="$PROJECT_DIR/feagi_data_deserializer.gdextension"
ROOT_GDE_OFF="$ROOT_GDE.off"

# Require explicit Godot binary path (no fallbacks)
GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  echo "ERROR: Set GODOT_BIN to your Godot 4 binary (e.g., /Applications/Godot.app/Contents/MacOS/Godot)." >&2
  exit 1
fi

# Output path: arg1 or default matching export preset location
OUT_PATH="${1:-$PROJECT_DIR/../../playground/public/static/godot/index.html}"
mkdir -p "$(dirname "$OUT_PATH")"

# Temporarily hide native extensions in source project to avoid early scans
RENAMED_ROOT=0
if [[ -f "$ROOT_GDE" ]]; then
  echo "Temporarily renaming $ROOT_GDE -> $ROOT_GDE_OFF ..."
  mv "$ROOT_GDE" "$ROOT_GDE_OFF"
  RENAMED_ROOT=1
fi
MOVED_ADDON=0
if [[ -d "$ADDON_DIR" ]]; then
  mkdir -p "$TMP_DIR"
  echo "Temporarily moving addon dir to $TMP_DIR ..."
  mv "$ADDON_DIR" "$TMP_DIR/"
  MOVED_ADDON=1
fi

# Create a clean temp project copy excluding the native addon entirely
mkdir -p "$TMP_PROJ"
echo "Creating temp export project at $TMP_PROJ (excluding native addon)..."
rsync -a --delete \
  --exclude "addons/feagi_rust_deserializer/**" \
  --exclude "feagi_data_deserializer.gdextension" \
  --exclude "libfeagi_data_deserializer.*" \
  --exclude "addons/feagi_export_filter/**" \
  "$PROJECT_DIR/" "$TMP_PROJ/"

# Hard guard: remove any lingering GDExtensions/libs in temp project
echo "Sanitizing temp project (removing any *.gdextension and *feagi_data_deserializer* libs)..."
find "$TMP_PROJ" -type f -name "*.gdextension" -print -delete || true
find "$TMP_PROJ" -type f \( -name "libfeagi_data_deserializer.*" -o -name "feagi_data_deserializer.dll" -o -name "libfeagi_data_deserializer.so" \) -print -delete || true
rm -rf "$TMP_PROJ/addons/feagi_rust_deserializer" 2>/dev/null || true
# Copy .godot cache but remove GDExtension references
if [ -d "$PROJECT_DIR/.godot" ]; then
    cp -r "$PROJECT_DIR/.godot" "$TMP_PROJ/.godot"
    # Remove GDExtension cache entries to prevent loading errors
    find "$TMP_PROJ/.godot" -name "*feagi_data_deserializer*" -delete 2>/dev/null || true
    find "$TMP_PROJ/.godot" -name "*.gdextension*" -delete 2>/dev/null || true
    # Remove extension manager cache that tracks loaded extensions
    rm -rf "$TMP_PROJ/.godot/extension_list.cfg" 2>/dev/null || true
    rm -rf "$TMP_PROJ/.godot/global_script_class_cache.cfg" 2>/dev/null || true
    # Clear any cached extension data
    find "$TMP_PROJ/.godot" -type f -name "*.cfg" -exec grep -l "feagi_data_deserializer\|FeagiDataDeserializer" {} \; -delete 2>/dev/null || true
fi

set +e
# Disable GDExtension loading explicitly during export (env guards)
GODOT_DISABLE_GDEXTENSIONS=1 GODOT_NO_EXTENSIONS=1 "$GODOT_BIN" --headless --path "$TMP_PROJ" --export-release "Web" "$OUT_PATH"
EXPORT_STATUS=$?
set -e

# Restore source project items BEFORE cleanup
if [[ "$MOVED_ADDON" -eq 1 ]]; then
  echo "Restoring addon directory..."
  mv "$TMP_DIR/feagi_rust_deserializer" "$PROJECT_DIR/addons/" 2>/dev/null || true
fi

# Cleanup temp project
rm -rf "$TMP_DIR"
if [[ "$RENAMED_ROOT" -eq 1 ]]; then
  mv "$ROOT_GDE_OFF" "$ROOT_GDE" 2>/dev/null || true
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


