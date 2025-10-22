# Rust Binary Distribution Strategy

## Overview

Brain-visualizer now uses **automated cross-platform binary builds** to ensure all users (Linux, macOS, Windows) can run the project immediately after cloning, without needing to compile Rust extensions.

## How It Works

### For Developers

When you merge Rust code changes to `staging`:

1. ✅ **Push your changes** to staging branch
2. 🤖 **GitHub Actions automatically**:
   - Builds binaries on Linux, macOS, Windows
   - Creates universal macOS binaries (arm64 + x86_64)
   - Commits all binaries back to staging
3. ✅ **Next pull** gets all platform binaries

**You don't need to do anything!**

### For Users

```bash
# That's it!
git clone https://github.com/feagi/brain-visualizer.git
cd brain-visualizer/godot_source
# Open in Godot - works immediately on Linux, macOS, or Windows
```

No Rust installation, no compilation, no build tools needed.

## What Triggers the Build?

The workflow runs when you push to `staging` and change:
- `rust_extensions/*/src/**` (Rust source code)
- `rust_extensions/*/Cargo.toml` (dependencies)
- `rust_extensions/build.py` (build script)

## What Gets Built?

Two Rust extensions for all platforms:

### 1. feagi_data_deserializer
High-performance WebSocket data deserialization
- Linux: `.so` files
- macOS: `.dylib` files (universal: arm64 + x86_64)
- Windows: `.dll` files

### 2. feagi_shared_video
Shared memory video reader
- Linux: `.so` files
- macOS: `.dylib` files (universal: arm64 + x86_64)
- Windows: `.dll` files

Each built in **debug** and **release** modes.

**Total: 12 binaries (~40-50 MB)**

## Repository Structure

```
brain-visualizer/
├── rust_extensions/                    # Source code (ignored build artifacts)
│   ├── build.py                        # Cross-platform build script
│   ├── feagi_data_deserializer/
│   └── feagi_shared_video/
│
├── godot_source/addons/                # Committed binaries for all platforms
│   ├── feagi_rust_deserializer/
│   │   └── target/
│   │       ├── debug/
│   │       │   ├── libfeagi_data_deserializer.dylib  ✅ Committed
│   │       │   ├── libfeagi_data_deserializer.so     ✅ Committed
│   │       │   └── feagi_data_deserializer.dll       ✅ Committed
│   │       └── release/
│   │           ├── libfeagi_data_deserializer.dylib  ✅ Committed
│   │           ├── libfeagi_data_deserializer.so     ✅ Committed
│   │           └── feagi_data_deserializer.dll       ✅ Committed
│   └── feagi_shared_video/
│       └── target/
│           ├── debug/   (same pattern)
│           └── release/ (same pattern)
│
└── .github/workflows/
    └── build-rust-binaries.yml         # Automated build workflow
```

## Monitoring Builds

### Check Workflow Status
Visit: https://github.com/feagi/brain-visualizer/actions

Look for: **"Build and Commit Rust Binaries"** workflow

### Check Latest Binary Commit
```bash
git log staging --oneline --grep="Update Rust binaries" -n 5
```

You'll see commits like:
```
abc1234 chore: Update Rust binaries for all platforms [skip ci]
```

### Verify Binaries Locally
```bash
# List all platform binaries
find godot_source/addons -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.dll" \)

# With sizes
find godot_source/addons -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.dll" \) -exec ls -lh {} \;
```

Expected output:
```
-rw-r--r-- libfeagi_data_deserializer.dylib  (4.2M)
-rw-r--r-- libfeagi_data_deserializer.so     (3.8M)
-rw-r--r-- feagi_data_deserializer.dll       (3.9M)
... (12 files total)
```

## Platform Detection

Godot automatically loads the correct binary using `.gdextension` files:

```ini
# godot_source/addons/feagi_rust_deserializer/feagi_data_deserializer.gdextension
[libraries]
macos.debug = "target/debug/libfeagi_data_deserializer.dylib"
linux.debug.x86_64 = "target/debug/libfeagi_data_deserializer.so"
windows.debug.x86_64 = "target/debug/feagi_data_deserializer.dll"
# ... release versions too
```

**Users never need to think about this** - Godot handles it!

## Manual Build (Optional)

If you need to build locally for testing:

```bash
cd rust_extensions

# Use the cross-platform build script
python3 build.py  # macOS/Linux
python build.py   # Windows

# Or use the shell wrappers
./build.sh        # macOS/Linux
build.bat         # Windows
```

This builds for your **current platform only**.  
The CI builds for **all platforms**.

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **User Setup** | Install Rust toolchain (30+ min) | Clone and run (2 min) |
| **Cross-Platform** | Build on each platform manually | Automatic via CI |
| **Onboarding** | Technical, error-prone | Simple, reliable |
| **Offline Use** | Need network for cargo | Works offline after clone |
| **Version Match** | Manual sync required | Always matches code |
| **Developer Time** | Build 3 platforms manually | Automatic in CI |

## Troubleshooting

### "Rust deserializer not available"

