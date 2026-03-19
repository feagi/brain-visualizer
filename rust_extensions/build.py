#!/usr/bin/env python3
"""
Cross-platform build script for FEAGI Rust extensions.

Builds Rust libraries and copies them to the Godot project.
Supports: macOS (arm64/x86_64/universal), Linux, Windows

Usage:
    python build.py                  # Build both debug and release (for developers)
    python build.py --release        # Build release only (for CI/CD)
    python build.py --dev            # Build debug only (fast local iteration)
    python build.py --local-arch     # Build for local architecture only (faster)
    python build.py --release --local-arch  # Combine options
    python build.py --extension feagi_data_deserializer  # Build one extension only
"""

import subprocess
import sys
import shutil
import platform
from pathlib import Path

SUPPORTED_EXTENSIONS = {
    "feagi_data_deserializer",
    "feagi_agent_client",
    "feagi_type_system",
}


def parse_selected_extensions(argv):
    """Parse repeatable '--extension <name>' arguments."""
    selected = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--extension":
            if i + 1 >= len(argv):
                print("[ERROR] --extension requires a value")
                sys.exit(1)
            selected.append(argv[i + 1].strip())
            i += 2
            continue
        i += 1
    if not selected:
        return set()
    invalid = [name for name in selected if name not in SUPPORTED_EXTENSIONS]
    if invalid:
        print(f"[ERROR] Unsupported extension name(s): {', '.join(invalid)}")
        print(f"[INFO] Supported values: {', '.join(sorted(SUPPORTED_EXTENSIONS))}")
        sys.exit(1)
    return set(selected)


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


