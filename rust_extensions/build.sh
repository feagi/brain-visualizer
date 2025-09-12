#!/bin/bash

# Build script for FEAGI Rust extensions
# This script builds the Rust library and copies it to the Godot project

set -e  # Exit on any error

echo "🦀 Building FEAGI Rust Extensions..."

# Navigate to the Rust project directory
ROOT_DIR="$(dirname "$0")"

# Build feagi_data_deserializer
cd "$ROOT_DIR/feagi_data_deserializer"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cargo clean

# Build in release mode for optimal performance
echo "🔨 Building Rust library (release mode)..."
cargo build --release

# Check if build was successful
if [ ! -f "target/release/libfeagi_data_deserializer.dylib" ]; then
    echo "❌ Build failed - shared library not found!"
    exit 1
fi

echo "✅ Build successful!"

# Copy files to Godot project
echo "📁 Copying files to Godot project..."
GODOT_ADDON_DIR="../../godot_source/addons/feagi_rust_deserializer"

# Create addon directory if it doesn't exist
mkdir -p "$GODOT_ADDON_DIR"

# Create target directory structure in addon
mkdir -p "$GODOT_ADDON_DIR/target/release"
mkdir -p "$GODOT_ADDON_DIR/target/debug"

# Copy the shared library to the target structure
cp "target/release/libfeagi_data_deserializer.dylib" "$GODOT_ADDON_DIR/target/release/"

# Build and copy debug library for editor use
echo "🔨 Building Rust library (debug mode for editor)..."
cargo build
cp "target/debug/libfeagi_data_deserializer.dylib" "$GODOT_ADDON_DIR/target/debug/"

# Remove any old library files in the wrong location and avoid root copies
rm -f "$GODOT_ADDON_DIR/libfeagi_data_deserializer.dylib"

echo "✅ Files copied successfully!"

# Display file sizes for reference
echo "📊 Library size:"
ls -lh "$GODOT_ADDON_DIR/target/release/libfeagi_data_deserializer.dylib"

# On macOS, also build universal (arm64+x86_64) and overwrite debug/release for editor compatibility
if [[ "$(uname)" == "Darwin" ]]; then
  echo "🍎 Building universal (arm64+x86_64) binaries..."
  rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null 2>&1 || true
  # Release
  cargo build --release --target aarch64-apple-darwin
  cargo build --release --target x86_64-apple-darwin
  lipo -create -output target/universal_release.dylib \
    target/aarch64-apple-darwin/release/libfeagi_data_deserializer.dylib \
    target/x86_64-apple-darwin/release/libfeagi_data_deserializer.dylib
  cp target/universal_release.dylib "$GODOT_ADDON_DIR/target/release/libfeagi_data_deserializer.dylib"
  # Debug
  cargo build --target aarch64-apple-darwin
  cargo build --target x86_64-apple-darwin
  lipo -create -output target/universal_debug.dylib \
    target/aarch64-apple-darwin/debug/libfeagi_data_deserializer.dylib \
    target/x86_64-apple-darwin/debug/libfeagi_data_deserializer.dylib
  cp target/universal_debug.dylib "$GODOT_ADDON_DIR/target/debug/libfeagi_data_deserializer.dylib"
  echo "✅ Universal binaries installed."
fi

echo ""
echo "🎉 feagi_data_deserializer build complete!"
echo "💡 Restart Godot to load the new extension."
echo ""
echo "🧪 To test the integration, run the test_rust_deserializer.tscn scene in Godot."

# Build feagi_shared_video
echo "\n🦀 Building feagi_shared_video (shared memory reader)..."
cd "$ROOT_DIR/feagi_shared_video"
echo "🧹 Cleaning previous builds..."
cargo clean
echo "🔨 Building Rust library (release mode)..."
cargo build --release

if [ ! -f "target/release/libfeagi_shared_video.dylib" ]; then
    echo "❌ Build failed - feagi_shared_video shared library not found!"
    exit 1
fi

echo "✅ Build successful!"

GODOT_ADDON_DIR2="../../godot_source/addons/feagi_shared_video"
mkdir -p "$GODOT_ADDON_DIR2/target/release" "$GODOT_ADDON_DIR2/target/debug"
cp "target/release/libfeagi_shared_video.dylib" "$GODOT_ADDON_DIR2/target/release/"

echo "🔨 Building Rust library (debug mode for editor)..."
cargo build
cp "target/debug/libfeagi_shared_video.dylib" "$GODOT_ADDON_DIR2/target/debug/"
rm -f "$GODOT_ADDON_DIR2/libfeagi_shared_video.dylib"

echo "📊 Library size:"
ls -lh "$GODOT_ADDON_DIR2/target/release/libfeagi_shared_video.dylib"

if [[ "$(uname)" == "Darwin" ]]; then
  echo "🍎 Building universal (arm64+x86_64) binaries for feagi_shared_video..."
  rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null 2>&1 || true
  cargo build --release --target aarch64-apple-darwin
  cargo build --release --target x86_64-apple-darwin
  lipo -create -output target/universal_release.dylib \
    target/aarch64-apple-darwin/release/libfeagi_shared_video.dylib \
    target/x86_64-apple-darwin/release/libfeagi_shared_video.dylib
  cp target/universal_release.dylib "$GODOT_ADDON_DIR2/target/release/libfeagi_shared_video.dylib"
  cargo build --target aarch64-apple-darwin
  cargo build --target x86_64-apple-darwin
  lipo -create -output target/universal_debug.dylib \
    target/aarch64-apple-darwin/debug/libfeagi_shared_video.dylib \
    target/x86_64-apple-darwin/debug/libfeagi_shared_video.dylib
  cp target/universal_debug.dylib "$GODOT_ADDON_DIR2/target/debug/libfeagi_shared_video.dylib"
  echo "✅ Universal binaries installed (feagi_shared_video)."
fi

echo "\n🎉 All Rust extensions built successfully!"
