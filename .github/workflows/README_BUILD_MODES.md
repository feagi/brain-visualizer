# Brain Visualizer CI/CD - 3 Build Modes

**Workflow:** `build-distribution-packages.yml`

**Produces 3 distinct distribution packages for different use cases**

---

## Overview

The CI/CD automatically builds Brain Visualizer in 3 different modes:

| Mode | Platforms | FEAGI | Size | Use Case |
|------|-----------|-------|------|----------|
| **1. Embedded** | macOS, Windows, Linux | In-process | ~200MB | Premium desktop, offline, demos |
| **2. Remote Desktop** | macOS, Windows, Linux | External | ~50MB | Developers, shared FEAGI, multi-client |
| **3. Web** | Browser (WASM) | Cloud | ~20MB | Online demos, accessibility, cloud |

---

## Triggers

### Automatic Builds

- **Push to `main` or `release/*`:** Builds all 3 modes
- **Git tags (`v*`):** Builds all 3 modes + creates GitHub Release

### Manual Trigger

Via GitHub Actions UI - you can select which modes to build:

```
Actions → Build Distribution Packages → Run workflow
  ☑ Build Mode 1 (Desktop Embedded)
  ☑ Build Mode 2 (Desktop Remote)
  ☑ Build Mode 3 (Web)
```

---

## Build Process

### Mode 1: Desktop Embedded

**Job 1: `build-feagi-embedded`**
- Runs on: Linux, macOS, Windows (parallel)
- Builds: `libfeagi_embedded.dylib/.so/.dll` for each platform
- macOS: Creates universal binary (Intel + ARM)
- Upload: Artifacts for next stage
- Time: ~10-15 minutes per platform

**Job 2: `export-desktop-embedded`**
- Depends on: Job 1 (needs FEAGI embedded libraries)
- Downloads: FEAGI embedded libraries from Job 1
- Builds: Existing Rust extensions (data deserializer)
- Exports: Godot project with **all extensions included**
- Creates: Distribution packages (.zip, .dmg, .tar.gz)
- Upload: Final distribution packages
- Time: ~5 minutes per platform

**Total artifacts:**
- `BrainVisualizer-Embedded-macOS.zip` (~200MB)
- `BrainVisualizer-Embedded-Windows.zip` (~180MB)
- `BrainVisualizer-Embedded-Linux.tar.gz` (~190MB)

---

### Mode 2: Desktop Remote

**Job: `export-desktop-remote`**
- Runs on: Linux, macOS, Windows (parallel)
- Builds: Only data deserializer (NOT FEAGI embedded)
- Exports: Godot project with **feagi_embedded excluded**
- Creates: Lightweight distribution packages
- Upload: Final packages
- Time: ~5 minutes per platform

**Total artifacts:**
- `BrainVisualizer-Remote-macOS.zip` (~50MB)
- `BrainVisualizer-Remote-Windows.zip` (~45MB)
- `BrainVisualizer-Remote-Linux.tar.gz` (~50MB)

---

### Mode 3: Web

**Job: `export-web`**
- Runs on: Linux
- Builds: WASM (if applicable)
- Exports: Godot project for web
- Excludes: All native extensions
- Creates: Web bundle (HTML + WASM)
- Upload: Web distribution
- Time: ~3 minutes

**Total artifacts:**
- `BrainVisualizer-Web.tar.gz` (~20MB)

---

## GitHub Release

**When:** Git tag pushed (e.g., `git tag v2.0.0 && git push --tags`)

**What happens:**
1. All 3 modes build in parallel
2. Distribution packages created
3. GitHub Release auto-created with:
   - Release notes
   - All 9 distribution files attached
   - Installation instructions

**Release includes:**
- 3 × macOS packages (embedded, remote, web)
- 3 × Windows packages
- 3 × Linux packages
- 1 × Web bundle

**Total: 7 downloadable assets per release**

---

## Caching Strategy

### Rust Build Cache

