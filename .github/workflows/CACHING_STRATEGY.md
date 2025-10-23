# Rust Binary Build Caching Strategy

This document explains how we optimize build times and avoid unnecessary rebuilds.

## Problem Statement

- Rust builds take **10+ minutes per platform** (3 platforms = 30+ minutes total)
- We don't want non-Rust changes triggering expensive rebuilds
- GitHub Actions has limited minutes per month

## Solution: Three-Layer Optimization

### 1. Path-Based Triggering ✅

**Workflow only runs when Rust code changes:**

```yaml
on:
  push:
    branches: [ staging ]
    paths:
      - 'rust_extensions/*/src/**'        # Rust source code
      - 'rust_extensions/*/Cargo.toml'    # Dependencies
      - 'rust_extensions/build.py'        # Build script
      - '.github/workflows/build-rust-binaries.yml'  # Workflow itself
```

**Effect:** Non-Rust changes (Godot scripts, docs, configs) don't trigger builds.

---

### 2. Aggressive Cargo Caching 🚀

**Caches compiled dependencies and build artifacts:**

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry     # Downloaded crates
      ~/.cargo/git          # Git dependencies
      rust_extensions/*/target  # Compiled artifacts
    key: ${{ runner.os }}-rust-binaries-${{ hashFiles('Cargo.toml', 'src/**/*.rs') }}
```

**Cache Key Strategy:**
- Hash of `Cargo.toml` + all `.rs` files
- If source unchanged → cache hit → reuse binaries
- If source changed → cache miss → rebuild

**Effect:** 
- First build: ~10 minutes
- Subsequent builds (no changes): ~30 seconds (just cache restoration)

---

### 3. Smart Build Skipping ⚡

**Check if cached binaries exist before building:**

```bash
if [ cached binaries exist ]; then
  echo "Using cache - skipping build"
  # Saves 10 minutes
else
  cargo build --release
fi
```

**Effect:** Even with cache restoration, skips the build process entirely if binaries are already present.

---

## Time Savings Example

### Scenario: Push to staging (Rust code unchanged)

| Step | Without Optimization | With Optimization |
|------|---------------------|-------------------|
| Checkout | 5s | 5s |
| Rust toolchain | 10s | 10s |
| Cache restore | N/A | 30s |
| **Build** | **10 min** | **SKIPPED** ⚡ |
| Upload artifacts | 20s | 20s |
| **Total per platform** | **~11 min** | **~1 min** |
| **Total (3 platforms)** | **~33 min** | **~3 min** |

**Savings: 30 minutes (90% reduction)** 🎉

---

## Scenario: When Does It Actually Build?

### ✅ Triggers rebuild:
1. Change to `.rs` source files
2. Change to `Cargo.toml` (dependencies)
3. Change to `build.py` script
4. Change to workflow file
5. Cache expired (GitHub caches expire after 7 days)

### ❌ Skips rebuild:
1. Changes to Godot scripts (`.gd` files)
2. Changes to documentation (`.md` files)
3. Changes to assets (`.png`, `.glb`, etc.)
4. Changes to other workflows
5. No changes to Rust code (cache hit)

---

## Cache Lifecycle

```
Day 0: Push Rust change
  → Build (10 min)
  → Cache stored
  
Day 1-7: Push Godot changes
  → Workflow doesn't run (path filter)
  → 0 minutes used
  
Day 1-7: Push Rust change
  → Cache hit
  → Skip build (30s)
  
Day 8: Cache expired
  → Rebuild (10 min)
  → New cache stored
```

---

## Manual Cache Invalidation

If you need to force a rebuild:

1. **Change Cargo.toml** (add/remove comment)
2. **Touch a source file** (add/remove whitespace)
3. **Delete cache in GitHub UI:**
   - Go to Actions → Caches
   - Delete `{os}-rust-binaries-*`

---

## Monitoring Cache Effectiveness

Check the workflow logs:

```
✅ Cached binaries found - skipping rebuild
⚡ Saved ~10 minutes of build time
```

vs

```
⚠️  No cached binaries - will build
[BUILD] Building Rust library (release mode - optimized)...
```

---

## Cost Analysis

### GitHub Actions Free Tier:
- 2,000 minutes/month for public repos
- 500 minutes/month for private repos

### Without Caching:
- 5 Rust pushes/week × 33 min = 165 min/week = **660 min/month** ⚠️

### With Caching:
- 5 Rust pushes/week × 3 min = 15 min/week = **60 min/month** ✅
- 1 cache miss/week × 33 min = 33 min/week = **132 min/month**
- **Total: ~192 min/month** ✅

**Savings: 468 minutes/month (71% reduction)** 🎉

---

## Best Practices

1. **Don't commit `Cargo.lock`** in extensions (lets cache key detect real changes)
2. **Use `--release` flag in CI** (smaller binaries, matches production)
3. **Keep cache key specific** (hash source files, not timestamps)
4. **Monitor cache hit rate** in workflow logs
5. **Consider cargo-chef** for multi-stage Docker builds (future optimization)

---

## Future Optimizations

If builds are still too slow:

1. **Incremental compilation** (already enabled in release mode)
2. **Parallel builds** via `cargo build -j $(nproc)`
3. **sccache** (distributed compilation cache)
4. **Cross-compilation** (build all targets on one runner)
5. **Pre-built dependency cache** (separate job for dependencies)

