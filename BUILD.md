# Brain Visualizer - Build Guide

This document describes how to build and export Brain Visualizer for different platforms.

## Prerequisites

- **Godot 4.5+** (stable)
- **Rust** (for building native extensions)
- **Python 3.8+** (for build scripts)

## macOS Build

### Automated Export

The easiest way to export for macOS is using the automated script:

```bash
cd godot_source
./export_macos.sh
```

The script will:
1. Find your Godot installation automatically
2. Clean previous exports
3. Verify export templates are installed
4. Export the project to `Brain-Visualizer.dmg`
5. Verify the exported DMG

### Manual Godot Path

If Godot isn't in the standard location:

```bash
./export_macos.sh /Applications/Godot.app/Contents/MacOS/Godot
```

Or set the environment variable:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
./export_macos.sh
```

### Export Templates

If you get an error about missing export templates:

1. Open Godot Editor
2. Go to: **Editor → Manage Export Templates**
3. Click **Download and Install**
4. Wait for download to complete
5. Run the export script again

## UID Cache (CI / Release Workflow)

The release workflow requires `godot_source/.godot/uid_cache.bin` to be committed. If CI fails with "invalid UID" or "Pure virtual function called":

1. Open the project in Godot Editor: `godot godot_source/project.godot`
2. Let the editor finish importing
3. Close Godot
4. Commit: `git add godot_source/.godot/uid_cache.bin && git commit -m "Add uid_cache.bin for CI"`

## Building Rust Extensions

Before exporting, ensure all Rust extensions are built:

```bash
cd rust_extensions
python3 build.py --release
```

This builds:
- `feagi_embedded` - Embedded FEAGI runtime
- `feagi_data_deserializer` - LZ4 decompression and data processing
- `feagi_shared_video` - Shared video processing

## Export Modes

### Debug vs Release

The export script uses **release mode** by default for optimized builds.

For debug builds, modify `export_macos.sh` and change:
```bash
"$godot_bin" --headless --export-release "$EXPORT_PRESET_NAME" "$OUTPUT_FILE"
```
to:
```bash
"$godot_bin" --headless --export-debug "$EXPORT_PRESET_NAME" "$OUTPUT_FILE"
```

### Script Export Modes

Edit `export_presets.cfg`:

```ini
script_export_mode=1  # Text scripts (slower, easier to debug)
script_export_mode=2  # Compiled bytecode (faster, production)
```

**Text mode (1)**: Use during development to ensure fresh exports
**Compiled mode (2)**: Use for production builds for better performance

## CI/CD Integration

### GitHub Actions

See `.github/workflows/build-macos.yml` for automated builds.

The workflow:
1. Checks out the repository
2. Installs Godot
3. Builds Rust extensions
4. Exports the macOS app
5. Uploads the DMG as an artifact

### Manual CI/CD

For other CI systems:

```bash
# Install Godot
wget https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_macos.universal.zip
unzip Godot_v4.5-stable_macos.universal.zip
GODOT_BIN="$(pwd)/Godot.app/Contents/MacOS/Godot"

# Install export templates
$GODOT_BIN --headless --quit  # First run creates config dir
wget https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz
mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.5.stable"
unzip Godot_v4.5-stable_export_templates.tpz -d "$HOME/Library/Application Support/Godot/export_templates/4.5.stable"

# Build Rust extensions
cd rust_extensions
cargo build --release

# Export
cd ../godot_source
./export_macos.sh "$GODOT_BIN"
```

## Troubleshooting

### Export fails with "Template not found"

Install export templates (see [Export Templates](#export-templates) section above).

### Rust libraries not found

Ensure all Rust extensions are built:
```bash
cd rust_extensions
python3 build.py --release
ls -la feagi_embedded/libfeagi_embedded.dylib
ls -la feagi_data_deserializer/libfeagi_data_deserializer.dylib
ls -la feagi_shared_video/libfeagi_shared_video.dylib
```

### "Desktop mode detected" appears in exported app

This indicates stale compiled scripts. Fix:
1. Set `script_export_mode=1` in `export_presets.cfg`
2. Delete `.godot` directory: `rm -rf godot_source/.godot`
3. Re-export

### App crashes immediately with "Code Signature Invalid"

**Symptom:** App crashes on launch with crash report showing:
- `Exception Type: EXC_CRASH (SIGKILL (Code Signature Invalid))`
- `codeSigningTrustLevel: 4294967295` (untrusted)

**Cause:** macOS requires all apps to be code signed. Unsigned apps are killed immediately.

**Fix:** The export script now automatically signs the app. If you have an existing unsigned app:

```bash
cd godot_source
./sign_app.sh "path/to/Brain Visualizer.app"
```

Or re-export the app - signing is now automatic:
```bash
cd godot_source
./export_macos.sh
```

**Note:** Ad-hoc signing (using `-`) is sufficient for local development. For distribution, use a developer certificate.

### App shows "Disconnected"

This usually means:
1. FEAGI binary is not bundled (expected for embedded mode)
2. Embedded extension is not loading properly
3. Check the console logs for debug messages

Expected log for embedded mode:
```
[DEBUG] FEAGI binary path: .../Resources/bin/feagi
[DEBUG] FEAGI binary exists: false
🦀 [BV] No FEAGI binary found - initializing FEAGI embedded extension...
```

## Platform-Specific Notes

### macOS

- The script builds a **Universal Binary** (x86_64 + arm64)
- All Rust libraries must be universal binaries
- **Code signing is automatic** - The export script automatically signs the app with ad-hoc signature
- Signing and notarization with developer certificate are optional but recommended for distribution

### Windows (TODO)

Coming soon: `export_windows.sh` or `export_windows.ps1`

### Linux (TODO)

Coming soon: `export_linux.sh`

### Web (HTML5)

Web export requires additional steps to exclude native extensions. See `export_web.sh`.

## Build Artifacts

After successful export:

- **DMG**: `godot_source/Brain-Visualizer.dmg`
- **App Bundle**: Inside the DMG at `/Volumes/Brain-Visualizer/Brain-Visualizer.app`
- **Export Log**: `godot_source/export.log`

## Clean Build

To start fresh:

```bash
cd godot_source
rm -rf .godot Brain-Visualizer.dmg Brain-Visualizer.app export.log
```

## Next Steps

After building:

1. Test the exported app
2. Verify all Rust extensions load correctly
3. Test FEAGI embedded mode
4. Verify code signature (automatic, but you can verify with `codesign -dv "Brain Visualizer.app"`)
5. (Optional) Sign with developer certificate and notarize for distribution

## Resources

- [Godot Export Documentation](https://docs.godotengine.org/en/stable/tutorials/export/index.html)
- [Godot Command Line Reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)

