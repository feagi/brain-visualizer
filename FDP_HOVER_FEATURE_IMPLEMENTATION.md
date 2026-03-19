# FDP Hover Feature Implementation Summary

## Overview
Extended the brain visualizer's cortical area hover feature to display decoded information for IPU and OPU cortical areas. Uses **feagi-sensorimotor** single-voxel decode API so that what BV displays matches what a robot/controller would process.

## Implementation Details

### 1. feagi-sensorimotor Single-Voxel Decode API
**File**: `feagi-core/crates/feagi-sensorimotor/src/single_voxel_decode.rs`

Public API that uses the same `coder_shared_functions` as feagi-sensorimotor's batch decoders:
- `decode_single_voxel(cortical_id, voxel_x, voxel_y, voxel_z, channel_dims, device_count) -> SingleVoxelDecodeResult`
- Supports: Percentage, SignedPercentage (1D-4D), CartesianPlane, Misc, Boolean
- Linear: `value = 1.0 - (z/z_max)` (z=0 is max)
- Exponential: `value = sum(0.5^z)` for active neurons

### 2. Rust GDExtension Functions (`feagi_data_deserializer`)
**File**: `brain-visualizer/rust_extensions/feagi_data_deserializer/src/lib.rs`

#### A. `parse_cortical_id_encoding()` - Binary Cortical ID Parser
- Decodes base64 cortical IDs to 8-byte binary format
- Returns encoding_type, encoding_format, is_signed for UI/legacy use

#### B. `decode_fdp_value()` - Delegates to feagi-sensorimotor
- Calls `feagi_sensorimotor::single_voxel_decode::decode_single_voxel`
- Cortical ID carries encoding; no need to pass encoding_type/format
- Returns: `{success: bool, channel: int, value: float, data_type: string, error: string}`

**Key Features**:
- Uses feagi-sensorimotor's actual decoding logic (no duplicated formulas)
- BV display matches robot processing

### 3. GDScript Integration
**File**: `brain-visualizer/godot_source/addons/UI_BrainMonitor/UI_BrainMonitor_Overlay.gd`

Modified `mouse_over_single_cortical_area()` to:
- Call `_get_decoded_value_suffix()` for both IPU and OPU cortical areas
- Uses `decode_fdp_value()` which delegates to feagi-sensorimotor
- Display format: `| value: X.X% (DataType)`

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
- **Implemented**: IPU and OPU cortical areas
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