```yaml
~/.cargo/registry        # Crate registry
~/.cargo/git            # Git dependencies
feagi-core/target       # FEAGI compiled artifacts
feagi/target            # FEAGI binary artifacts
rust_extensions/*/target # Extension artifacts
```

**Benefits:**
- First build: ~15 minutes
- Cached build: ~2-5 minutes
- Cache hit rate: ~80% (if no Rust changes)

### Godot Export Cache

Godot doesn't cache well - always re-exports. But export is fast (~2-3 minutes).

---

## Build Matrix

### Platform Matrix (Mode 1 & 2)

```yaml
matrix:
  include:
    - os: ubuntu-latest
      platform: Linux
      lib_extension: .so
    - os: macos-latest
      platform: macOS
      lib_extension: .dylib
    - os: windows-latest
      platform: Windows
      lib_extension: .dll
```

**Parallel execution:** All 3 platforms build simultaneously

### macOS Special Handling

macOS builds create **universal binaries** (Intel + ARM):

```bash
# Build both architectures
cargo build --target aarch64-apple-darwin --release
cargo build --target x86_64-apple-darwin --release

# Combine into universal binary
lipo -create \
  target/aarch64-apple-darwin/release/libfeagi_embedded.dylib \
  target/x86_64-apple-darwin/release/libfeagi_embedded.dylib \
  -output target/release/libfeagi_embedded.dylib
```

---

## Artifacts

### Intermediate Artifacts (7 days retention)

**From Job 1 (`build-feagi-embedded`):**
- `feagi-embedded-linux` - Linux `.so` file
- `feagi-embedded-macos` - macOS universal `.dylib` file
- `feagi-embedded-windows` - Windows `.dll` file

**Purpose:** Pass to Job 2 for Godot export

### Final Artifacts (30 days retention)

**Desktop Embedded (Mode 1):**
- `BrainVisualizer-Embedded-macOS.zip`
- `BrainVisualizer-Embedded-Windows.zip`
- `BrainVisualizer-Embedded-Linux.tar.gz`

**Desktop Remote (Mode 2):**
- `BrainVisualizer-Remote-macOS.zip`
- `BrainVisualizer-Remote-Windows.zip`
- `BrainVisualizer-Remote-Linux.tar.gz`

**Web (Mode 3):**
- `BrainVisualizer-Web.tar.gz`

**Purpose:** Download and distribute to users

---

## File Sizes

### Mode 1: Embedded

| Platform | Uncompressed | Compressed (.zip) |
|----------|--------------|-------------------|
| macOS | ~250MB | ~200MB |
| Windows | ~230MB | ~180MB |
| Linux | ~240MB | ~190MB |

**Includes:**
- Godot engine + BV (~30MB)
- FEAGI embedded library (~13MB)
- Rust data deserializer (~3MB)
- Assets and scenes (~50MB)
- Debug symbols stripped

### Mode 2: Remote

| Platform | Uncompressed | Compressed (.zip) |
|----------|--------------|-------------------|
| macOS | ~70MB | ~50MB |
| Windows | ~65MB | ~45MB |
| Linux | ~70MB | ~50MB |

**Includes:**
- Godot engine + BV (~30MB)
- Rust data deserializer (~3MB)
- Assets and scenes (~50MB)
- **NO** FEAGI embedded

### Mode 3: Web

| Component | Size |
|-----------|------|
| WASM | ~15MB |
| Assets | ~5MB |
| HTML/JS | ~500KB |

**Total:** ~20MB

---

## Environment Variables

### For Users (Runtime)

```bash
# Force remote mode even if embedded is available
export FEAGI_MODE=remote
export FEAGI_API_URL=http://192.168.1.100:8000
export FEAGI_WS_HOST=192.168.1.100
export FEAGI_WS_PORT=9050

./BrainVisualizer-Embedded.app
# Will use remote mode despite having embedded capability
```

### For CI/CD (Build Time)

```yaml
env:
  GODOT_VERSION: 4.2.1
  FEAGI_VERSION: 2.0.0
  CARGO_TERM_COLOR: always
```

---

## Workflow Steps Explained

### Step 1: Build FEAGI Embedded (All Platforms)

