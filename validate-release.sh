#!/bin/bash
# Validation script for release workflow
# Checks build paths, .gdextension files, and workflow syntax

# Don't use set -e because grep returns non-zero on no match (expected behavior)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔍 Validating release workflow configuration..."
echo ""

ERRORS=0
WARNINGS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_error() {
    echo -e "${RED}❌ $1${NC}"
    ((ERRORS++))
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

check_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 1. Validate workflow YAML syntax
echo "1. Validating workflow YAML syntax..."
if command -v yamllint &> /dev/null; then
    if yamllint .github/workflows/release.yml &> /dev/null; then
        check_success "Workflow YAML syntax is valid"
    else
        check_error "Workflow YAML has syntax errors (run: yamllint .github/workflows/release.yml)"
    fi
else
    check_warning "yamllint not installed (optional: pip install yamllint)"
fi

# 2. Check if build.py copies to correct paths expected by .gdextension files
echo ""
echo "2. Validating build.py copy paths match .gdextension expectations..."

PLATFORM=$(uname -s)
case "$PLATFORM" in
    Linux)
        PLATFORM_NAME="linux"
        TARGET_TRIPLE="x86_64-unknown-linux-gnu"
        DESERIALIZER_PATH="godot_source/addons/FeagiCoreIntegration/target/${TARGET_TRIPLE}/release/libfeagi_data_deserializer.so"
        TYPE_SYSTEM_PATH="godot_source/addons/FeagiCoreIntegration/libfeagi_type_system.so"
        SHARED_VIDEO_PATH="godot_source/addons/feagi_shared_video/target/${TARGET_TRIPLE}/release/libfeagi_shared_video.so"
        ;;
    Darwin)
        PLATFORM_NAME="macos"
        DESERIALIZER_PATH="godot_source/addons/FeagiCoreIntegration/libfeagi_data_deserializer.dylib"
        TYPE_SYSTEM_PATH="godot_source/addons/FeagiCoreIntegration/libfeagi_type_system.dylib"
        SHARED_VIDEO_PATH="godot_source/addons/feagi_shared_video/target/release/libfeagi_shared_video.dylib"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM_NAME="windows"
        TARGET_TRIPLE="x86_64-pc-windows-msvc"
        DESERIALIZER_PATH="godot_source/addons/FeagiCoreIntegration/target/${TARGET_TRIPLE}/release/feagi_data_deserializer.dll"
        TYPE_SYSTEM_PATH="godot_source/addons/FeagiCoreIntegration/feagi_type_system.dll"
        SHARED_VIDEO_PATH="godot_source/addons/feagi_shared_video/target/${TARGET_TRIPLE}/release/feagi_shared_video.dll"
        ;;
    *)
        check_warning "Unknown platform: $PLATFORM (skipping path validation)"
        PLATFORM_NAME="unknown"
        ;;
esac

if [ "$PLATFORM_NAME" != "unknown" ]; then
    echo "   Platform: $PLATFORM_NAME"
    echo "   Expected paths after build.py --release:"
    
    # Check if build.py has the correct copy logic
    if [ "$PLATFORM_NAME" = "linux" ]; then
        if grep -q "x86_64-unknown-linux-gnu" rust_extensions/build.py 2>/dev/null; then
            check_success "build.py has Linux path logic"
        else
            check_error "build.py missing Linux path logic (x86_64-unknown-linux-gnu)"
        fi
    else
        check_success "build.py Linux path check skipped (not Linux platform)"
    fi
    
    if [ "$PLATFORM_NAME" = "windows" ]; then
        if grep -q "x86_64-pc-windows-msvc" rust_extensions/build.py 2>/dev/null; then
            check_success "build.py has Windows path logic"
        else
            check_error "build.py missing Windows path logic (x86_64-pc-windows-msvc)"
        fi
    else
        check_success "build.py Windows path check skipped (not Windows platform)"
    fi
    
    if [ "$PLATFORM_NAME" = "macos" ]; then
        if grep -q "addon2_path / lib1_name\|addon2_path / lib3_name" rust_extensions/build.py 2>/dev/null; then
            check_success "build.py has macOS direct copy logic"
        else
            check_error "build.py missing macOS direct copy logic"
        fi
    else
        check_success "build.py macOS path check skipped (not macOS platform)"
    fi
fi

# 3. Validate .gdextension file paths
echo ""
echo "3. Validating .gdextension file paths..."

check_gdextension_path() {
    local gdext_file="$1"
    local expected_pattern="$2"
    local description="$3"
    
    if [ ! -f "$gdext_file" ]; then
        check_error "$description: .gdextension file not found: $gdext_file"
        return
    fi
    
    if grep -Eq "$expected_pattern" "$gdext_file"; then
        check_success "$description: .gdextension has correct path pattern"
    else
        check_error "$description: .gdextension missing expected path pattern: $expected_pattern"
    fi
}

