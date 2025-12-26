# Brain Visualizer macOS Crash Fix - Code Signing

## Issue

Brain Visualizer was crashing on macOS with the following error:

```
Exception Type: EXC_CRASH (SIGKILL (Code Signature Invalid))
codeSigningTrustLevel: 4294967295 (untrusted)
```

## Root Cause

macOS requires all applications to be code signed. When an app is exported from Godot without proper code signing, macOS's security system (Gatekeeper) kills the app immediately on launch with `SIGKILL (Code Signature Invalid)`.

The export preset was configured for ad-hoc signing (`codesign/codesign=3`) but the actual signing step was not being performed after export.

## Solution

### Automatic Signing (Recommended)

The export script (`export_macos.sh`) now automatically signs the app bundle after export:

1. Signs all dynamic libraries (`.dylib`) in `Contents/Frameworks/`
2. Signs all executables in `Contents/MacOS/`
3. Signs any bundled binaries in `Contents/Resources/bin/`
4. Signs the entire app bundle
5. Verifies the signature

**No action required** - signing happens automatically during export.

### Manual Signing (For Existing Apps)

If you have an existing unsigned app that's crashing, use the standalone signing script:

```bash
cd brain-visualizer/godot_source
./sign_app.sh "path/to/Brain Visualizer.app"
```

Or sign directly with codesign:

```bash
codesign --force --deep --sign - "Brain Visualizer.app"
codesign --verify --verbose "Brain Visualizer.app"
```

## Technical Details

### Ad-Hoc Signing

The fix uses **ad-hoc signing** (`codesign -s -`), which:
- ✅ Allows the app to run on macOS without being killed
- ✅ Works for local development and testing
- ✅ Does not require a developer certificate
- ❌ Not suitable for distribution (users will see "unidentified developer" warning)

### For Distribution

For production distribution, you should:
1. Obtain an Apple Developer certificate
2. Update `export_presets.cfg` with your Team ID and certificate
3. Sign with your developer identity
4. Notarize the app with Apple

See [Godot's code signing documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_osx.html#code-signing) for details.

## Verification

To verify an app is properly signed:

```bash
codesign -dv "Brain Visualizer.app"
codesign --verify --verbose "Brain Visualizer.app"
```

Expected output should show:
- `Authority=Apple Development: ...` (for developer cert) or `Authority=adhoc` (for ad-hoc)
- `valid on disk` and `satisfies its Designated Requirement`

## Files Modified

1. `godot_source/export_macos.sh` - Added automatic code signing after export
2. `godot_source/sign_app.sh` - New standalone script for signing existing apps
3. `BUILD.md` - Updated documentation with troubleshooting section

## Testing

After applying this fix:
1. Export a new app: `cd godot_source && ./export_macos.sh`
2. Launch the app - it should start without crashing
3. Check Console.app for any code signing errors (should be none)

## References

- [macOS Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Godot macOS Export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_osx.html)
- [Gatekeeper and Code Signing](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)


















