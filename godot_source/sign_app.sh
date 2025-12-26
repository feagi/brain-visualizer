#!/bin/bash
set -euo pipefail

# ===================================================================
# Brain Visualizer - App Code Signing Script
# ===================================================================
# This script signs an existing Brain Visualizer app bundle
# Usage: ./sign_app.sh [path/to/Brain Visualizer.app]
# ===================================================================

# Configuration
DEFAULT_APP="./Brain Visualizer.app"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

sign_app_bundle() {
    local app_file="$1"
    
    if [[ ! -d "$app_file" ]]; then
        print_error "App bundle not found: $app_file"
        return 1
    fi
    
    print_info "Signing app bundle: $app_file"
    
    # Sign all dylibs in Frameworks first (must be signed before the main executable)
    if [[ -d "$app_file/Contents/Frameworks" ]]; then
        print_info "Signing dynamic libraries..."
        local signed_count=0
        local failed_count=0
        
        find "$app_file/Contents/Frameworks" -name "*.dylib" -type f | while read -r dylib; do
            if codesign --force --deep --sign - "$dylib" 2>/dev/null; then
                print_success "Signed: $(basename "$dylib")"
                ((signed_count++)) || true
            else
                print_warning "Failed to sign: $(basename "$dylib")"
                ((failed_count++)) || true
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
    
    # Sign any binaries in Resources/bin
    if [[ -d "$app_file/Contents/Resources/bin" ]]; then
        print_info "Signing bundled binaries..."
        find "$app_file/Contents/Resources/bin" -type f -perm +111 | while read -r bin; do
            if codesign --force --deep --sign - "$bin" 2>/dev/null; then
                print_success "Signed: $(basename "$bin")"
            else
                print_warning "Failed to sign: $(basename "$bin")"
            fi
        done
    fi
    
    # Sign the entire app bundle
    print_info "Signing app bundle..."
    if codesign --force --deep --sign - "$app_file" 2>&1; then
        print_success "App bundle signed successfully"
        
        # Verify the signature
        print_info "Verifying code signature..."
        if codesign --verify --verbose "$app_file" 2>&1 | grep -q "valid on disk"; then
            print_success "Code signature verified - app should launch successfully"
            
            # Show signature details
            print_info "Signature details:"
            codesign -dv "$app_file" 2>&1 | grep -E "(Authority|Identifier|Format)" || true
            
            return 0
        else
            print_warning "Code signature verification failed"
            codesign --verify --verbose "$app_file" 2>&1 || true
            return 1
        fi
    else
        print_error "Failed to sign app bundle"
        print_error "App will crash on launch with 'Code Signature Invalid' error"
        print_info "Ensure Xcode Command Line Tools are installed:"
        print_info "  xcode-select --install"
        return 1
    fi
}

main() {
    print_header "Brain Visualizer - Code Signing"
    
    # Get app path from argument or use default
    local app_file="${1:-$DEFAULT_APP}"
    
    # Resolve to absolute path
    if [[ ! "$app_file" =~ ^/ ]]; then
        app_file="$(cd "$(dirname "$app_file")" && pwd)/$(basename "$app_file")"
    fi
    
    # Check if codesign is available
    if ! command -v codesign &> /dev/null; then
        print_error "codesign command not found"
        print_error "Please install Xcode Command Line Tools:"
        print_error "  xcode-select --install"
        exit 1
    fi
    
    # Sign the app
    if sign_app_bundle "$app_file"; then
        print_header "Signing Complete"
        print_success "App is now signed and ready to launch"
        return 0
    else
        print_error "Signing failed"
        exit 1
    fi
}

# Run main function
main "$@"


