# feagi_data_deserializer: Linux expects x86_64-unknown-linux-gnu, macOS expects direct
check_gdextension_path \
    "godot_source/addons/FeagiCoreIntegration/feagi_data_deserializer.gdextension" \
    "x86_64-unknown-linux-gnu" \
    "feagi_data_deserializer (Linux path)"

check_gdextension_path \
    "godot_source/addons/FeagiCoreIntegration/feagi_data_deserializer.gdextension" \
    "libfeagi_data_deserializer.dylib" \
    "feagi_data_deserializer (macOS path)"

# feagi_type_system: All platforms expect direct (no target subdirectory)
check_gdextension_path \
    "godot_source/addons/FeagiCoreIntegration/feagi_type_system.gdextension" \
    "libfeagi_type_system" \
    "feagi_type_system (all platforms)"

# feagi_shared_video: Linux/Windows use target triples, macOS uses target/release
check_gdextension_path \
    "godot_source/addons/feagi_shared_video/feagi_shared_video.gdextension" \
    "target/release|target/x86_64-unknown-linux-gnu/release|target/x86_64-pc-windows-msvc/release" \
    "feagi_shared_video (cross-platform paths)"

# 4. Check if build.py builds feagi_type_system
echo ""
echo "4. Validating all required extensions are built..."

if grep -q "feagi_type_system" rust_extensions/build.py 2>/dev/null; then
    check_success "build.py includes feagi_type_system"
else
    check_error "build.py missing feagi_type_system build"
fi

if grep -q "feagi_data_deserializer" rust_extensions/build.py 2>/dev/null; then
    check_success "build.py includes feagi_data_deserializer"
else
    check_error "build.py missing feagi_data_deserializer build"
fi

if grep -q "feagi_shared_video" rust_extensions/build.py 2>/dev/null; then
    check_success "build.py includes feagi_shared_video"
else
    check_error "build.py missing feagi_shared_video build"
fi

# 5. Check version consistency
echo ""
echo "5. Validating version consistency..."

VERSION_FILES=(
    "feagi-bv/pyproject.toml"
    "feagi-bv-platform/feagi-bv-meta/pyproject.toml"
    "feagi-bv-platform/feagi-bv-linux/pyproject.toml"
    "feagi-bv-platform/feagi-bv-macos/pyproject.toml"
    "feagi-bv-platform/feagi-bv-windows/pyproject.toml"
    "rust_extensions/feagi_embedded/Cargo.toml"
)

VERSIONS=()
for file in "${VERSION_FILES[@]}"; do
    if [ -f "$file" ]; then
        if [[ "$file" == *.toml ]]; then
            # Extract version value (handles both [project] and [package] sections)
            # Pattern: version = "2.1.1"
            # Use awk for better cross-platform compatibility
            VERSION=$(grep -E '^\s*version\s*=' "$file" | head -1 | awk -F'"' '{print $2}')
            # Fallback if awk didn't work
            if [ -z "$VERSION" ] || [ "$VERSION" = "version" ]; then
                VERSION=$(grep -E '^\s*version\s*=' "$file" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
            fi
        fi
        if [ -n "$VERSION" ] && [ "$VERSION" != "version" ] && [[ "$VERSION" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
            VERSIONS+=("$VERSION")
            check_success "$file: version = $VERSION"
        else
            check_warning "$file: Could not extract version"
        fi
    else
        check_warning "$file: File not found"
    fi
done

# Check if all versions match
UNIQUE_VERSIONS=($(printf '%s\n' "${VERSIONS[@]}" | sort -u))
if [ ${#UNIQUE_VERSIONS[@]} -eq 1 ]; then
    check_success "All versions match: ${UNIQUE_VERSIONS[0]}"
elif [ ${#UNIQUE_VERSIONS[@]} -gt 1 ]; then
    check_error "Version mismatch! Found: ${UNIQUE_VERSIONS[*]}"
fi

# 6. Check workflow caching
echo ""
echo "6. Validating workflow caching..."

if grep -q "Cache Rust dependencies" .github/workflows/release.yml 2>/dev/null; then
    check_success "Workflow has Rust caching"
else
    check_error "Workflow missing Rust caching"
fi

# Count how many "Cache Rust dependencies" entries exist (should be 2: one for build-bv-remote, one for build-rust-binaries)
CACHE_COUNT=$(grep -c "Cache Rust dependencies" .github/workflows/release.yml 2>/dev/null || echo "0")
if [ "$CACHE_COUNT" -ge 2 ]; then
    check_success "build-rust-binaries job has caching (found $CACHE_COUNT cache entries)"
elif [ "$CACHE_COUNT" -eq 1 ]; then
    check_error "build-rust-binaries job missing caching (only found 1 cache entry)"
else
    check_error "No Rust caching found in workflow"
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Validations passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    exit 1
fi
