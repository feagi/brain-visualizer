# Cross-Platform Build System for FEAGI Rust Extensions

## Quick Start

### Windows
```batch
build.bat
```

### macOS/Linux
```bash
./build.sh
```

### Direct Python (All Platforms)
```bash
python build.py
```

## Architecture

The build system uses a **single Python script** (`build.py`) as the core implementation, with lightweight OS-specific wrappers (`build.sh`, `build.bat`) for convenience.

### Why Python?

- **True cross-platform**: Works identically on Windows, macOS, and Linux
- **Path handling**: `pathlib` automatically handles OS-specific path separators
- **Platform detection**: Built-in `platform` module handles OS differences
- **Maintainability**: All logic in one place - no duplicate code
- **No dependencies**: Uses only Python standard library
- **Easy to debug**: Standard Python error handling and logging

### Design Benefits

1. **Single source of truth**: All build logic in `build.py`
2. **Easy maintenance**: Update one file, all platforms benefit
3. **Familiar interface**: Users can still run `./build.sh` or `build.bat`
4. **Platform-aware**: Automatically handles:
   - `.dylib` (macOS), `.so` (Linux), `.dll` (Windows)
   - Universal binaries on macOS (arm64 + x86_64)
   - Path separators (`/` vs `\`)
   - Library naming (`lib` prefix on Unix)

## What Gets Built

The build system compiles two Rust extensions:

1. **feagi_data_deserializer**: High-performance data deserialization
2. **feagi_shared_video**: Shared memory video reader

For each extension, it:
- Builds both debug and release versions
- Copies libraries to Godot addon directories
- On macOS: Creates universal binaries (arm64 + x86_64)
- Cleans up old files in wrong locations

## Requirements

- **Python 3.6+** (usually pre-installed on macOS/Linux)
- **Rust toolchain** (cargo, rustc)
- **macOS only**: Xcode command-line tools for `lipo`

## Troubleshooting

### "python: command not found"
- **Windows**: Install Python from python.org
- **Linux**: `sudo apt install python3` (or equivalent)
- **macOS**: Python 3 should be pre-installed; try `python3` instead

### Build fails on macOS universal binary
- Ensure Xcode command-line tools: `xcode-select --install`
- The script will auto-install targets: `aarch64-apple-darwin`, `x86_64-apple-darwin`

### Permission denied on Unix
```bash
chmod +x build.sh
./build.sh
```

## Alternative Approaches

If you prefer not to use Python, here are other options:

### Option 1: cargo-make (Rust-native)

Install:
```bash
cargo install cargo-make
```

Create `Makefile.toml`:
```toml
[env]
GODOT_SOURCE_DIR = "../godot_source"

[tasks.build-deserializer]
cwd = "feagi_data_deserializer"
script = '''
cargo build --release
cargo build
'''

[tasks.build-shared-video]
cwd = "feagi_shared_video"
script = '''
cargo build --release
cargo build
'''

[tasks.copy-libs]
dependencies = ["build-deserializer", "build-shared-video"]
script_runner = "@shell"
script = '''
# Copy logic here (simplified for example)
cp feagi_data_deserializer/target/release/*.{dylib,so,dll} \
   ${GODOT_SOURCE_DIR}/addons/feagi_rust_deserializer/target/release/
'''

[tasks.build-all]
dependencies = ["build-deserializer", "build-shared-video", "copy-libs"]
```

Run with:
```bash
cargo make build-all
```

**Pros**: Rust ecosystem, powerful task dependencies  
**Cons**: Extra dependency, less flexible than Python

### Option 2: Just (Modern task runner)

Install:
```bash
cargo install just
```

Create `justfile`:
```just
# Cross-platform build for FEAGI Rust extensions

godot_dir := "../godot_source"

# Build all extensions
build-all: build-deserializer build-shared-video
    @echo "✅ All extensions built!"

# Build deserializer
build-deserializer:
    cd feagi_data_deserializer && cargo build --release
    cd feagi_data_deserializer && cargo build

# Build shared video
build-shared-video:
    cd feagi_shared_video && cargo build --release
    cd feagi_shared_video && cargo build

# Copy libraries to Godot
copy-libs: build-all
    # Add copy logic here
```

Run with:
```bash
just build-all
```

**Pros**: Simple, readable, good for task running  
**Cons**: Less flexible for complex platform detection

### Option 3: Pure Shell Scripts (Not Recommended)

Keep separate `.sh` for Unix and `.bat` for Windows.

**Pros**: No extra dependencies  
**Cons**: 
- Duplicate logic across files
- Hard to maintain
- Windows batch is limited and error-prone
- PowerShell would be better but adds complexity

## Maintenance Guidelines

When adding new Rust extensions:

1. Open `build.py`
2. Add a new call to `build_rust_library()` in `main()`:
   ```python
   project3_path, addon3_path, lib3_name = build_rust_library(
       "your_new_extension",
       root_dir / "your_new_extension",
       godot_source / "addons" / "your_addon_name"
   )
   ```
3. If on macOS and you want universal binaries:
   ```python
   if platform.system() == "Darwin":
       build_universal_macos(project3_path, addon3_path, lib3_name)
   ```

That's it! No need to modify wrapper scripts.

## CI/CD Integration

The Python script is CI-friendly:

```yaml
# GitHub Actions example
- name: Build Rust Extensions
  run: python rust_extensions/build.py
```

```yaml
# GitLab CI example
build_rust:
  script:
    - python rust_extensions/build.py
```

Exit codes are properly propagated (0 for success, non-zero for failure).

## Performance Notes

- **Release builds**: Optimized with `-O3` level optimizations
- **Debug builds**: Include debug symbols, faster compile time
- **Universal binaries**: Slightly larger but support both Intel and Apple Silicon Macs
- **Clean builds**: `cargo clean` ensures fresh compilation

## Questions?

For issues with the build system, check:
1. Python version: `python --version` (need 3.6+)
2. Rust toolchain: `cargo --version`
3. Build output for specific errors
4. Platform-specific tools (lipo on macOS)

