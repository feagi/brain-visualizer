# FEAGI Brain Visualizer - Rust Extensions

This directory contains Rust-based extensions for the FEAGI Brain Visualizer, providing high-performance data processing capabilities through Godot's GDExtension system.

> 📖 **For comprehensive setup and web export instructions, see [RUST_GODOT_GUIDE.md](./RUST_GODOT_GUIDE.md)**

## Overview

The Rust extensions replace computationally intensive GDScript operations with native Rust code, providing significant performance improvements for:

- **WebSocket data deserialization**: Converting byte streams from FEAGI into coordinate arrays
- **Bulk array processing**: Efficient conversion of packed byte arrays to typed arrays
- **Memory management**: Reduced allocations and improved cache locality

## Architecture

### Components

1. **feagi_data_deserializer**: Main Rust library that wraps FEAGI's data serialization library
2. **GDExtension Integration**: Seamless integration with Godot through the gdext library
3. **Rust-Only Processing**: All deserialization is handled by Rust for maximum performance

### Performance Benefits

- **Native Code Execution**: Rust compiles to optimized machine code vs interpreted GDScript
- **Zero-Copy Operations**: Direct memory mapping where possible
- **SIMD Optimizations**: Compiler can leverage CPU vector instructions
- **Memory Safety**: Rust's ownership system prevents common memory errors

## Building

### Prerequisites

- **Rust toolchain** (1.70+)
- **Python 3.6+** (for cross-platform build script)
- **Godot 4.1+**
- **Git** access to FEAGI repositories
- **macOS only**: Xcode command-line tools (for universal binaries)

### Quick Build

**Windows:**
```batch
build.bat
```

**macOS/Linux:**
```bash
./build.sh
```

**All platforms (direct):**
```bash
python build.py
```

> 📖 **For detailed build system documentation, see [BUILD_SYSTEM.md](./BUILD_SYSTEM.md)**

### What Gets Built

The automated build script compiles and installs:
1. **feagi_data_deserializer**: High-performance data deserialization
2. **feagi_shared_video**: Shared memory video reader

For each extension, it:
- Builds both debug and release versions
- Copies libraries to Godot addon directories (`godot_source/addons/`)
- Creates universal binaries on macOS (arm64 + x86_64)
- Cleans up old files in incorrect locations

### Manual Build (Advanced)

If you need to build a specific extension manually:

```bash
cd rust_extensions/feagi_data_deserializer
cargo build --release
```

The build process will:
1. Download and compile the gdext library
2. Clone and build the feagi_data_serialization library
3. Generate the shared library (.dylib on macOS, .dll on Windows, .so on Linux)

### Integration

Built libraries are automatically copied to their respective addon directories and loaded by Godot through `.gdextension` configuration files.

## Usage

### In GDScript

```gdscript
# Initialize the Rust deserializer
var rust_deserializer = FeagiDataDeserializer.new()

# Decode Type 11 neuron data
var decoded_result = rust_deserializer.decode_type_11_data(byte_buffer)

# Process the results
if decoded_result.success:
    for cortical_id in decoded_result.areas.keys():
        var area_data = decoded_result.areas[cortical_id]
        # area_data contains x_array, y_array, z_array, p_array
```

### WebSocket Integration

The `FEAGIWebSocketAPI` class requires the Rust deserializer to function. If the Rust extension fails to load, WebSocket processing will be disabled with clear error messages.

## Testing

Run the test script to verify the integration:

```gdscript
# In Godot, run the test_rust_deserializer.tscn scene
# Check the output console for test results
```

## Performance Comparison

| Operation | GDScript (ms) | Rust (ms) | Improvement |
|-----------|---------------|-----------|-------------|
| Type 11 Decode (1000 neurons) | ~15ms | ~2ms | **7.5x faster** |
| Bulk Array Conversion | ~8ms | ~0.5ms | **16x faster** |
| Memory Allocations | High | Minimal | **Reduced GC pressure** |

*Benchmarks performed on Apple M1 Pro with 1000 neurons across 10 cortical areas*

## Troubleshooting

### Common Issues

1. **"FeagiDataDeserializer not found"**
   - Ensure the .gdextension file is in the correct location
   - Check that the shared library was built successfully
   - Verify Godot can load GDExtensions (check project settings)

2. **Build failures**
   - Ensure Python 3.6+ is installed: `python --version` or `python3 --version`
   - Update Rust toolchain: `rustup update`
   - Clear cargo cache: `cargo clean`
   - Check network connectivity for git dependencies
   - On macOS: Ensure Xcode command-line tools are installed: `xcode-select --install`
   - Try manual build: `cd feagi_data_deserializer && cargo build --release`

3. **WebSocket processing disabled**
   - Check that the Rust deserializer is properly initialized (look for 🦀 log messages)
   - Ensure the shared library is in the correct location
   - Verify the .gdextension file paths are correct

### Debug Mode

Enable debug logging by setting the environment variable:
```bash
export RUST_LOG=debug
```

## Future Enhancements

- [ ] Integration with additional FEAGI data types
- [ ] GPU-accelerated processing using wgpu
- [x] WebAssembly support for web deployment ✅ **COMPLETED**
- [ ] Multi-threaded processing for large datasets
- [ ] Custom memory allocators for specific use cases

## Contributing

When modifying the Rust code:

1. Follow Rust naming conventions and documentation standards
2. Add comprehensive tests for new functionality
3. Update benchmarks to measure performance impact
4. Ensure the Rust extension loads properly and handles all edge cases
5. Update this README with any new features or breaking changes

## License

This Rust extension follows the same license as the main FEAGI Brain Visualizer project.
