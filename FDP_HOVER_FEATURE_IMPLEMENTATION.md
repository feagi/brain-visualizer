# FDP Hover Feature Implementation Summary

## Overview
Extended the brain visualizer's cortical area hover feature to display FDP-decoded information for OPU (Output Processing Unit) cortical areas using **FDP v0.0.50-beta.59**.

## Implementation Details

### 1. Rust GDExtension Functions (`feagi_data_deserializer`)
**File**: `brain-visualizer/rust_extensions/feagi_data_deserializer/src/lib.rs`

Added two functions:

#### A. `parse_cortical_id_encoding()` - Binary Cortical ID Parser
- Decodes base64 cortical IDs to 8-byte binary format
- Parses FDP's binary structure per `feagi-data-structures` specification:
  ```
  [0] = 'i' or 'o' (input/output marker)
  [1-3] = 3-char unit identifier (e.g., "mot", "cam")
  [4-5] = data_type_configuration (u16, little-endian):
          bits 0-3: variant (0=Percentage, 4=SignedPercentage, etc.)
          bit 4: frame handling (0=Absolute, 1=Incremental)
          bit 5: positioning (0=Linear, 1=Fractional)
  [6] = unit_index
  [7] = group_index
  ```
- Extracts encoding_type and encoding_format from binary structure
- Returns: `{success: bool, encoding_type: string, encoding_format: string, error: string}`

#### B. `decode_fdp_value()` - FDP Value Decoder
- Uses the **actual FDP decoding logic** from `feagi-sensorimotor` crate
- Implements the exact same formulas used by FDP's internal decoders:
  - **Linear encoding**: `value = (z_index / z_max_depth) * 100.0`
  - **Exponential encoding**: `value = 0.5^z_index * 100.0`
- Calculates channel number from voxel X coordinate
- Returns: `{success: bool, channel: int, value: float, fdp_version: string, error: string}`

**Key Features**:
- No invented logic - uses FDP's actual binary format and decoding functions
- Supports all encoding types: linear, exponential
- Supports all encoding formats: 1d, 2d, 3d, 4d
- Published crate dependency from crates.io (not local path)
- **No FEAGI dependency** - works entirely from cortical ID and voxel coordinates

### 2. GDScript Integration
**File**: `brain-visualizer/godot_source/addons/UI_BrainMonitor/UI_BrainMonitor_Overlay.gd`

Modified `mouse_over_single_cortical_area()` to:
- Initialize FDP deserializer on startup
- Call `decode_fdp_value()` for OPU cortical areas only (IPU will have separate implementation)
- Display result in format: `FDP:{version} CH:{channel} Value:{value}%`
- Only shows FDP info when cortical area has decoded ID information (encoding type/format)

### 3. Dependencies
**Files**: 
- `brain-visualizer/rust_extensions/feagi_data_deserializer/Cargo.toml`
- `brain-visualizer/rust_extensions/feagi_type_system/Cargo.toml`

All FDP dependencies updated to **v0.0.50-beta.59**:
```toml
feagi-structures = "0.0.1-beta.1"
feagi-serialization = "0.0.1-beta.1"
feagi-sensorimotor = "0.0.50-beta.59"
base64 = "0.22"  # For base64 cortical ID decoding
```

## Display Format
When hovering over an OPU voxel, the bottom-left overlay shows:
```
Area - [cortical name] [coordinates] | [device info] | FDP:0.0.50-beta.59 CH:3 Value:45.67%
```

### Example
For cortical ID `b21vdAQAAAA=` (motor, SignedPercentage, Linear, 1D) hovering at voxel (0, 0, 5):
```
Area - motor (0, 0, 5) | FDP:0.0.50-beta.59 CH:0 Value:62.50%
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
✅ Uses published crates from crates.io (not local paths)
✅ Uses actual FDP binary format and decoding logic (not invented)
✅ Additive only (no existing functionality removed)
✅ OPU-specific (as requested, IPU will be separate)
✅ Proper error handling and validation
✅ No FEAGI dependency - works from cortical ID binary structure
✅ All extensions on consistent FDP version (beta.59)

## How It Works (No FEAGI Required)
1. User hovers over OPU voxel
2. Base64 cortical ID (e.g., `b21vdAQAAAA=`) is decoded to 8 bytes
3. Binary structure parsed using FDP's format to extract encoding type/format
4. Voxel coordinates decoded using FDP's actual decoding formulas
5. Result displayed in overlay

**Completely standalone** - only needs cortical ID and voxel coordinates!

