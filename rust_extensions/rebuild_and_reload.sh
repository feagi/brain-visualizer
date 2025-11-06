#!/bin/bash
# Complete rebuild and reload script for FEAGI embedded extension
# Handles: build, copy, cache clear, Godot restart prompt

set -e

echo "🔨 Complete FEAGI Embedded Rebuild and Reload"
echo "=============================================="

# 1. Build
echo "Step 1: Building FEAGI embedded..."
cd feagi_embedded
cargo build --release
cd ..

# 2. Copy to Godot
echo "Step 2: Copying to Godot addons..."
mkdir -p ../godot_source/addons/feagi_embedded/target/release
cp feagi_embedded/target/release/libfeagi_embedded.dylib \
   ../godot_source/addons/feagi_embedded/target/release/

# 3. Verify
ls -lh ../godot_source/addons/feagi_embedded/target/release/libfeagi_embedded.dylib

# 4. Kill Godot if running
echo "Step 3: Killing Godot (if running)..."
pkill -9 Godot 2>/dev/null || echo "  (Godot not running)"

# 5. Clear Godot cache
echo "Step 4: Clearing Godot cache..."
rm -rf ../godot_source/.godot
echo "  ✅ Cache cleared"

# 6. Fix .gdextension file (ensure correct format)
echo "Step 5: Ensuring .gdextension file is correct..."
cat > ../godot_source/addons/feagi_embedded/feagi_embedded.gdextension << 'EOF'
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1
reloadable = false

[libraries]
macos.debug = "target/release/libfeagi_embedded.dylib"
macos.release = "target/release/libfeagi_embedded.dylib"
windows.debug.x86_64 = "target/debug/feagi_embedded.dll"
windows.release.x86_64 = "target/release/feagi_embedded.dll"
linux.debug.x86_64 = "target/debug/libfeagi_embedded.so"
linux.release.x86_64 = "target/release/libfeagi_embedded.so"
EOF

echo "  ✅ .gdextension file updated"

echo ""
echo "=============================================="
echo "✅ Build complete!"
echo "=============================================="
echo ""
echo "📖 Next steps:"
echo "  1. Open Godot: cd ../godot_source && open -a Godot ."
echo "  2. Press F5 to run"
echo ""

