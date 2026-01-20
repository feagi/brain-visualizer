# Releasing Brain Visualizer

## Overview

This repository automatically builds and publishes Brain Visualizer binaries for all platforms when you create a version tag.

**Build Requirements:**
- **Godot Engine 4.5** (automatically installed by workflow)
- **Export Templates 4.5.stable** (automatically installed by workflow)
- **feagi-core crates** (pulled from crates.io during build)

---

## Release Types

### Production Release
```bash
git tag v1.2.3
git push origin v1.2.3
```
**Publishes:** Stable release, used by feagi-desktop production builds

### Beta Release (Pre-release)
```bash
git tag v1.2.3-beta.1
git push origin v1.2.3-beta.1
```
**Publishes:** Pre-release, used by feagi-desktop beta builds

### Alpha Release (Pre-release)
```bash
git tag v1.2.3-alpha.1
git push origin v1.2.3-alpha.1
```
**Publishes:** Pre-release, typically feagi-desktop uses `staging` branch instead

---

## What Gets Built

When you push a tag, GitHub Actions automatically:

### 1. macOS (.app bundle)
- Godot-exported BrainVisualizer.app
- Universal binary (Intel + Apple Silicon)
- **Output:** `BrainVisualizer-macos-v1.2.3.tar.gz`

### 2. Linux (executable)
- Godot-exported x86_64 binary
- Includes .pck data file
- **Output:** `BrainVisualizer-linux-v1.2.3.tar.gz`

### 3. Windows (executable)
- Godot-exported .exe
- Includes .pck data file
- **Output:** `BrainVisualizer-windows-v1.2.3.zip`

---

## Godot Version

**Current:** Godot 4.5 stable (September 2025 release)

To update Godot version:
1. Edit `.github/workflows/release.yml`
2. Change download URLs to new version
3. Test locally with new Godot first

---

## Export Templates

The workflow uses Godot's built-in export templates. Ensure your `godot_source/export_presets.cfg` has:

```ini
[preset.0]
name="macOS"
platform="macOS"
runnable=true
...

[preset.1]
name="Linux/X11"
platform="Linux/X11"
runnable=true
...

[preset.2]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
...
```

---

## Manual Dispatch

For emergency releases or testing:

**GitHub UI:** Actions → Release Brain Visualizer → Run workflow
- Enter tag name (e.g., `v1.2.3-hotfix`)
- Triggers the build manually

---

## Integration with feagi-desktop

### Production/Beta Builds
When feagi-desktop builds a production or beta release:
```yaml
1. Downloads BrainVisualizer-macos-v1.2.3.tar.gz from GitHub releases
2. Extracts BrainVisualizer.app
3. Bundles it into the desktop app
```

**Fast CI:** No Godot export needed, just download and bundle (~5 min)

### Alpha/Staging Builds
When feagi-desktop builds alpha or staging:
```yaml
1. Checks out brain-visualizer staging branch
2. Installs Godot
3. Exports BrainVisualizer.app from source
4. Bundles it into the desktop app
```

**Slower CI:** Full Godot export process (~10 min)

---

## Version Synchronization

### Coordinated Release
For major versions, coordinate tags across repos:

```bash
# brain-visualizer
git tag v1.2.3
git push origin v1.2.3

# feagi-rust
git tag v1.2.3
git push origin v1.2.3

# feagi-desktop (after above releases are published)
git tag v1.2.3
git push origin v1.2.3
```

### Independent Updates
For bug fixes in one component:

```bash
# Just tag the component that changed
cd brain-visualizer
git tag v1.2.4
git push origin v1.2.4

# feagi-desktop can still use v1.2.3 of feagi-rust
```

---

## Troubleshooting

### Build Failed
- Check GitHub Actions logs: Actions → Release Brain Visualizer
- Common issues:
  - Godot export errors (check export_presets.cfg)
  - Missing export templates (workflow installs them)
  - Script errors in Godot project

### Release Not Found
- Wait 10-15 minutes for workflow to complete
- Check releases page: https://github.com/feagi/brain-visualizer/releases
- Verify tag was pushed correctly: `git ls-remote --tags origin`

### App Doesn't Launch
- Test locally before releasing
- Check Godot project errors
- Verify all required resources are exported

---

## Best Practices