def build_rust_library(
    project_name,
    project_dir,
    godot_addon_dir,
    build_release=True,
    build_debug=True,
    no_clean=False,
):
    """Build a Rust library in one or both modes and deploy to addon paths.
    
    Args:
        project_name: Name of the Rust project
        project_dir: Path to the Rust project directory
        godot_addon_dir: Path to the Godot addon directory
        build_release: If True, build and deploy release artifacts.
        build_debug: If True, build and deploy debug artifacts.
        no_clean: If True, skip cargo clean (useful for CI caching). If False, clean before building.
    """
    print_section(f"Building {project_name}")
    
    lib_ext = get_library_extension()
    lib_prefix = get_library_prefix()
    lib_name = f"{lib_prefix}{project_name}.{lib_ext}"
    
    project_path = Path(project_dir)
    if not project_path.exists():
        print(f"[ERROR] Project directory not found: {project_path}")
        sys.exit(1)
    
    # Clean previous builds (unless --no-clean is specified)
    if not no_clean:
        print("[CLEAN] Cleaning previous builds...")
        run_command(["cargo", "clean"], cwd=project_path)
    else:
        print("[INFO] Skipping cargo clean (using cache)")
    
    release_lib = None
    debug_lib = None
    if build_release:
        print("[BUILD] Building Rust library (release mode - optimized)...")
        run_command(["cargo", "build", "--release", "--locked"], cwd=project_path)
        release_lib = project_path / "target" / "release" / lib_name
        if not release_lib.exists():
            print(f"[ERROR] Build failed - release library not found: {release_lib}")
            sys.exit(1)
    
    if build_debug:
        print("[BUILD] Building Rust library (debug mode - for development)...")
        run_command(["cargo", "build", "--locked"], cwd=project_path)
        debug_lib = project_path / "target" / "debug" / lib_name
        if not debug_lib.exists():
            print(f"[ERROR] Build failed - debug library not found: {debug_lib}")
            sys.exit(1)
    if not build_release and not build_debug:
        print("[ERROR] Invalid build mode: at least one of release/debug must be enabled")
        sys.exit(1)
    
    print("[SUCCESS] Build successful!")
    
    # Copy files to Godot project
    print("[COPY] Copying files to Godot project...")
    addon_path = Path(godot_addon_dir)
    addon_path.mkdir(parents=True, exist_ok=True)
    
    # Determine target triple and copy paths based on platform
    system = platform.system()
    
    if system == "Linux":
        # Linux: copy to target/x86_64-unknown-linux-gnu/release/
        target_triple = "x86_64-unknown-linux-gnu"
        if build_release and release_lib:
            release_dest = addon_path / "target" / target_triple / "release"
            release_dest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(release_lib, release_dest / lib_name)
        if build_debug and debug_lib:
            debug_dest = addon_path / "target" / target_triple / "debug"
            debug_dest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(debug_lib, debug_dest / lib_name)
    elif system == "Darwin":
        # macOS: copy directly to addon directory (for .gdextension compatibility)
        # Also copy to target/release/ for legacy compatibility
        if build_release and release_lib:
            shutil.copy2(release_lib, addon_path / lib_name)
            (addon_path / "target" / "release").mkdir(parents=True, exist_ok=True)
            shutil.copy2(release_lib, addon_path / "target" / "release" / lib_name)
        if build_debug and debug_lib:
            if not build_release:
                # Dev/debug-only mode: ensure debug manifest paths resolve directly.
                shutil.copy2(debug_lib, addon_path / lib_name)
            else:
                shutil.copy2(debug_lib, addon_path / lib_name.replace(".dylib", "_debug.dylib"))
            (addon_path / "target" / "debug").mkdir(parents=True, exist_ok=True)
            shutil.copy2(debug_lib, addon_path / "target" / "debug" / lib_name)
    elif system == "Windows":
        # Windows: copy to target/x86_64-pc-windows-msvc/release/
        target_triple = "x86_64-pc-windows-msvc"
        if build_release and release_lib:
            release_dest = addon_path / "target" / target_triple / "release"
            release_dest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(release_lib, release_dest / lib_name)
        if build_debug and debug_lib:
            debug_dest = addon_path / "target" / target_triple / "debug"
            debug_dest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(debug_lib, debug_dest / lib_name)
    else:
        # Fallback: copy to target/release/
        if build_release and release_lib:
            (addon_path / "target" / "release").mkdir(parents=True, exist_ok=True)
            shutil.copy2(release_lib, addon_path / "target" / "release" / lib_name)
        if build_debug and debug_lib:
            (addon_path / "target" / "debug").mkdir(parents=True, exist_ok=True)
            shutil.copy2(debug_lib, addon_path / "target" / "debug" / lib_name)
    
    print("[SUCCESS] Files copied successfully!")
    
    # Display file sizes
    if build_release:
        if system == "Darwin":
            release_size = (addon_path / lib_name).stat().st_size
        elif system == "Linux":
            release_size = (addon_path / "target" / "x86_64-unknown-linux-gnu" / "release" / lib_name).stat().st_size
        elif system == "Windows":
            release_size = (addon_path / "target" / "x86_64-pc-windows-msvc" / "release" / lib_name).stat().st_size
        else:
            release_size = (addon_path / "target" / "release" / lib_name).stat().st_size
        print(f"[INFO] Release library size: {release_size / (1024*1024):.2f} MB")
    if build_debug and debug_lib:
        debug_size = debug_lib.stat().st_size
        print(f"[INFO] Debug library size: {debug_size / (1024*1024):.2f} MB")
    
    return project_path, addon_path, lib_name


