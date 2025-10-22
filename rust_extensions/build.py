#!/usr/bin/env python3
"""
Cross-platform build script for FEAGI Rust extensions.

Builds Rust libraries and copies them to the Godot project.
Supports: macOS (arm64/x86_64/universal), Linux, Windows
"""

import subprocess
import sys
import shutil
import platform
from pathlib import Path


def get_library_extension():
    """Get the shared library extension for the current platform."""
    system = platform.system()
    if system == "Windows":
        return "dll"
    elif system == "Darwin":
        return "dylib"
    else:  # Linux and others
        return "so"


def get_library_prefix():
    """Get the library prefix for the current platform."""
    return "" if platform.system() == "Windows" else "lib"


def run_command(cmd, cwd=None):
    """Run a shell command and check for errors."""
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[ERROR] Command failed: {' '.join(cmd)}")
        print(f"stderr: {result.stderr}")
        sys.exit(1)
    return result


def print_section(message):
    """Print a formatted section header."""
    print(f"\n{'='*60}")
    print(f"  {message}")
    print(f"{'='*60}\n")


def build_rust_library(project_name, project_dir, godot_addon_dir):
    """Build a Rust library in both debug and release modes."""
    print_section(f"Building {project_name}")
    
    lib_ext = get_library_extension()
    lib_prefix = get_library_prefix()
    lib_name = f"{lib_prefix}{project_name}.{lib_ext}"
    
    project_path = Path(project_dir)
    if not project_path.exists():
        print(f"[ERROR] Project directory not found: {project_path}")
        sys.exit(1)
    
    # Clean previous builds
    print("[CLEAN] Cleaning previous builds...")
    run_command(["cargo", "clean"], cwd=project_path)
    
    # Build release
    print("[BUILD] Building Rust library (release mode)...")
    run_command(["cargo", "build", "--release"], cwd=project_path)
    
    # Build debug
    print("[BUILD] Building Rust library (debug mode)...")
    run_command(["cargo", "build"], cwd=project_path)
    
    # Check if builds were successful
    release_lib = project_path / "target" / "release" / lib_name
    debug_lib = project_path / "target" / "debug" / lib_name
    
    if not release_lib.exists():
        print(f"[ERROR] Build failed - release library not found: {release_lib}")
        sys.exit(1)
    
    if not debug_lib.exists():
        print(f"[ERROR] Build failed - debug library not found: {debug_lib}")
        sys.exit(1)
    
    print("[SUCCESS] Build successful!")
    
    # Copy files to Godot project
    print("[COPY] Copying files to Godot project...")
    addon_path = Path(godot_addon_dir)
    addon_path.mkdir(parents=True, exist_ok=True)
    
    # Create target directory structure
    (addon_path / "target" / "release").mkdir(parents=True, exist_ok=True)
    (addon_path / "target" / "debug").mkdir(parents=True, exist_ok=True)
    
    # Copy libraries
    shutil.copy2(release_lib, addon_path / "target" / "release" / lib_name)
    shutil.copy2(debug_lib, addon_path / "target" / "debug" / lib_name)
    
    # Remove any old library files in the wrong location
    old_lib = addon_path / lib_name
    if old_lib.exists():
        old_lib.unlink()
    
    print("[SUCCESS] Files copied successfully!")
    
    # Display file sizes
    release_size = (addon_path / "target" / "release" / lib_name).stat().st_size
    print(f"[INFO] Release library size: {release_size / (1024*1024):.2f} MB")
    
    return project_path, addon_path, lib_name


def build_universal_macos(project_path, addon_path, lib_name):
    """Build universal (arm64+x86_64) binaries for macOS."""
    print_section("Building macOS Universal Binaries")
    
    project_name = project_path.name
    
    # Add targets (silently)
    subprocess.run(
        ["rustup", "target", "add", "aarch64-apple-darwin"],
        capture_output=True
    )
    subprocess.run(
        ["rustup", "target", "add", "x86_64-apple-darwin"],
        capture_output=True
    )
    
    # Build release for both architectures
    print("[BUILD] Building arm64 (release)...")
    run_command(
        ["cargo", "build", "--release", "--target", "aarch64-apple-darwin"],
        cwd=project_path
    )
    
    print("[BUILD] Building x86_64 (release)...")
    run_command(
        ["cargo", "build", "--release", "--target", "x86_64-apple-darwin"],
        cwd=project_path
    )
    
    # Create universal binary (release)
    universal_release = project_path / "target" / "universal_release.dylib"
    run_command([
        "lipo", "-create", "-output", str(universal_release),
        str(project_path / "target" / "aarch64-apple-darwin" / "release" / lib_name),
        str(project_path / "target" / "x86_64-apple-darwin" / "release" / lib_name)
    ])
    shutil.copy2(universal_release, addon_path / "target" / "release" / lib_name)
    
    # Build debug for both architectures
    print("[BUILD] Building arm64 (debug)...")
    run_command(
        ["cargo", "build", "--target", "aarch64-apple-darwin"],
        cwd=project_path
    )
    
    print("[BUILD] Building x86_64 (debug)...")
    run_command(
        ["cargo", "build", "--target", "x86_64-apple-darwin"],
        cwd=project_path
    )
    
    # Create universal binary (debug)
    universal_debug = project_path / "target" / "universal_debug.dylib"
    run_command([
        "lipo", "-create", "-output", str(universal_debug),
        str(project_path / "target" / "aarch64-apple-darwin" / "debug" / lib_name),
        str(project_path / "target" / "x86_64-apple-darwin" / "debug" / lib_name)
    ])
    shutil.copy2(universal_debug, addon_path / "target" / "debug" / lib_name)
    
    print("[SUCCESS] Universal binaries installed.")


def main():
    """Main build process."""
    print_section("FEAGI Rust Extensions Build")
    print(f"Platform: {platform.system()} ({platform.machine()})")
    
    # Get root directory
    root_dir = Path(__file__).parent
    godot_source = root_dir.parent / "godot_source"
    
    # Build feagi_data_deserializer
    project1_path, addon1_path, lib1_name = build_rust_library(
        "feagi_data_deserializer",
        root_dir / "feagi_data_deserializer",
        godot_source / "addons" / "feagi_rust_deserializer"
    )
    
    # Build universal binaries on macOS
    if platform.system() == "Darwin":
        build_universal_macos(project1_path, addon1_path, lib1_name)
    
    # Build feagi_shared_video
    project2_path, addon2_path, lib2_name = build_rust_library(
        "feagi_shared_video",
        root_dir / "feagi_shared_video",
        godot_source / "addons" / "feagi_shared_video"
    )
    
    # Build universal binaries on macOS
    if platform.system() == "Darwin":
        build_universal_macos(project2_path, addon2_path, lib2_name)
    
    # Final success message
    print_section("Build Complete!")
    print("[SUCCESS] All Rust extensions built successfully!")
    print("[TIP] Restart Godot to load the new extensions.")
    print("[TEST] To test the integration, run the test_rust_deserializer.tscn scene in Godot.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[ERROR] Build interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n[ERROR] Build failed with error: {e}")
        sys.exit(1)