1. **Test export locally first:**
   ```bash
   cd godot_source
   godot --export-release "macOS" ../build/test.app --headless
   ```

2. **Semantic versioning**: Use v1.2.3 format consistently

3. **Tag annotations**: `git tag -a v1.2.3 -m "Release v1.2.3"`

4. **Update Info.plist**: Workflow handles this automatically

5. **Branch protection**: Releases from `main` only (production), `staging` for pre-releases

---

## CI/CD Workflow Details

File: `.github/workflows/release.yml`

**Trigger:** Any tag starting with `v`

**Jobs:**
1. `release-macos` - Exports macOS .app bundle
2. `release-linux` - Exports Linux executable
3. `release-windows` - Exports Windows .exe
4. `create-release` - Creates GitHub release with all binaries

**Runtime:** ~10-15 minutes total

**Requirements:**
- Repository has GitHub Actions enabled
- No special secrets needed (uses default GITHUB_TOKEN)
- `export_presets.cfg` must be committed with presets: "macOS", "Linux/X11", "Windows Desktop"
- Godot project must be compatible with **Godot 4.5**
- `feagi-core` crates must be available on crates.io

---

## For First-Time Setup

1. **Verify export_presets.cfg** exists in `godot_source/`

2. **Test locally:**
   ```bash
   godot --export-release "macOS" test.app --path godot_source --headless
   ```

3. **Enable GitHub Actions** in repository settings

4. **Create test tag:**
   ```bash
   git tag v0.1.0-test
   git push origin v0.1.0-test
   ```

5. **Verify release appears** at: https://github.com/feagi/brain-visualizer/releases

6. **Delete test release** if successful

---

## Godot Project Requirements

For CI to work, your Godot project must:
- Have valid export presets configured
- Work in headless mode (no GUI dependencies)
- Not require manual intervention during export
- Have all resources properly referenced (not absolute paths)

---

## Questions?

- Workflow issues: Check `.github/workflows/release.yml`
- Godot export problems: Check `godot_source/export_presets.cfg`
- feagi-desktop integration: See `neuraville/feagi-desktop/HYBRID_RELEASE_STRATEGY.md`
- Build failures: Open an issue with Actions logs




## Overview

This repository automatically builds and publishes Brain Visualizer binaries for all platforms when you create a version tag.

**Build Requirements:**
- **Godot Engine 4.5** (automatically installed by workflow)
- **Export Templates 4.5.stable** (automatically installed by workflow)
- **feagi-core crates** (pulled from crates.io during build)

---

## Release Types

### Production Release
```bash
git tag v1.2.3
git push origin v1.2.3
```
**Publishes:** Stable release, used by feagi-desktop production builds

### Beta Release (Pre-release)
```bash
git tag v1.2.3-beta.1
git push origin v1.2.3-beta.1
```
**Publishes:** Pre-release, used by feagi-desktop beta builds

### Alpha Release (Pre-release)
```bash
git tag v1.2.3-alpha.1
git push origin v1.2.3-alpha.1
```
**Publishes:** Pre-release, typically feagi-desktop uses `staging` branch instead

---

## What Gets Built

When you push a tag, GitHub Actions automatically:

### 1. macOS (.app bundle)
- Godot-exported BrainVisualizer.app
- Universal binary (Intel + Apple Silicon)
- **Output:** `BrainVisualizer-macos-v1.2.3.tar.gz`

### 2. Linux (executable)
- Godot-exported x86_64 binary
- Includes .pck data file
- **Output:** `BrainVisualizer-linux-v1.2.3.tar.gz`

### 3. Windows (executable)
- Godot-exported .exe
- Includes .pck data file
- **Output:** `BrainVisualizer-windows-v1.2.3.zip`

---

## Godot Version

**Current:** Godot 4.5 stable (September 2025 release)

To update Godot version:
1. Edit `.github/workflows/release.yml`
2. Change download URLs to new version
3. Test locally with new Godot first

---

## Export Templates

The workflow uses Godot's built-in export templates. Ensure your `godot_source/export_presets.cfg` has:

```ini
[preset.0]
name="macOS"
platform="macOS"
runnable=true
...

[preset.1]
name="Linux/X11"
platform="Linux/X11"
runnable=true
...

[preset.2]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
...
```

---

