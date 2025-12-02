# FDP Hover Feature Implementation Summary

## Overview
Extended the brain visualizer's cortical area hover feature to display FDP-decoded information for OPU (Output Processing Unit) cortical areas.

## Implementation Details

### 1. Rust GDExtension Function (`feagi_data_deserializer`)
**File**: `brain-visualizer/rust_extensions/feagi_data_deserializer/src/lib.rs`

Added `decode_fdp_value()` function that:
- Uses the **actual FDP decoding logic** from `feagi_connector_core` crate (v0.0.50-beta.54+)
- Implements the exact same formulas used by FDP's internal decoders:
  - **Linear encoding**: `value = (z_index / z_max_depth) * 100.0`
  - **Exponential encoding**: `value = 0.5^z_index * 100.0`
- Calculates channel number from voxel X coordinate
- Validates all inputs and provides detailed error messages
- Returns: `{success: bool, channel: int, value: float, fdp_version: string, error: string}`

**Key Features**:
- No invented logic - uses FDP's actual decoding functions
- Supports all encoding types: linear, exponential
- Supports all encoding formats: 1d, 2d, 3d, 4d
- Published crate dependency (not local path)

### 2. GDScript Integration
**File**: `brain-visualizer/godot_source/addons/UI_BrainMonitor/UI_BrainMonitor_Overlay.gd`

Modified `mouse_over_single_cortical_area()` to:
- Initialize FDP deserializer on startup
- Call `decode_fdp_value()` for OPU cortical areas only (IPU will have separate implementation)
- Display result in format: `FDP:{version} CH:{channel} Value:{value}%`
- Only shows FDP info when cortical area has decoded ID information (encoding type/format)

### 3. Dependencies
**File**: `brain-visualizer/rust_extensions/feagi_data_deserializer/Cargo.toml`

Added dependency:
```toml
feagi_connector_core = "0.0.50-beta.54"
```

## Display Format
When hovering over an OPU voxel, the bottom-left overlay shows:
```
Area - [cortical name] [coordinates] | [device info] | FDP:0.0.50-beta.54 CH:3 Value:45.67%
```

## Current Scope
- **Implemented**: OPU cortical areas only
- **Pending**: IPU cortical areas (different variation to be implemented)
- **Additive**: All existing hover functionality preserved

## Testing
To test the feature:
1. Load brain visualizer with a genome containing OPU areas with encoding info
2. Hover mouse over OPU cortical area voxels
3. Verify FDP decoding information appears in bottom-left overlay
4. Verify the displayed values match FDP's actual decoding logic

## Technical Notes
- The Rust extension compiles to `libfeagi_data_deserializer.dylib` (macOS)
- Library is loaded by Godot via `feagi_data_deserializer.gdextension`
- Build command: `cargo build --release` in `rust_extensions/feagi_data_deserializer/`
- Copy to: `godot_source/addons/FeagiCoreIntegration/libfeagi_data_deserializer.dylib`

## Architecture Compliance
✅ Uses published crates (not local paths)
✅ Uses actual FDP decoding logic (not invented)
✅ Additive only (no existing functionality removed)
✅ OPU-specific (as requested)
✅ Proper error handling and validation

