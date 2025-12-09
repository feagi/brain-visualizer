# Neuron Position Offset Fix for All Cortical Areas

## Issue Description

**Problem**: Neuron firing activations were appearing with a 0.5-unit offset from their correct positions within cortical areas. This affected all cortical area sizes.

**Symptoms**:
- Neurons appeared shifted by approximately 0.5 units in X, Y, and Z
- For example, neuron (0,0,0) appeared 0.5 units inward from the corner
- The offset was most noticeable in larger cortical areas (e.g., 16x16x3, 128x128x3)
- Caused misalignment between expected and actual neuron positions

## Root Cause

The bug was in the Rust neuron visualization processor at:
`brain-visualizer/rust_extensions/feagi_data_deserializer/src/lib.rs`

An incorrect offset was being added to all neuron positions:

```rust
// ❌ BEFORE (INCORRECT):
let offset = Vector3::new(0.5, 0.5, 0.5);  // Wrong!
let centered_pos = Vector3::new(
    feagi_pos.x - half_dimensions.x + offset.x,  // Adds 0.5
    feagi_pos.y - half_dimensions.y + offset.y,  // Adds 0.5
    feagi_pos.z - half_dimensions.z + offset.z,  // Adds 0.5
);
```

### Why This Was Wrong

The 0.5 offset was being added to all neuron positions, causing them to shift inward from their correct locations.

**Example with 16x16x3 cortical area:**
- StaticBody position (center): (28.0, 38.0, 18.5)
- StaticBody scale: (16.0, 16.0, 3.0)
- Neuron (0,0,0) with offset:
  - `centered_pos = (0,0,0) - (8,8,1.5) + (0.5,0.5,0.5) = (-7.5, -7.5, -1.0)`
  - After scaling and parent transform: **0.5 unit offset from corner**

The offset was originally intended to center each voxel cube, but FEAGI coordinates already represent the neuron position correctly. The corner coordinate (0,0,0) should map exactly to the cortical area's corner, not 0.5 units inward.

## The Fix

Remove the incorrect 0.5 offset from neuron position calculations.

```rust
// ✅ AFTER (CORRECT):
let offset = Vector3::ZERO;  // No offset needed
let centered_pos = Vector3::new(
    feagi_pos.x - half_dimensions.x,  // No offset
    feagi_pos.y - half_dimensions.y,  // No offset
    feagi_pos.z - half_dimensions.z,  // No offset
);
```

### What This Achieves

1. **Neuron (0,0,0) maps to the exact corner** of the cortical area
2. **All neuron positions are accurate** relative to the cortical area bounds
3. **Works correctly for all cortical area sizes** (1x1x1, 16x16x3, 128x128x3, etc.)

## Technical Details

### Transform Matrix Structure

A 3D transform in Godot is represented as a 3x4 matrix:
```
[basis_x.x, basis_y.x, basis_z.x, origin.x]
[basis_x.y, basis_y.y, basis_z.y, origin.y]
[basis_x.z, basis_y.z, basis_z.z, origin.z]
```

- **Basis columns (0-2)**: Define the local coordinate axes and scale
- **Origin column (3)**: Defines the position in parent space

### Coordinate System Explanation

**FEAGI Space:**
- Position (20, 30, -20) represents the **lower-left-front corner** of a cortical area
- Neuron (0,0,0) is at this corner
- Neuron (15,15,2) is at the opposite corner for a 16x16x3 area

**Godot World Space:**
- StaticBody3D.position is the **center** of the cortical area
- For FEAGI (20, 30, -20) with dimensions (16, 16, 3):
  - Z-flip: (20, 30, 20)
  - Add half dimensions: (20, 30, 20) + (8, 8, -1.5) = (28, 38, 18.5) ← center

**MultiMesh Local Space (child of StaticBody3D):**
- Neuron transforms are relative to the StaticBody3D center
- Neuron (0,0,0) should be at local position (-8, -8, 1.5) before parent scale
- After parent scale (16, 16, 3): (-8, -8, 1.5) × scale becomes (-0.5, -0.5, 0.5) in local
- This places it at world position (28, 38, 18.5) + parent_scale × local = corner

The key insight: **No offset should be added** - the math already correctly positions neurons.

## Files Modified

1. `/Users/nadji/code/FEAGI-2.0/brain-visualizer/rust_extensions/feagi_data_deserializer/src/lib.rs`
   - Modified `apply_arrays_to_multimesh()` function
   - Modified `process_neuron_visualization()` function
   - Modified `process_arrays_for_visualization()` function
   - Changed `offset = Vector3::new(0.5, 0.5, 0.5)` to `offset = Vector3::ZERO` in all three locations

## Testing

After applying this fix and rebuilding:

```bash
cd brain-visualizer/rust_extensions/feagi_data_deserializer
./build.sh
```

Test with cortical areas of various sizes:
- ✅ 1x1x1: Neurons positioned correctly
- ✅ 16x16x3: Now fixed (had 0.5 unit offset)
- ✅ 128x128x3: Now fixed (had 0.5 unit offset)
- ✅ Any size: Should work correctly

## Related Code

### Godot Renderer
`brain-visualizer/godot_source/addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/UI_BrainMonitor_DirectPointsCorticalAreaRenderer.gd`

Line 456-462: Calls the Rust processor
```gdscript
var result = _rust_processor.apply_arrays_to_multimesh(
    _multi_mesh,
    x_array,
    y_array,
    z_array,
    _dimensions  # Vector3(5, 5, 5) for 5x5x5 area
)
```

### Scene Hierarchy
```
UI_BrainMonitor_CorticalArea
  └── UI_BrainMonitor_DirectPointsCorticalAreaRenderer
      └── StaticBody3D (_static_body)
          ├── position = _position_godot_space (e.g., Vector3(10, 20, -30))
          ├── scale = _dimensions (e.g., Vector3(5, 5, 5))
          └── MultiMeshInstance3D (_multi_mesh_instance)
              └── MultiMesh instances (neuron voxels)
                  ├── Each instance has a Transform3D
                  ├── Transform is relative to StaticBody3D
                  └── NOW CORRECTLY POSITIONED!
```

## Impact

This fix ensures that neuron firing activations are correctly visualized for cortical areas of ANY size, not just 1x1x1. This is critical for:
- Accurate brain visualization
- Debugging neural activity
- Understanding neural patterns in larger cortical areas
- Proper alignment with cortical area boundaries

## Date

Fixed: November 25, 2025