## Manual Dispatch

For emergency releases or testing:

**GitHub UI:** Actions → Release Brain Visualizer → Run workflow
- Enter tag name (e.g., `v1.2.3-hotfix`)
- Triggers the build manually

---

## Integration with feagi-desktop

### Production/Beta Builds
When feagi-desktop builds a production or beta release:
```yaml
1. Downloads BrainVisualizer-macos-v1.2.3.tar.gz from GitHub releases
2. Extracts BrainVisualizer.app
3. Bundles it into the desktop app
```

**Fast CI:** No Godot export needed, just download and bundle (~5 min)

### Alpha/Staging Builds
When feagi-desktop builds alpha or staging:
```yaml
1. Checks out brain-visualizer staging branch
2. Installs Godot
3. Exports BrainVisualizer.app from source
4. Bundles it into the desktop app
```

**Slower CI:** Full Godot export process (~10 min)

---

## Version Synchronization

### Coordinated Release
For major versions, coordinate tags across repos:

```bash
# brain-visualizer
git tag v1.2.3
git push origin v1.2.3

# feagi-rust
git tag v1.2.3
git push origin v1.2.3

# feagi-desktop (after above releases are published)
git tag v1.2.3
git push origin v1.2.3
```

### Independent Updates
For bug fixes in one component:

```bash
# Just tag the component that changed
cd brain-visualizer
git tag v1.2.4
git push origin v1.2.4

# feagi-desktop can still use v1.2.3 of feagi-rust
```

---

## Troubleshooting

### Build Failed
- Check GitHub Actions logs: Actions → Release Brain Visualizer
- Common issues:
  - Godot export errors (check export_presets.cfg)
  - Missing export templates (workflow installs them)
  - Script errors in Godot project

### Release Not Found
- Wait 10-15 minutes for workflow to complete
- Check releases page: https://github.com/feagi/brain-visualizer/releases
- Verify tag was pushed correctly: `git ls-remote --tags origin`

### App Doesn't Launch
- Test locally before releasing
- Check Godot project errors
- Verify all required resources are exported

---

## Best Practices

1. **Test export locally first:**
   ```bash
   cd godot_source
   godot --export-release "macOS" ../build/test.app --headless
   ```

2. **Semantic versioning**: Use v1.2.3 format consistently

3. **Tag annotations**: `git tag -a v1.2.3 -m "Release v1.2.3"`

4. **Update Info.plist**: Workflow handles this automatically

5. **Branch protection**: Releases from `main` only (production), `staging` for pre-releases

---

## CI/CD Workflow Details

File: `.github/workflows/release.yml`

**Trigger:** Any tag starting with `v`

**Jobs:**
1. `release-macos` - Exports macOS .app bundle
2. `release-linux` - Exports Linux executable
3. `release-windows` - Exports Windows .exe
4. `create-release` - Creates GitHub release with all binaries

**Runtime:** ~10-15 minutes total

**Requirements:**
- Repository has GitHub Actions enabled
- No special secrets needed (uses default GITHUB_TOKEN)
- `export_presets.cfg` must be committed with presets: "macOS", "Linux/X11", "Windows Desktop"
- Godot project must be compatible with **Godot 4.5**
- `feagi-core` crates must be available on crates.io

---

## For First-Time Setup

1. **Verify export_presets.cfg** exists in `godot_source/`

2. **Test locally:**
   ```bash
   godot --export-release "macOS" test.app --path godot_source --headless
   ```

3. **Enable GitHub Actions** in repository settings

4. **Create test tag:**
   ```bash
   git tag v0.1.0-test
   git push origin v0.1.0-test
   ```

5. **Verify release appears** at: https://github.com/feagi/brain-visualizer/releases

6. **Delete test release** if successful

---

## Godot Project Requirements

For CI to work, your Godot project must:
- Have valid export presets configured
- Work in headless mode (no GUI dependencies)
- Not require manual intervention during export
- Have all resources properly referenced (not absolute paths)

---

## Questions?

- Workflow issues: Check `.github/workflows/release.yml`
- Godot export problems: Check `godot_source/export_presets.cfg`
- feagi-desktop integration: See `neuraville/feagi-desktop/HYBRID_RELEASE_STRATEGY.md`
- Build failures: Open an issue with Actions logs

