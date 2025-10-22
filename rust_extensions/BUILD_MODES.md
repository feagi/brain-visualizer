# Rust Build Modes

This document explains the different build modes for FEAGI Rust extensions.

## Build Modes

### Debug Mode
- **Compile time:** Fast (~30 seconds)
- **Runtime performance:** Slow (no optimizations)
- **Binary size:** 100+ MB (includes debug symbols, DWARF data, unoptimized code)
- **Use case:** Local development, debugging with IDE
- **Git tracked:** NO (excluded via .gitignore)

### Release Mode
- **Compile time:** Slower (~2 minutes)
- **Runtime performance:** Fast (full optimizations)
- **Binary size:** 10-20 MB (symbols stripped)
- **Use case:** Production, distribution, end users
- **Git tracked:** YES (committed by CI/CD)

## Usage

### For Developers (Local Development)
Build both debug and release:
```bash
cd rust_extensions
python3 build.py
```

This creates:
- `godot_source/addons/*/target/debug/*.{so,dylib,dll}` - NOT committed to Git
- `godot_source/addons/*/target/release/*.{so,dylib,dll}` - NOT committed to Git (you build locally)

### For CI/CD (GitHub Actions)
Build release only:
```bash
cd rust_extensions
python3 build.py --release
```

This creates:
- `godot_source/addons/*/target/release/*.{so,dylib,dll}` - Committed to Git

## Why This Design?

1. **Developers need debug builds** for:
   - Faster compilation during development
   - Better error messages and stack traces
   - IDE debugger integration (breakpoints, variable inspection)

2. **Users/CI only need release builds** because:
   - Optimized performance for production
   - Small file size (GitHub has 100 MB limit)
   - No need for debug symbols in distributed binaries

3. **Git ignores debug builds** because:
   - 100+ MB files exceed GitHub limits
   - Debug symbols are platform/compiler specific
   - No value in distributing debug builds to end users

## File Size Comparison

Typical sizes for `feagi_data_deserializer`:

| Platform | Debug | Release |
|----------|-------|---------|
| Linux    | 104 MB | 12 MB |
| macOS    | 98 MB | 15 MB |
| Windows  | 95 MB | 10 MB |

**Total if all committed:** 627 MB  
**Total with release only:** 37 MB ✅

