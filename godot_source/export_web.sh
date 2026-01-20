#!/bin/bash

set -euo pipefail

# Absolute project paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

echo "Creating clean temp export project at $TMP_PROJ (excluding native GDExtensions)..."

# Create a clean temp project copy excluding native GDExtensions entirely
mkdir -p "$TMP_PROJ"
rsync -a --delete \
  --exclude "addons/feagi_rust_deserializer/**" \
  --exclude "feagi_data_deserializer.gdextension" \
  --exclude "libfeagi_data_deserializer.*" \
  --exclude "addons/feagi_export_filter/**" \
  "$PROJECT_DIR/" "$TMP_PROJ/"

# Sanitize temp project: remove any lingering GDExtensions/libs
echo "Sanitizing temp project (removing any *.gdextension and native libs)..."
find "$TMP_PROJ" -type f -name "*.gdextension" -print -delete || true
find "$TMP_PROJ" -type f \( -name "libfeagi_data_deserializer.*" -o -name "feagi_data_deserializer.dll" -o -name "libfeagi_data_deserializer.so" \) -print -delete || true
rm -rf "$TMP_PROJ/addons/feagi_rust_deserializer" 2>/dev/null || true

# Copy .godot cache but sanitize GDExtension references
if [ -d "$PROJECT_DIR/.godot" ]; then
    echo "Copying and sanitizing .godot cache..."
    cp -r "$PROJECT_DIR/.godot" "$TMP_PROJ/.godot"
    # Remove GDExtension cache entries to prevent loading errors
    find "$TMP_PROJ/.godot" -name "*feagi_data_deserializer*" -delete 2>/dev/null || true
    find "$TMP_PROJ/.godot" -name "*.gdextension*" -delete 2>/dev/null || true
    # Remove extension manager cache that tracks loaded extensions
    rm -f "$TMP_PROJ/.godot/extension_list.cfg" 2>/dev/null || true
    rm -f "$TMP_PROJ/.godot/global_script_class_cache.cfg" 2>/dev/null || true
    # Clear any cached extension data
    find "$TMP_PROJ/.godot" -type f -name "*.cfg" -exec grep -l "feagi_data_deserializer\|FeagiDataDeserializer" {} \; -delete 2>/dev/null || true
fi

echo "Exporting to web..."
set +e
# Disable GDExtension loading explicitly during export
GODOT_DISABLE_GDEXTENSIONS=1 GODOT_NO_EXTENSIONS=1 "$GODOT_BIN" --headless --path "$TMP_PROJ" --export-release "Web" "$OUT_PATH"
EXPORT_STATUS=$?
set -e

# Cleanup temp project
echo "Cleaning up temp project..."
rm -rf "$TMP_DIR"

# Copy WASM assets alongside index.html so the browser can fetch them
echo "Copying WASM assets..."
OUT_DIR="$(dirname "$OUT_PATH")"
# Read the wasm dir from project settings; default to wasm/
WASM_DIR_SETTING=$(grep -E '^wasm_dir=' "$PROJECT_DIR/project.godot" | sed -E 's/^wasm_dir="(.*)"/\1/' || echo "")
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
  echo "Copying WASM files from $SRC_WASM_DIR to $DEST_WASM_DIR"
  cp -f "$SRC_WASM_DIR/feagi_wasm_processing.js" "$DEST_WASM_DIR/" 2>/dev/null || echo "Warning: feagi_wasm_processing.js not found"
  cp -f "$SRC_WASM_DIR/feagi_wasm_processing_bg.wasm" "$DEST_WASM_DIR/" 2>/dev/null || echo "Warning: feagi_wasm_processing_bg.wasm not found"
else
  echo "Warning: WASM directory $SRC_WASM_DIR not found - web build may not have WASM decoder"
fi

if [[ $EXPORT_STATUS -eq 0 ]]; then
  echo "✅ Web export completed successfully!"
  echo "📁 Output: $OUT_PATH"
  if [[ -d "$DEST_WASM_DIR" ]]; then
    echo "🦀 WASM assets: $DEST_WASM_DIR"
  fi
else
  echo "❌ Web export failed with status $EXPORT_STATUS"
fi

exit $EXPORT_STATUS