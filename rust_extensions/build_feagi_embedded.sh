#!/bin/bash
# Build script for FEAGI Embedded GDExtension
#
# This builds the complete FEAGI engine as a Godot extension for desktop platforms.
# WARNING: This is a LARGE build (2-5 minutes) as it includes the entire FEAGI stack.
#
# Usage:
#   ./build_feagi_embedded.sh              # Build release
#   ./build_feagi_embedded.sh --debug      # Build debug
#   ./build_feagi_embedded.sh --clean      # Clean and build release

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/feagi_embedded"
ADDON_DIR="$SCRIPT_DIR/../godot_source/addons/feagi_embedded"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "  FEAGI Embedded GDExtension Builder"
echo "========================================="
echo ""

# Parse arguments
MODE="release"
CLEAN=false
for arg in "$@"; do
    case $arg in
        --debug)
            MODE="debug"
            ;;
        --clean)
            CLEAN=true
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--debug] [--clean]"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}⚠️  WARNING: This is a LARGE build!${NC}"
echo -e "${YELLOW}   - Build time: 2-5 minutes${NC}"
echo -e "${YELLOW}   - Desktop only (macOS, Windows, Linux)${NC}"
echo -e "${YELLOW}   - Includes entire FEAGI stack${NC}"
echo ""
echo "Build mode: $MODE"
echo ""

cd "$PROJECT_DIR"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "🧹 Cleaning previous builds..."
    cargo clean
fi

# Build
echo "🔨 Building FEAGI Embedded ($MODE)..."
if [ "$MODE" = "debug" ]; then
    cargo build
else
    cargo build --release
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Copy to Godot addons
echo "📦 Installing to Godot..."
mkdir -p "$ADDON_DIR/target/$MODE"

# Determine library name based on platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_NAME="libfeagi_embedded.dylib"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LIB_NAME="libfeagi_embedded.so"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    LIB_NAME="feagi_embedded.dll"
else
    echo -e "${RED}❌ Unsupported platform: $OSTYPE${NC}"
    exit 1
fi

# Copy library
cp "target/$MODE/$LIB_NAME" "$ADDON_DIR/target/$MODE/$LIB_NAME"
echo -e "${GREEN}✅ Installed: $ADDON_DIR/target/$MODE/$LIB_NAME${NC}"

# Copy .gdextension file
cp "feagi_embedded.gdextension" "$ADDON_DIR/feagi_embedded.gdextension"
echo -e "${GREEN}✅ Installed: $ADDON_DIR/feagi_embedded.gdextension${NC}"

echo ""
echo "========================================="
echo -e "${GREEN}✅ FEAGI Embedded build complete!${NC}"
echo "========================================="
echo ""
echo "💡 Next steps:"
echo "  1. Restart Godot to load the extension"
echo "  2. In GDScript:"
echo "     var feagi = FeagiEmbedded.new()"
echo "     feagi.initialize_default()"
echo "     feagi.start()"
echo ""
echo "📖 See: brain-visualizer/docs/FEAGI_EMBEDDED_IN_PROCESS_PROPOSAL.md"