**Symptoms:** Brain visualizer shows warning about missing Rust extension

**Solutions:**
1. Pull latest staging:
   ```bash
   git pull origin staging
   ```

2. Check binaries exist:
   ```bash
   ls godot_source/addons/feagi_rust_deserializer/target/debug/
   ```

3. Verify your platform's binary is present:
   - macOS: `libfeagi_data_deserializer.dylib`
   - Linux: `libfeagi_data_deserializer.so`
   - Windows: `feagi_data_deserializer.dll`

4. If missing, check if CI built them:
   - Visit Actions tab
   - Check "Build and Commit Rust Binaries" workflow
   - Look for failures

### Workflow Fails

**Common causes:**
1. **Rust compilation error** - Fix Rust code first
2. **Missing dependency** - Update Cargo.toml
3. **Platform-specific issue** - Check specific runner logs

**How to debug:**
1. Go to Actions tab
2. Click failed workflow run
3. Expand the failed job (Linux/macOS/Windows)
4. Read compilation errors
5. Fix Rust code
6. Push again to staging

### Binary Size Growing

**If repo gets too large:**

Option 1: Strip debug symbols (already done in release mode)
```toml
# Cargo.toml
[profile.release]
strip = true
```

Option 2: Enable more aggressive optimization
```toml
[profile.release]
lto = true
codegen-units = 1
opt-level = "z"  # Optimize for size
```

Option 3: Consider Git LFS (future)
- Migrate to Git Large File Storage
- Keeps repo history small
- Transparent for users (git lfs is widely available)

## Architecture Compliance

This approach aligns with FEAGI architecture principles:

✅ **Deterministic** - Binary always matches code version  
✅ **Reliable** - No compilation failures for users  
✅ **Cross-platform** - Works identically on all platforms  
✅ **No fallbacks** - Rust extensions are required, always available  
✅ **Centralized** - CI builds all platforms consistently  
✅ **No hardcoded paths** - Godot handles platform detection  

## Developer Workflow

### Normal Development (No Rust Changes)
```bash
# Just work normally
git checkout -b feature/my-gdscript-feature
# ... make changes to GDScript ...
git commit -m "feat: add new feature"
git push origin feature/my-gdscript-feature
# ... create PR to staging ...
```

**Binaries not affected** - No rebuild triggered

### Rust Development
```bash
# Work on Rust code
git checkout -b feature/rust-optimization
cd rust_extensions/feagi_data_deserializer/src
# ... edit Rust code ...

# Test locally (your platform only)
cd ../..
python3 build.py

# Commit and push
git add .
git commit -m "feat: optimize data deserialization"
git push origin feature/rust-optimization

# Create PR to staging
# ... after merge to staging ...
# 🤖 CI automatically builds all platforms
# 🤖 CI commits binaries back to staging
```

**Binaries automatically updated** for all platforms!

### Testing Binaries Before Merge

Want to test all platform binaries before merging to staging?

```bash
# Push to a test branch
git push origin feature/rust-optimization

# Manually trigger workflow (if enabled for your branch)
# Or: temporarily change workflow to trigger on your branch
# .github/workflows/build-rust-binaries.yml:
# on:
#   push:
#     branches: [ staging, feature/rust-optimization ]

# After CI completes, pull and test
git pull
```

## FAQ

**Q: Why commit binaries to git?**  
A: Best user experience. Clone and run immediately. No dependencies, no compilation, no failures.

**Q: Won't this make the repo huge?**  
A: Binaries only change when Rust code changes (infrequent). ~50 MB total. Modern git handles this fine.

**Q: What about Docker deployments?**  
A: Still works! Docker can use the committed binaries or build fresh ones.

**Q: Can I still build locally?**  
A: Yes! Use `python3 build.py` anytime. Useful for development.

**Q: What about web exports?**  
A: Web uses WASM instead of native binaries. Separate build process. See `WASM_COMPATIBILITY.md`.

**Q: How often does CI run?**  
A: Only when Rust code changes in staging. Not on every commit.

**Q: Can I disable auto-commit?**  
A: Yes, comment out the push step in the workflow. But why? This is the whole point!

**Q: What if I need arm64 Linux or other architectures?**  
A: Add to the build matrix in the workflow. CI will build and commit automatically.

## Next Steps

1. ✅ Merge this to staging
2. ✅ Make a small Rust change to test workflow
3. ✅ Verify all platform binaries get committed
4. ✅ Test cloning on Windows/Linux to confirm it works
5. ✅ Update main README with simpler setup instructions
6. ✅ Celebrate! 🎉

## Related Documentation

- **Workflow Details**: `.github/workflows/README_RUST_BINARIES.md`
- **Rust Integration**: `RUST_INTEGRATION_SUMMARY.md`
- **Build System**: `rust_extensions/BUILD_SYSTEM.md`
- **WASM Compatibility**: `WASM_COMPATIBILITY.md`
- **Deployment**: `DEPLOY.md`

---

**Last Updated:** 2025-10-22  
**Status:** ✅ Production Ready  
**Maintainer:** FEAGI Development Team

