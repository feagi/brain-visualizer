# Brain Visualizer Windows DLL Missing - Root Cause Review

**Date:** 2025-02-20  
**Issue:** GDExtension DLLs (feagi_type_system.dll, feagi_data_deserializer.dll, feagi_shared_video.dll) are missing from the Windows release package (BrainVisualizer-Remote-Windows.zip).

---

## Summary

The DLLs are built and placed in the Godot project, but they never reach the final Windows zip because:

1. **Godot export does not reliably copy GDExtension [dependencies] on Windows** (known Godot 4.x behavior)
2. **The workflow never copies the built DLLs into the exports directory** before packaging

---

## Build Flow (Windows)

1. **Build Rust extensions** – `build.py` compiles and copies DLLs to:
   - `godot_source/addons/FeagiCoreIntegration/feagi_type_system.dll`
   - `godot_source/addons/FeagiCoreIntegration/target/x86_64-pc-windows-msvc/release/feagi_data_deserializer.dll`
   - (feagi_shared_video: not built in CI)

2. **Stage rust libraries artifact** – Copies DLLs to `rust-libs/` and uploads as artifact (used later for PyPI wheels, not for the BV package).

3. **Export Godot project** – `--export-release "Windows Desktop" ../exports/BrainVisualizer-Remote.exe`
   - Produces: `exports/BrainVisualizer-Remote.exe`, `exports/BrainVisualizer-Remote.pck`
   - Godot should copy [dependencies] from .gdextension files into the export dir, but this is unreliable on Windows

4. **Create distribution package** – Collects from `exports/`:
   ```pwsh
   $files = @()
   $files += "BrainVisualizer-Remote.exe"
   $files += "BrainVisualizer-Remote.pck"
   $files += Get-ChildItem -Filter "*.dll" | Select-Object -ExpandProperty Name
   Compress-Archive -Path $files -DestinationPath BrainVisualizer-Remote-Windows.zip
   ```
   - If Godot did not copy the DLLs, `*.dll` yields nothing and the zip has no GDExtension DLLs.

---

## Root Causes

### 1. Godot export does not reliably include GDExtension DLLs on Windows

- `.gdextension` files define `[dependencies]` (e.g. `feagi_type_system.dll`, `feagi_data_deserializer.dll`).
- Godot 4.x is known to have issues with copying these dependencies on Windows exports.
- Even when it works, behavior can vary by Godot version and export preset.

### 2. No explicit copy of DLLs into exports before packaging

- The workflow assumes Godot will place the DLLs in the export output.
- There is no step that copies `rust-libs/` or `godot_source/addons/FeagiCoreIntegration/...` into `exports/` before creating the zip.
- `rust-libs/` is only used for the PyPI `build-rust-binaries` job, not for the BV Windows package.

### 3. Desktop export filter skips feagi_rust_deserializer manifest

- `desktop_filter.gd` skips `res://addons/feagi_rust_deserializer/feagi_data_deserializer.gdextension` with the comment “desktop binary already has it compiled in”.
- GDExtensions are loaded dynamically, not compiled in; that comment is misleading.
- The active manifest is `FeagiCoreIntegration/feagi_data_deserializer.gdextension`, which is not skipped, so this is not the main cause of missing DLLs.

---

## Recommended Fix

Add a step before **Create distribution package (Windows)** that copies the built DLLs into `exports/`:

```yaml
- name: Copy GDExtension DLLs to exports (Windows)
  if: runner.os == 'Windows'
  shell: bash
  run: |
    cd exports
    # Copy from addons (same source used by rust-libs staging)
    cp -v ../godot_source/addons/FeagiCoreIntegration/feagi_type_system.dll . 2>/dev/null || true
    cp -v ../godot_source/addons/FeagiCoreIntegration/target/x86_64-pc-windows-msvc/release/feagi_data_deserializer.dll . 2>/dev/null || true
    # feagi_shared_video optional
    cp -v ../godot_source/addons/feagi_shared_video/target/x86_64-pc-windows-msvc/release/feagi_shared_video.dll . 2>/dev/null || true
    echo "DLLs in exports:"
    ls -la *.dll 2>/dev/null || echo "No DLLs found"
```

This makes the Windows package independent of Godot’s dependency-copy behavior.

---

## References

- `brain-visualizer/.github/workflows/release.yml` – build-bv-remote job, Windows matrix
- `brain-visualizer/godot_source/addons/FeagiCoreIntegration/*.gdextension` – dependency paths
- `brain-visualizer/rust_extensions/build.py` – where DLLs are copied
- `brain-visualizer/godot_source/addons/feagi_export_filter/desktop_filter.gd` – export filter
- Godot 4 GDExtension Windows export issues (e.g. forum/godotengine#101734)