```yaml
build-feagi-embedded:
  strategy:
    matrix:
      os: [ubuntu, macos, windows]
  
  steps:
    - Checkout code
    - Install Rust
    - Cache dependencies
    - cargo build --release
    - Upload library artifact
```

**Why parallel?** Saves time - all platforms build simultaneously (~15 min total instead of ~45 min sequential)

### Step 2: Export Desktop Embedded (All Platforms)

```yaml
export-desktop-embedded:
  needs: build-feagi-embedded  # Waits for libraries
  strategy:
    matrix:
      os: [ubuntu, macos, windows]
  
  steps:
    - Download FEAGI embedded library
    - Build data deserializer
    - Export Godot (includes all extensions)
    - Create distribution package
    - Upload package
```

### Step 3: Export Desktop Remote (All Platforms)

```yaml
export-desktop-remote:
  # No dependency on build-feagi-embedded
  steps:
    - Build data deserializer only
    - Remove feagi_embedded addon
    - Export Godot (lightweight)
    - Create package
```

### Step 4: Export Web

```yaml
export-web:
  steps:
    - Export for Web platform
    - Exclude all native extensions
    - Create web bundle
```

### Step 5: Create Release (Tags Only)

```yaml
create-release:
  if: startsWith(github.ref, 'refs/tags/v')
  needs: [all export jobs]
  
  steps:
    - Download all artifacts
    - Create GitHub Release
    - Attach all packages
    - Generate release notes
```

---

## Build Times

**First build (no cache):**
- Mode 1: ~20 minutes (all platforms)
- Mode 2: ~8 minutes (all platforms)
- Mode 3: ~3 minutes
- **Total: ~20 minutes** (parallel execution)

**Cached build (no Rust changes):**
- Mode 1: ~10 minutes
- Mode 2: ~5 minutes
- Mode 3: ~3 minutes
- **Total: ~10 minutes**

**Per-platform breakdown:**
- Rust build (FEAGI embedded): ~10-15 min (cached: ~2-5 min)
- Rust build (data deserializer): ~2-3 min (cached: ~1 min)
- Godot export: ~2-3 min (no cache)
- Package creation: ~1 min

---

## Testing in CI

### Automated Tests (Future)

Add test jobs before export:

```yaml
test-feagi-embedded:
  needs: build-feagi-embedded
  steps:
    - Load extension in Godot
    - Run test_feagi_embedded.gd
    - Verify initialization, start/stop, stats
    - Upload test results
```

### Manual Testing

After workflow completes:
1. Download artifacts from Actions tab
2. Extract and test on target platform
3. Verify all 3 modes work

---

## Troubleshooting

### Build Fails on Windows

**Issue:** Rust linking errors  
**Solution:** Windows runner may need MSVC toolchain setup
```yaml
- name: Setup MSVC (Windows)
  if: runner.os == 'Windows'
  uses: ilammy/msvc-dev-cmd@v1
```

### macOS Universal Binary Fails

**Issue:** `lipo: can't open input file`  
**Solution:** Ensure both arch builds succeed before lipo
```yaml
- name: Verify both architectures
  run: |
    ls -lh target/aarch64-apple-darwin/release/
    ls -lh target/x86_64-apple-darwin/release/
```

### Godot Export Fails

**Issue:** Missing export templates  
**Solution:** Ensure Godot setup includes templates
```yaml
uses: chickensoft-games/setup-godot@v1
with:
  include-templates: true  # Important!
```

### Artifact Too Large

**Issue:** GitHub has 2GB limit per artifact  
**Solution:** Our largest (Mode 1 macOS) is ~200MB - well within limit

---

## Maintenance

### Updating Godot Version

1. Update env variable:
```yaml
env:
  GODOT_VERSION: 4.3.0  # New version
```

2. Update export presets if needed (usually automatic)

### Updating FEAGI Version

1. Update env variable:
```yaml
env:
  FEAGI_VERSION: 2.1.0
```

2. Ensure FEAGI library version matches in `feagi/Cargo.toml`

