#!/bin/bash
set -euo pipefail

# ===================================================================
# Brain Visualizer - macOS Export Script
# ===================================================================
# This script automates the export of the Godot project to macOS
# Usage: ./export_macos.sh [godot_executable]
# ===================================================================

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_PRESET_NAME="macOS"
OUTPUT_FILE="$PROJECT_DIR/Brain Visualizer.dmg"

# Godot executable (can be overridden by argument or environment variable)
GODOT_BIN="${1:-${GODOT_BIN:-}}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===================================================================
# Functions
# ===================================================================

print_header() {
    echo "" >&2
    echo -e "${BLUE}========================================${NC}" >&2
    echo -e "${BLUE}$1${NC}" >&2
    echo -e "${BLUE}========================================${NC}" >&2
    echo "" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

find_godot_executable() {
    print_info "Looking for Godot executable..."
    
    # Common locations for Godot 4.5 on macOS
    # No fallbacks - project requires specific version
    local godot_locations=(
        "/Applications/Godot45.app/Contents/MacOS/Godot"
        "$HOME/Applications/Godot45.app/Contents/MacOS/Godot"
    )
    
    for location in "${godot_locations[@]}"; do
        if [[ -n "$location" && -x "$location" ]]; then
            echo "$location"
            return 0
        fi
    done
    
    return 1
}

verify_godot_version() {
    local godot_bin="$1"
    print_info "Verifying Godot version..."
    
    local version_output
    version_output=$("$godot_bin" --headless --version 2>&1 | head -1 | tr -d '\r\n')
    
    # Check if it's Godot 4.5 (strict version requirement)
    if echo "$version_output" | grep -q "4\.5"; then
        print_success "Found Godot 4.5: $version_output"
        return 0
    else
        print_error "This project requires Godot 4.5 (found: $version_output)"
        return 1
    fi
}

clean_previous_exports() {
    print_info "Cleaning previous exports..."
    
    # Remove DMG files (both old and new names)
    if [[ -f "$OUTPUT_FILE" ]]; then
        rm -f "$OUTPUT_FILE"
        print_success "Removed old DMG: $OUTPUT_FILE"
    fi
    rm -f "$PROJECT_DIR/Brain-Visualizer.dmg" 2>/dev/null || true
    
    # Remove .app files (both old and new names)
    local app_file="${OUTPUT_FILE%.dmg}.app"
    if [[ -d "$app_file" ]]; then
        rm -rf "$app_file"
        print_success "Removed old .app: $app_file"
    fi
    rm -rf "$PROJECT_DIR/Brain-Visualizer.app" 2>/dev/null || true
    
    # Remove staging directory
    rm -rf "$PROJECT_DIR/.dmg_staging" 2>/dev/null || true
}

verify_export_templates() {
    local godot_bin="$1"
    print_info "Checking for export templates..."
    
    # Godot export templates are usually in ~/.local/share/godot/export_templates/
    local templates_dir="$HOME/Library/Application Support/Godot/export_templates"
    
    if [[ ! -d "$templates_dir" ]]; then
        print_warning "Export templates directory not found at: $templates_dir"
        print_warning "You may need to download export templates from Godot Editor:"
        print_warning "  Editor → Manage Export Templates → Download and Install"
        return 1
    fi
    
    print_success "Export templates directory found"
    return 0
}

sign_app_bundle() {
    local app_file="$1"
    
    if [[ ! -d "$app_file" ]]; then
        print_error "App bundle not found: $app_file"
        return 1
    fi
    
    print_info "Signing app bundle with ad-hoc signature..."
    
    # Sign all dylibs in Frameworks first (must be signed before the main executable)
    if [[ -d "$app_file/Contents/Frameworks" ]]; then
        print_info "Signing dynamic libraries..."
        find "$app_file/Contents/Frameworks" -name "*.dylib" -type f | while read -r dylib; do
            if codesign --force --deep --sign - "$dylib" 2>/dev/null; then
                print_success "Signed: $(basename "$dylib")"
            else
                print_warning "Failed to sign: $(basename "$dylib")"
            fi
        done
    fi
    
    # Sign all executables in MacOS
    if [[ -d "$app_file/Contents/MacOS" ]]; then
        print_info "Signing executables..."
        find "$app_file/Contents/MacOS" -type f -perm +111 | while read -r exe; do
            if codesign --force --deep --sign - "$exe" 2>/dev/null; then
                print_success "Signed: $(basename "$exe")"
            else
                print_warning "Failed to sign: $(basename "$exe")"
            fi
        done
    fi
    
    # Sign the entire app bundle
    print_info "Signing app bundle..."
    if codesign --force --deep --sign - "$app_file" 2>&1; then
        print_success "App bundle signed successfully"
        
        # Verify the signature
        if codesign --verify --verbose "$app_file" 2>&1 | grep -q "valid on disk"; then
            print_success "Code signature verified"
            return 0
        else
            print_warning "Code signature verification failed, but continuing..."
            return 0
        fi
    else
        print_error "Failed to sign app bundle"
        print_warning "App may crash on launch due to invalid code signature"
        return 1
    fi
}

run_export() {
    local godot_bin="$1"
    local app_file="${OUTPUT_FILE%.dmg}.app"
    
    print_info "Starting export..."
    print_info "Project: $PROJECT_DIR"
    print_info "Preset: $EXPORT_PRESET_NAME"
    print_info "Output: $app_file"
    
    # Run Godot export in headless mode
    # --headless: Run without window (for CI/CD)
    # --export-release: Export using release preset
    cd "$PROJECT_DIR"
    
    if "$godot_bin" --headless --export-release "$EXPORT_PRESET_NAME" "$app_file" 2>&1 | tee export.log; then
        print_success "Export command completed"
        
        # Bundle FEAGI binary and config for subprocess mode
        print_info "Bundling FEAGI binary and configuration..."
        local feagi_bin_src="$PROJECT_DIR/../../feagi/target/release/feagi"
        local feagi_cfg_src="$PROJECT_DIR/../../feagi/feagi_configuration.toml"
        local feagi_wrapper_src="$PROJECT_DIR/launch_feagi_wrapper.sh"
        local feagi_bin_dest="$app_file/Contents/Resources/bin"
        local feagi_cfg_dest="$app_file/Contents/Resources"
        local feagi_wrapper_dest="$app_file/Contents/MacOS"
        
        if [[ -f "$feagi_bin_src" ]]; then
            mkdir -p "$feagi_bin_dest"
            cp "$feagi_bin_src" "$feagi_bin_dest/"
            chmod +x "$feagi_bin_dest/feagi"
            print_success "FEAGI binary bundled successfully"
            
            # Bundle wrapper script for debugging
            if [[ -f "$feagi_wrapper_src" ]]; then
                cp "$feagi_wrapper_src" "$feagi_wrapper_dest/"
                chmod +x "$feagi_wrapper_dest/launch_feagi_wrapper.sh"
                print_success "FEAGI wrapper script bundled"
            fi
        else
            print_warning "FEAGI binary not found at: $feagi_bin_src"
            print_warning "Exported app will use embedded FEAGI extension (has threading issues)"
            print_warning "To fix: cd ../../feagi && cargo build --release"
        fi
        
        if [[ -f "$feagi_cfg_src" ]]; then
            # Patch config for App Store compatibility (no relative paths)
            cp "$feagi_cfg_src" "$feagi_cfg_dest/feagi_configuration.toml"
            
            # Disable file logging (use stdout/stderr only for sandboxed apps)
            sed -i '' 's|log_file = "feagi.log"|log_file = ""|' "$feagi_cfg_dest/feagi_configuration.toml"
            
            # Disable snapshot output for App Store (requires write access)
            sed -i '' 's|output_dir = "output/snapshots"|output_dir = ""|' "$feagi_cfg_dest/feagi_configuration.toml"
            sed -i '' 's|temp_dir = "output/snapshots/tmp"|temp_dir = ""|' "$feagi_cfg_dest/feagi_configuration.toml"
            
            print_success "FEAGI configuration bundled and patched for App Store"
        else
            print_warning "FEAGI config not found at: $feagi_cfg_src"
            print_warning "FEAGI subprocess may fail to start without configuration"
        fi
        
        # Bundle genomes folder
        print_info "Bundling genomes..."
        local genomes_src="$PROJECT_DIR/Resources/genomes"
        local genomes_dest="$app_file/Contents/Resources/genomes"
        
        if [[ -d "$genomes_src" ]]; then
            mkdir -p "$genomes_dest"
            cp -R "$genomes_src"/* "$genomes_dest/"
            print_success "Genomes bundled successfully"
        else
            print_warning "Genomes folder not found at: $genomes_src"
            print_warning "FEAGI will start without a default genome"
        fi
        
        # Sign the app bundle (required for macOS to allow execution)
        print_header "Code Signing"
        if ! sign_app_bundle "$app_file"; then
            print_warning "Code signing failed - app may crash on launch"
            print_warning "To fix: Ensure you have Xcode Command Line Tools installed"
        fi
        
        return 0
    else
        print_error "Export command failed"
        print_error "Check export.log for details"
        return 1
    fi
}

create_dmg() {
    print_info "Creating installer DMG with drag-and-drop interface..."
    
    local app_file="${OUTPUT_FILE%.dmg}.app"
    
    if [[ ! -d "$app_file" ]]; then
        print_error ".app file not found: $app_file"
        return 1
    fi
    
    # Remove old DMG if it exists
    if [[ -f "$OUTPUT_FILE" ]]; then
        rm -f "$OUTPUT_FILE"
    fi
    
    # Create temporary staging directory
    local staging_dir="$PROJECT_DIR/.dmg_staging"
    rm -rf "$staging_dir"
    mkdir -p "$staging_dir"
    
    # Copy .app to staging directory
    print_info "Copying app to staging directory..."
    cp -R "$app_file" "$staging_dir/"
    
    # Create symbolic link to Applications folder
    print_info "Creating Applications folder link..."
    ln -s /Applications "$staging_dir/Applications"
    
    # Verify symlink was created
    if [[ ! -L "$staging_dir/Applications" ]]; then
        print_error "Failed to create Applications symlink"
        rm -rf "$staging_dir"
        return 1
    fi
    
    # Create compressed DMG directly (using -format UDZO and -srcfolder includes symlinks)
    print_info "Creating compressed DMG with drag-to-install interface..."
    rm -f "$OUTPUT_FILE"
    
    # Use UDZO format which should preserve symlinks
    if ! hdiutil create -volname "Brain Visualizer" \
        -srcfolder "$staging_dir" \
        -ov -format UDZO \
        -fs HFS+ \
        "$OUTPUT_FILE" 2>&1 | grep -v "hdiutil: create"; then
        print_error "Failed to create DMG"
        print_info "Staging contents:"
        ls -la "$staging_dir" || true
        rm -rf "$staging_dir"
        return 1
    fi
    
    # Clean up
    print_info "Cleaning up temporary files..."
    rm -rf "$staging_dir"
    rm -rf "$app_file"
    
    print_success "Installer DMG created successfully"
    return 0
}

verify_export() {
    print_info "Verifying export..."
    
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        print_error "Export DMG not found: $OUTPUT_FILE"
        return 1
    fi
    
    local file_size
    file_size=$(du -h "$OUTPUT_FILE" | awk '{print $1}')
    print_success "Export DMG created: $OUTPUT_FILE ($file_size)"
    
    # Verify DMG contents
    print_info "Verifying DMG contents..."
    local mount_point="/tmp/bv-verify-$$"
    
    if hdiutil attach "$OUTPUT_FILE" -mountpoint "$mount_point" -quiet 2>/dev/null; then
        if [[ -d "$mount_point/Brain Visualizer.app" ]]; then
            print_success "Found Brain Visualizer.app in DMG"
            
            # Check for essential files
            if [[ -f "$mount_point/Brain Visualizer.app/Contents/MacOS/Brain Visualizer" ]]; then
                print_success "Found executable"
            else
                print_error "Executable not found"
                hdiutil detach "$mount_point" -quiet 2>/dev/null || true
                return 1
            fi
            
            if [[ -f "$mount_point/Brain Visualizer.app/Contents/Resources/Brain Visualizer.pck" ]]; then
                print_success "Found .pck file"
            else
                print_warning ".pck file not found"
            fi
            
            if [[ -d "$mount_point/Brain Visualizer.app/Contents/Frameworks" ]]; then
                local lib_count
                lib_count=$(find "$mount_point/Brain Visualizer.app/Contents/Frameworks" -name "*.dylib" 2>/dev/null | wc -l | tr -d ' ')
                print_success "Found $lib_count Rust libraries"
            else
                print_warning "No Frameworks directory found"
            fi
        else
            print_error "Brain Visualizer.app not found in DMG"
            hdiutil detach "$mount_point" -quiet 2>/dev/null || true
            return 1
        fi
        
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    else
        print_warning "Could not mount DMG for verification"
    fi
    
    return 0
}

# ===================================================================
# Main Script
# ===================================================================

main() {
    print_header "Brain Visualizer - macOS Export"
    
    # Step 1: Find Godot executable
    if [[ -z "$GODOT_BIN" ]]; then
        if ! GODOT_BIN=$(find_godot_executable); then
            print_error "Godot executable not found"
            echo ""
            echo "Please specify the Godot executable:"
            echo "  ./export_macos.sh /path/to/Godot.app/Contents/MacOS/Godot"
            echo "  or"
            echo "  export GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot"
            exit 1
        fi
    fi
    
    print_success "Using Godot: $GODOT_BIN"
    
    # Step 2: Verify Godot version
    if ! verify_godot_version "$GODOT_BIN"; then
        exit 1
    fi
    
    # Step 3: Check export templates
    if ! verify_export_templates "$GODOT_BIN"; then
        print_warning "Continuing anyway, but export may fail..."
    fi
    
    # Step 4: Build FEAGI binary
    print_header "Building FEAGI Binary"
    print_info "Building FEAGI for subprocess mode..."
    local feagi_dir="$PROJECT_DIR/../../feagi"
    if [[ -d "$feagi_dir" ]]; then
        cd "$feagi_dir"
        if cargo build --release 2>&1 | tail -20; then
            print_success "FEAGI binary built successfully"
        else
            print_error "FEAGI binary build failed"
            print_warning "Export will continue but app may use embedded FEAGI (has threading issues)"
        fi
        cd "$PROJECT_DIR"
    else
        print_warning "FEAGI source directory not found at: $feagi_dir"
        print_warning "Export will continue but app may use embedded FEAGI (has threading issues)"
    fi
    
    # Step 5: Clean previous exports
    clean_previous_exports
    
    # Step 6: Run export
    print_header "Exporting Project"
    if ! run_export "$GODOT_BIN"; then
        print_error "Export failed"
        exit 1
    fi
    
    # Step 7: Create DMG
    print_header "Creating DMG"
    if ! create_dmg; then
        print_error "DMG creation failed"
        exit 1
    fi
    
    # Step 8: Verify export
    print_header "Verification"
    if ! verify_export; then
        print_error "Export verification failed"
        exit 1
    fi
    
    # Success!
    print_header "Export Complete"
    print_success "Successfully created installer DMG: $OUTPUT_FILE"
    echo "" >&2
    print_info "To install:"
    echo "  1. Open: $OUTPUT_FILE" >&2
    echo "  2. Drag 'Brain Visualizer.app' to the 'Applications' folder" >&2
    echo "  3. Launch from Applications or Spotlight" >&2
    echo "" >&2
    print_info "To test directly from DMG:"
    echo "  open '$OUTPUT_FILE'" >&2
    echo "" >&2
    
    return 0
}

# Run main function
main "$@"

