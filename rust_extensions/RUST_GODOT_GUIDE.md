# Rust + Godot Integration Guide

This guide covers everything needed to use Rust with Godot in the FEAGI Brain Visualizer project, including desktop and web export support.

## Overview

The project uses Rust for high-performance data processing with dual-platform support:
- **Desktop**: Native GDExtension (`.dylib`/`.dll`/`.so`) for maximum performance
- **Web**: WebAssembly (WASM) for browser compatibility

## Project Structure

```
rust_extensions/
├── feagi_data_deserializer/          # Main GDExtension crate
│   ├── src/lib.rs                    # Rust implementation
│   ├── Cargo.toml                    # Dependencies & web features
│   ├── .cargo/config.toml            # Web build configuration
│   └── feagi_data_deserializer.gdextension  # Godot extension config
├── feagi_wasm_processing/            # Web-only WASM crate
│   ├── src/lib.rs                    # WASM bindings
│   └── Cargo.toml                    # WASM dependencies
├── build.sh                          # Desktop build script
└── README.md                         # Basic build instructions
```

## Prerequisites

### For Desktop Development

1. **Rust Toolchain**:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   rustup update
   ```

2. **Platform-specific tools**:
   - **macOS**: Xcode Command Line Tools
   - **Linux**: `build-essential`, `pkg-config`
   - **Windows**: Visual Studio Build Tools

### For Web Export (Additional)

1. **Nightly Rust** (required for WASM std building):
   ```bash
   rustup toolchain install nightly
   rustup component add rust-src --toolchain nightly
   ```

2. **WASM targets**:
   ```bash
   # For our current WASM setup (wasm-bindgen)
   rustup target add wasm32-unknown-unknown
   
   # For future godot-rust web support (when available)
   rustup target add wasm32-unknown-emscripten --toolchain nightly
   ```

3. **wasm-bindgen-cli**:
   ```bash
   cargo install wasm-bindgen-cli
   ```

4. **Emscripten** (for future godot-rust web support):
   ```bash
   git clone https://github.com/emscripten-core/emsdk.git
   cd emsdk
   ./emsdk install 3.1.74
   ./emsdk activate 3.1.74
   source ./emsdk_env.sh  # Add to your shell profile
   ```

## Building

### Desktop Build

```bash
cd rust_extensions
./build.sh
```

This script:
1. Builds release and debug versions for `feagi_data_deserializer`
2. Creates universal binaries (macOS: arm64+x86_64)
3. Copies files to `godot_source/addons/feagi_rust_deserializer/`
4. Clears quarantine attributes (macOS)

### Building the Shared Memory Video Reader (feagi_shared_video)

macOS (Universal debug):

```bash
cd rust_extensions/feagi_shared_video
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo build --target aarch64-apple-darwin
cargo build --target x86_64-apple-darwin
lipo -create -output target/universal_debug.dylib \
  target/aarch64-apple-darwin/debug/libfeagi_shared_video.dylib \
  target/x86_64-apple-darwin/debug/libfeagi_shared_video.dylib
cp target/universal_debug.dylib ../../godot_source/addons/feagi_shared_video/target/debug/libfeagi_shared_video.dylib
```

Windows (Debug):

```powershell
cd rust_extensions\feagi_shared_video
cargo build
Copy-Item target\debug\feagi_shared_video.dll ..\..\godot_source\addons\feagi_shared_video\target\debug\
```

Linux (Debug):

```bash
cd rust_extensions/feagi_shared_video
cargo build
cp target/debug/libfeagi_shared_video.so ../../godot_source/addons/feagi_shared_video/target/debug/
```

Update `godot_source/addons/feagi_shared_video/feagi_shared_video.gdextension` to match your platform paths if necessary.

### Web Build

```bash
cd rust_extensions/feagi_wasm_processing
./build_wasm.sh
```

This creates:
- `feagi_wasm_processing_bg.wasm` - The WASM binary
- `feagi_wasm_processing.js` - JavaScript bindings

Files are copied to `godot_source/wasm/` for web export.

## Configuration Files

### 1. GDExtension Configuration

`feagi_data_deserializer.gdextension` defines library paths for each platform:

```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1
reloadable = false

[libraries]
# Desktop platforms
macos.debug = "target/debug/libfeagi_data_deserializer.dylib"
macos.release = "target/release/libfeagi_data_deserializer.dylib"
windows.debug.x86_64 = "target/x86_64-pc-windows-msvc/debug/feagi_data_deserializer.dll"
# ... other platforms