### Adding New Platform

Add to matrix:
```yaml
matrix:
  include:
    # ... existing ...
    - os: ubuntu-latest
      platform: Linux-ARM64
      target: aarch64-unknown-linux-gnu
```

---

## Cost Estimation

**GitHub Actions free tier:**
- 2,000 minutes/month for private repos
- Unlimited for public repos

**Our usage per build:**
- Mode 1 (all platforms): ~60 minutes (20 min × 3 platforms parallel)
- Mode 2 (all platforms): ~24 minutes (8 min × 3 platforms)
- Mode 3: ~3 minutes
- **Total per run: ~60 minutes** (parallel execution)

**Monthly (assuming 10 releases):**
- 10 builds × 60 min = 600 minutes
- Well within free tier!

---

## Release Process

### For Maintainers

**To create a new release:**

```bash
# 1. Ensure main branch is stable
git checkout main
git pull

# 2. Create and push tag
git tag v2.0.0 -m "Release 2.0.0 - FEAGI Embedded Support"
git push origin v2.0.0

# 3. Wait for CI/CD
# GitHub Actions will:
#   - Build all 3 modes
#   - Create artifacts
#   - Create GitHub Release
#   - Attach all packages
```

**Time:** ~20 minutes from tag push to release ready

**Output:** GitHub Release page with 7 downloadable assets

---

## Download Artifacts

### From Actions Tab

1. Go to: Actions → Build Distribution Packages → [Latest run]
2. Scroll to "Artifacts" section
3. Download desired mode(s)

### From Releases Page

1. Go to: Releases → [Latest release]
2. Download from "Assets" section
3. Choose your platform and mode

---

## Local Development

### Building Locally (without CI/CD)

**Mode 1 (Embedded):**
```bash
cd brain-visualizer/rust_extensions
./build_feagi_embedded.sh
cd ../godot_source
godot --export-release "macOS" ../exports/BV-Embedded.app
```

**Mode 2 (Remote):**
```bash
cd brain-visualizer/godot_source
# Ensure feagi_embedded addon is excluded
rm -rf addons/feagi_embedded
godot --export-release "macOS" ../exports/BV-Remote.app
```

**Mode 3 (Web):**
```bash
cd brain-visualizer/godot_source
godot --export-release "Web" ../exports/web/index.html
```

---

## FAQ

### Q: Why build 3 separate modes instead of one with runtime detection?

**A:** Distribution size and user experience.
- **Embedded users** don't want to download 200MB if they use remote
- **Remote users** don't want 13MB embedded library they'll never use
- **Web users** literally can't use native libraries

### Q: Can we build all modes from one export?

**A:** No - Godot export presets control file inclusion/exclusion. We need separate exports.

### Q: Why does Mode 1 take longer to build?

**A:** Must compile entire FEAGI stack (~30 crates). Mode 2 only compiles data deserializer (~1 crate).

### Q: Can users switch modes after installation?

**A:** Only by installing a different package. Mode is determined at build time (file inclusion).

**Exception:** Embedded build CAN run in remote mode via environment variables (the library is there but unused).

### Q: What if FEAGI embedded build fails but remote succeeds?

**A:** CI continues! Each mode is independent. Users get Mode 2 & 3, Mode 1 marked as failed.

---

## Monitoring

### Success Indicators

- ✅ All jobs green
- ✅ 7 artifacts uploaded
- ✅ File sizes within expected ranges
- ✅ GitHub Release created (for tags)

### Failure Indicators

- ❌ Red jobs - check logs
- ❌ Missing artifacts - check upload steps
- ❌ Wrong file sizes - check exclusion filters

---

## Next Steps

1. **Test workflow:** Push to `main` or create test tag
2. **Verify artifacts:** Download and test on each platform
3. **Iterate:** Fix any platform-specific issues
4. **Document:** Update user installation guide

---

**Maintained by:** Neuraville DevOps  
**Last Updated:** November 5, 2025  
**Related:** `BUILD_MODES_STRATEGY.md`, `export_presets.cfg`

