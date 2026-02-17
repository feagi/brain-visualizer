#!/bin/bash
# Build script for feagi_data_deserializer Rust extension.
# Builds the Rust library and copies it to where feagi_data_deserializer.gdextension expects it.
# Must be run from this directory (rust_extensions/feagi_data_deserializer).
# For CI and multi-platform builds, use rust_extensions/build.py instead.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Destination: addons/FeagiCoreIntegration (paths under it must match .gdextension)
GODOT_ADDON_DIR="${SCRIPT_DIR}/../../godot_source/addons/FeagiCoreIntegration"
if [ ! -d "$(dirname "$GODOT_ADDON_DIR")" ]; then
    echo "[ERROR] Godot addon directory not found: $GODOT_ADDON_DIR (run from rust_extensions/feagi_data_deserializer)"
    exit 1
fi

echo "[BUILD] FEAGI Data Deserializer (release)..."
cargo build --release --locked

PLATFORM=$(uname -s)
case "$PLATFORM" in
    Darwin)
        # .gdextension: macos.release = "libfeagi_data_deserializer.dylib" (same dir as .gdextension)
        SRC="target/release/libfeagi_data_deserializer.dylib"
        if [ ! -f "$SRC" ]; then
            echo "[ERROR] Build failed - library not found: $SRC"
            exit 1
        fi
        mkdir -p "$GODOT_ADDON_DIR"
        cp "$SRC" "$GODOT_ADDON_DIR/"
        echo "[OK] Copied to $GODOT_ADDON_DIR/libfeagi_data_deserializer.dylib"
        ;;
    Linux)
        # .gdextension: linux.release.x86_64 = "target/x86_64-unknown-linux-gnu/release/libfeagi_data_deserializer.so"
        TARGET_TRIPLE="x86_64-unknown-linux-gnu"
        SRC="target/release/libfeagi_data_deserializer.so"
        DEST_DIR="$GODOT_ADDON_DIR/target/$TARGET_TRIPLE/release"
        if [ ! -f "$SRC" ]; then
            echo "[ERROR] Build failed - library not found: $SRC"
            exit 1
        fi
        mkdir -p "$DEST_DIR"
        cp "$SRC" "$DEST_DIR/"
        echo "[OK] Copied to $DEST_DIR/libfeagi_data_deserializer.so"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # .gdextension: windows.release.x86_64 = "target/x86_64-pc-windows-msvc/release/feagi_data_deserializer.dll"
        TARGET_TRIPLE="x86_64-pc-windows-msvc"
        SRC="target/release/feagi_data_deserializer.dll"
        DEST_DIR="$GODOT_ADDON_DIR/target/$TARGET_TRIPLE/release"
        if [ ! -f "$SRC" ]; then
            echo "[ERROR] Build failed - library not found: $SRC"
            exit 1
        fi
        mkdir -p "$DEST_DIR"
        cp "$SRC" "$DEST_DIR/"
        echo "[OK] Copied to $DEST_DIR/feagi_data_deserializer.dll"
        ;;
    *)
        echo "[ERROR] Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

echo "[DONE] Build complete. Restart Godot to load the extension."