def build_universal_macos(project_path, addon_path, lib_name, release_only=False):
    """Build universal (arm64+x86_64) binaries for macOS.
    
    Args:
        project_path: Path to the Rust project
        addon_path: Path to the Godot addon directory
        lib_name: Name of the library file
        release_only: If True, only build release mode
    """
    print_section("Building macOS Universal Binaries")
    
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
        ["cargo", "build", "--release", "--locked", "--target", "aarch64-apple-darwin"],
        cwd=project_path
    )
    
    print("[BUILD] Building x86_64 (release)...")
    run_command(
        ["cargo", "build", "--release", "--locked", "--target", "x86_64-apple-darwin"],
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
    
    # Build debug for both architectures (only if not release_only)
    if not release_only:
        print("[BUILD] Building arm64 (debug)...")
        run_command(
            ["cargo", "build", "--locked", "--target", "aarch64-apple-darwin"],
            cwd=project_path
        )
        
        print("[BUILD] Building x86_64 (debug)...")
        run_command(
            ["cargo", "build", "--locked", "--target", "x86_64-apple-darwin"],
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
        print("[SUCCESS] Universal binaries installed (release + debug).")
    else:
        print("[SUCCESS] Universal binary installed (release only).")


def main():
    """Main build process."""
    # Parse command line arguments
    release_only = "--release" in sys.argv or "--release-only" in sys.argv
    dev_mode = "--dev" in sys.argv
    local_arch_only = "--local-arch" in sys.argv or "--native" in sys.argv
    no_clean = "--no-clean" in sys.argv
    selected_extensions = parse_selected_extensions(sys.argv[1:])
    
    if release_only and dev_mode:
        print("[ERROR] --release and --dev are mutually exclusive")
        sys.exit(1)
    
    build_release = not dev_mode
    build_debug = dev_mode or not release_only
    
    print_section("FEAGI Rust Extensions Build")
    print(f"Platform: {platform.system()} ({platform.machine()})")
    if dev_mode:
        print("[MODE] Dev mode (debug only - fastest local iteration)")
    elif release_only:
        print("[MODE] Release only (CI/CD mode)")
    else:
        print("[MODE] Debug + Release (Developer mode)")
    if local_arch_only:
        print("[ARCH] Local architecture only (skipping universal binary)")
    if selected_extensions:
        print(f"[TARGET] Selected extension(s): {', '.join(sorted(selected_extensions))}")
    
    # Get root directory
    root_dir = Path(__file__).parent
    godot_source = root_dir.parent / "godot_source"
    addon2_path = godot_source / "addons" / "FeagiCoreIntegration"
    addon1_path = godot_source / "addons" / "feagi_rust_deserializer"
    system = platform.system()

    built_deserializer = False
    built_agent_client = False
    built_type_system = False

    def should_build(extension_name):
        return not selected_extensions or extension_name in selected_extensions
    
    # Build feagi_data_deserializer (deploy to BOTH addon locations for compatibility)
    if should_build("feagi_data_deserializer"):
        project1_path, addon1_path, lib1_name = build_rust_library(
            "feagi_data_deserializer",
            root_dir / "feagi_data_deserializer",
            addon1_path,
            build_release=build_release,
            build_debug=build_debug,
            no_clean=no_clean
        )
        
        # Also copy to FeagiCoreIntegration addon (legacy location - for compatibility)
        print("[COPY] Also deploying to FeagiCoreIntegration addon (legacy location)...")
        
        if system == "Linux":
            # Linux: copy to target/x86_64-unknown-linux-gnu/release/
            target_triple = "x86_64-unknown-linux-gnu"
            release_dest = addon2_path / "target" / target_triple / "release"
            release_dest.mkdir(parents=True, exist_ok=True)
            if build_release:
                shutil.copy2(project1_path / "target" / "release" / lib1_name, release_dest / lib1_name)
            if build_debug:
                debug_dest = addon2_path / "target" / target_triple / "debug"
                debug_dest.mkdir(parents=True, exist_ok=True)
                debug_lib = project1_path / "target" / "debug" / lib1_name
                if debug_lib.exists():
                    shutil.copy2(debug_lib, debug_dest / lib1_name)
        elif system == "Darwin":
            # macOS: copy directly to addon directory (as expected by .gdextension)
            if build_release:
                shutil.copy2(project1_path / "target" / "release" / lib1_name, addon2_path / lib1_name)
            elif build_debug:
                debug_lib = project1_path / "target" / "debug" / lib1_name
                if debug_lib.exists():
                    shutil.copy2(debug_lib, addon2_path / lib1_name)
            if build_release and build_debug:
                debug_lib = project1_path / "target" / "debug" / lib1_name
                if debug_lib.exists():
                    shutil.copy2(debug_lib, addon2_path / lib1_name.replace(".dylib", "_debug.dylib"))
        elif system == "Windows":
            # Windows: copy to target/x86_64-pc-windows-msvc/release/
            target_triple = "x86_64-pc-windows-msvc"
            release_dest = addon2_path / "target" / target_triple / "release"
            release_dest.mkdir(parents=True, exist_ok=True)
            if build_release:
                shutil.copy2(project1_path / "target" / "release" / lib1_name, release_dest / lib1_name)
            if build_debug:
                debug_dest = addon2_path / "target" / target_triple / "debug"
                debug_dest.mkdir(parents=True, exist_ok=True)
                debug_lib = project1_path / "target" / "debug" / lib1_name
                if debug_lib.exists():
                    shutil.copy2(debug_lib, debug_dest / lib1_name)
        else:
            # Fallback: copy to target/release/
            if build_release:
                (addon2_path / "target" / "release").mkdir(parents=True, exist_ok=True)
                shutil.copy2(project1_path / "target" / "release" / lib1_name, addon2_path / "target" / "release" / lib1_name)
            if build_debug:
                (addon2_path / "target" / "debug").mkdir(parents=True, exist_ok=True)
                debug_lib = project1_path / "target" / "debug" / lib1_name
                if debug_lib.exists():
                    shutil.copy2(debug_lib, addon2_path / "target" / "debug" / lib1_name)
        print("[SUCCESS] Deployed to both addon locations!")
        
        # Build universal binaries on macOS (unless --local-arch is specified)
        if platform.system() == "Darwin" and not local_arch_only and build_release:
            build_universal_macos(project1_path, addon1_path, lib1_name, release_only=release_only and not dev_mode)
            # Also copy universal binaries to FeagiCoreIntegration (directly to addon directory for .gdextension)
            if (addon1_path / "target" / "release" / lib1_name).exists():
                shutil.copy2(addon1_path / "target" / "release" / lib1_name, addon2_path / lib1_name)
            if build_debug and (addon1_path / "target" / "debug" / lib1_name).exists():
                shutil.copy2(addon1_path / "target" / "debug" / lib1_name, addon2_path / lib1_name.replace(".dylib", "_debug.dylib"))
        elif platform.system() == "Darwin" and local_arch_only and build_release:
            print(f"[INFO] Skipping universal binary build (using local {platform.machine()} only)")
        built_deserializer = True
    
    # feagi_shared_video - commented out from build
    # project2_path, addon2_path, lib2_name = build_rust_library(
    #     "feagi_shared_video",
    #     root_dir / "feagi_shared_video",
    #     godot_source / "addons" / "feagi_shared_video",
    #     build_release=build_release,
    #     build_debug=build_debug,
    #     no_clean=no_clean
    # )
    # if platform.system() == "Darwin" and not local_arch_only and build_release:
    #     build_universal_macos(project2_path, addon2_path, lib2_name, release_only=release_only and not dev_mode)
    # elif platform.system() == "Darwin" and local_arch_only and build_release:
    #     print(f"[INFO] Skipping universal binary build (using local {platform.machine()} only)")

    # Build feagi_agent_client (required by FeagiCoreIntegration.gdextension)
    if should_build("feagi_agent_client"):
        project4_path, addon4_path, lib4_name = build_rust_library(
            "feagi_agent_client",
            root_dir / "feagi_agent_client",
            godot_source / "addons" / "FeagiCoreIntegration",
            build_release=build_release,
            build_debug=build_debug,
            no_clean=no_clean
        )

        # Build universal binaries on macOS (unless --local-arch is specified)
        if platform.system() == "Darwin" and not local_arch_only and build_release:
            build_universal_macos(project4_path, addon4_path, lib4_name, release_only=release_only and not dev_mode)
        elif platform.system() == "Darwin" and local_arch_only and build_release:
            print(f"[INFO] Skipping universal binary build (using local {platform.machine()} only)")
        built_agent_client = True
    
    # Build feagi_type_system (deploy directly to FeagiCoreIntegration addon)
    if should_build("feagi_type_system"):
        print_section("Building feagi_type_system")
        project3_path = root_dir / "feagi_type_system"
        if not project3_path.exists():
            print(f"[ERROR] Project directory not found: {project3_path}")
            sys.exit(1)
        
        lib_ext = get_library_extension()
        lib_prefix = get_library_prefix()
        lib3_name = f"{lib_prefix}feagi_type_system.{lib_ext}"
        
        # Clean previous builds (unless --no-clean is specified)
        if not no_clean:
            print("[CLEAN] Cleaning previous builds...")
            run_command(["cargo", "clean"], cwd=project3_path)
        else:
            print("[INFO] Skipping cargo clean (using cache)")
        
        release_lib = None
        debug_lib = None
        
        if build_release:
            print("[BUILD] Building feagi_type_system (release mode)...")
            run_command(["cargo", "build", "--release", "--locked"], cwd=project3_path)
            release_lib = project3_path / "target" / "release" / lib3_name
            if not release_lib.exists():
                print(f"[ERROR] Build failed - release library not found: {release_lib}")
                sys.exit(1)
        
        if build_debug:
            print("[BUILD] Building feagi_type_system (debug mode)...")
            run_command(["cargo", "build", "--locked"], cwd=project3_path)
            debug_lib = project3_path / "target" / "debug" / lib3_name
            if not debug_lib.exists():
                print(f"[ERROR] Build failed - debug library not found: {debug_lib}")
                sys.exit(1)
        
        # Copy directly to FeagiCoreIntegration addon (not in target subdirectory)
        addon3_path = godot_source / "addons" / "FeagiCoreIntegration"
        addon3_path.mkdir(parents=True, exist_ok=True)
        if build_release and release_lib:
            shutil.copy2(release_lib, addon3_path / lib3_name)
            print(f"[SUCCESS] feagi_type_system deployed (release) to: {addon3_path / lib3_name}")
        elif build_debug and debug_lib:
            shutil.copy2(debug_lib, addon3_path / lib3_name)
            print(f"[SUCCESS] feagi_type_system deployed (debug) to: {addon3_path / lib3_name}")
        
        # Build universal binary on macOS if needed
        if platform.system() == "Darwin" and not local_arch_only and build_release:
            # Build for both architectures
            run_command(["cargo", "build", "--release", "--locked", "--target", "aarch64-apple-darwin"], cwd=project3_path)
            run_command(["cargo", "build", "--release", "--locked", "--target", "x86_64-apple-darwin"], cwd=project3_path)
            
            # Create universal binary
            arm64_lib = project3_path / "target" / "aarch64-apple-darwin" / "release" / lib3_name
            x86_64_lib = project3_path / "target" / "x86_64-apple-darwin" / "release" / lib3_name
            
            if arm64_lib.exists() and x86_64_lib.exists():
                universal_lib = addon3_path / lib3_name
                run_command(["lipo", "-create", str(arm64_lib), str(x86_64_lib), "-output", str(universal_lib)])
                print(f"[SUCCESS] Universal binary created: {universal_lib}")
        built_type_system = True
    
    # Clean up old library files in legacy/wrong locations only.
    # Do not remove addon2_path / lib: FeagiCoreIntegration is the current deploy target for the deserializer.
    print_section("Cleaning Up Legacy Files")
    if built_deserializer:
        cleanup_paths = [
            godot_source / "libfeagi_data_deserializer.dylib",
            addon1_path / "libfeagi_data_deserializer.dylib",
            addon2_path / "bin" / "macos" / "libfeagi_data_deserializer.dylib",
        ]
        for path in cleanup_paths:
            if path.exists():
                print(f"[CLEANUP] Removing legacy file: {path}")
                path.unlink()
    
    # Final success message (feagi_shared_video commented out; addon2_path = FeagiCoreIntegration here)
    feagi_core_path = godot_source / "addons" / "FeagiCoreIntegration"
    print_section("Build Complete!")
    if selected_extensions:
        print("[SUCCESS] Selected Rust extension(s) built successfully!")
    else:
        print("[SUCCESS] All Rust extensions built successfully!")
    print("[INFO] Libraries deployed to:")
    if built_deserializer:
        if build_release:
            print(f"  - {addon1_path / 'target' / 'release' / lib1_name} (feagi_rust_deserializer)")
            print(f"  - {feagi_core_path / lib1_name} (FeagiCoreIntegration)")
        if build_debug:
            print(f"  - {addon1_path / 'target' / 'debug' / lib1_name} (feagi_rust_deserializer)")
    if built_agent_client:
        print(f"  - {feagi_core_path} ({lib4_name}, platform-specific location)")
    if built_type_system:
        print(f"  - {feagi_core_path / lib3_name} (feagi_type_system)")
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