# Web platforms (for future godot-rust web support)
web.debug.wasm32 = "target/wasm32-unknown-emscripten/debug/feagi_data_deserializer.wasm"
web.release.wasm32 = "target/wasm32-unknown-emscripten/release/feagi_data_deserializer.wasm"
```

### 2. Rust Dependencies

`Cargo.toml` includes web features for future compatibility:

```toml
[dependencies]
godot = { 
    git = "https://github.com/godot-rust/gdext", 
    branch = "master", 
    features = ["experimental-wasm", "lazy-function-tables"] 
}
feagi_data_serialization = "0.0.50-beta.18"
```

### 3. Web Build Configuration

`.cargo/config.toml` for Emscripten builds:

```toml
[target.wasm32-unknown-emscripten]
rustflags = [
    "-C", "link-args=-sSIDE_MODULE=2",
    "-Zlink-native-libraries=no",
    "-Cllvm-args=-enable-emscripten-cxx-exceptions=0",
]
```

## Godot Integration

### Desktop Usage

The native GDExtension is automatically loaded by Godot:

```gdscript
# In GDScript - automatically available
var deserializer = ClassDB.instantiate("FeagiDataDeserializer")
var result = deserializer.decode_type_11_data(byte_data)
```

### Web Usage

Web builds use a WASM decoder with JavaScript interop:

```gdscript
# Platform detection
if OS.has_feature("web"):
    # Use WASM decoder
    var result = WASMDecoder.decode_type_11(byte_data)
else:
    # Use native GDExtension
    var result = rust_deserializer.decode_type_11_data(byte_data)
```

The `WASMDecoder` class (`godot_source/Utils/WASMDecoder.gd`) handles:
- WASM module loading
- JavaScript-to-Godot data conversion
- Error handling and fallbacks

## Web Export Process

### 1. Export Script

Use the provided export script:

```bash
cd godot_source
GODOT_BIN="/path/to/Godot" ./export_web.sh [output_path]
```

The script:
- Creates a clean temporary project copy
- Excludes native GDExtension files
- Copies WASM assets to the output directory
- Preserves original project files

### 2. Manual Export

If using Godot editor export:

1. **Project Settings**:
   - Set `application/wasm_dir="wasm/"`
   - Enable required export features

2. **Export Preset**:
   - Create "Web" export preset
   - Enable "Extensions Support"
   - Configure thread support as needed

3. **File Management**:
   - Ensure WASM files are in `godot_source/wasm/`
   - Native GDExtension files should be excluded from web builds

## Data Flow Architecture

### Desktop Flow
```
FEAGI Data → WebSocket → Native Rust GDExtension → Godot Dictionary → UI
```

### Web Flow
```
FEAGI Data → WebSocket → WASM Module → JavaScript → JSON → Godot Dictionary → UI
```

### Key Differences

1. **Performance**: Native is faster, WASM has JavaScript interop overhead
2. **Data Types**: Native uses direct Godot types, WASM requires JSON serialization
3. **Loading**: Native loads at startup, WASM loads asynchronously
4. **Debugging**: Native has better debugging, WASM uses browser dev tools

## Troubleshooting

### Desktop Issues

1. **"Class not found" errors**:
   - Check `.gdextension` file paths
   - Verify library files exist in `target/debug|release/`
   - Clear quarantine attributes (macOS): `xattr -dr com.apple.quarantine addon_dir/`

2. **Build failures**:
   - Update Rust: `rustup update`
   - Clean build: `cargo clean`
   - Check platform-specific dependencies

### Web Issues

1. **WASM not loading**:
   - Check browser console for fetch errors
   - Verify WASM files are in correct directory
   - Ensure web server supports WASM MIME type

2. **"Invalid result type" errors**:
   - Usually indicates JavaScript-to-Godot conversion issues
   - Check WASM function return format
   - Verify JSON serialization is working

3. **Cross-origin issues**:
   - Serve files from proper web server
   - Check CORS headers for WASM files

### Build Environment

1. **Keep dependencies updated**:
   ```bash
   cargo update
   rustup update
   ```

2. **Clean builds when switching targets**:
   ```bash
   cargo clean
   ```

3. **Verify toolchain installation**:
   ```bash
   rustup show
   cargo --version
   ```

## Performance Considerations

### Desktop
- Use release builds for production
- Profile with `cargo flamegraph` if needed
- Consider `lto = true` for smaller binaries

### Web
- WASM has ~2-3x overhead vs native
- JSON serialization adds latency
- Consider data batching for large datasets
- Use browser dev tools for profiling

## Future Improvements

1. **Native Web Support**: When godot-rust adds full web support, migrate from custom WASM to native GDExtension
2. **Multi-threading**: Explore web workers for WASM processing
3. **Streaming**: Implement streaming data processing for large datasets
4. **Caching**: Add WASM module caching for faster subsequent loads

## References

- [godot-rust Documentation](https://godot-rust.github.io/book/)
- [godot-rust Web Export Guide](https://godot-rust.github.io/book/toolchain/export-web.html)
- [wasm-bindgen Book](https://rustwasm.github.io/wasm-bindgen/)
- [Godot GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)
