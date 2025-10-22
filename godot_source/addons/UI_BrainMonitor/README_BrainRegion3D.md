# Brain Region 3D Visualization

## Overview

This feature introduces 3D visualization of FEAGI Brain Regions as composite 3D objects in the brain monitor. Brain regions are represented as semi-transparent red plates with input and output cortical areas positioned on top.

## Key Features

### 🏗️ **3D Plate Component**
- **File**: `UI_BrainMonitor_BrainRegion3D.gd`
- **Purpose**: Reusable 3D component for visualizing brain regions
- **Design**: Semi-transparent red XZ plane with input/output cortical areas positioned on top
- **Sizing**: Automatically calculated from I/O cortical area dimensions with padding
- **Material**: Semi-transparent red material that sits underneath cortical areas

### 🧠 **Region-Based Scene Management**  
- **Modification**: Updated `UI_BrainMonitor_3DScene.gd`
- **Root Region Areas**: Shows cortical areas directly in root region at normal 3D positions
- **Child Region Areas**: Hidden from main 3D space (no duplicate display)
- **Child Regions**: Displayed as interactive semi-transparent red plates
- **I/O Areas**: Child region input/output areas positioned on top of plates

### 🔄 **Dynamic Updates**
- Responds to brain region changes in real-time
- Handles cortical area additions/removals  
- Updates frame contents automatically

### 📍 **FEAGI Coordinate Integration**
- **Positioning**: Uses brain region's `coordinates_3D` property
- **Conversion**: Proper FEAGI-to-Godot coordinate transformation
- **Z-Axis Flip**: Converts FEAGI Z-axis to Godot coordinate system
- **Center Offset**: Adjusts from FEAGI lower-front-left to Godot center positioning

## Architecture

```
UI_BrainMonitor_3DScene
├── Direct Cortical Areas (from root region)
│   └── UI_BrainMonitor_CorticalArea (normal rendering)
└── Child Brain Regions  
    └── UI_BrainMonitor_BrainRegion3D (3D frame)
        ├── Input Container (left side)
        │   └── Input Cortical Areas (scaled down)
        └── Output Container (right side)
            └── Output Cortical Areas (scaled down)
```

## Display Logic

### Cortical Area Visibility Rules

1. **Root Region Areas**: 
   - Show in normal 3D positions
   - Use full FEAGI coordinates
   - Standard scaling and rendering

2. **Child Region Areas**:
   - Hidden from main 3D space to avoid duplication
   - Only I/O areas are shown (inside wireframe cubes)
   - Non-I/O areas are completely hidden

3. **Wireframe Cube Contents**:
   - Only input/output cortical areas of the child region
   - Scaled down (0.7x) for inside-cube display
   - Positioned: inputs on left, outputs on right

### Input/Output Classification

The system determines input and output cortical areas using:

1. **Connection Chain Links** (Primary method):
   - `input_open_chain_links`: Areas that are destinations of input links
   - `output_open_chain_links`: Areas that are sources of output links
   - **Note**: These areas can be located anywhere in the brain region hierarchy

2. **Cortical Area Types** (Secondary method):
   - `IPU` (Input Processing Unit): Treated as input (if directly contained in brain region)
   - `OPU` (Output Processing Unit): Treated as output (if directly contained in brain region)

3. **Non-IO Areas**: Not visualized at the wireframe cube level (CORE, MEMORY, CUSTOM, etc.)

### Key Fixes Applied

#### Fix 1: I/O Area Detection Logic
- **Previous Issue**: Only showed I/O areas that were directly contained within the brain region
- **Current Fix**: Shows I/O areas referenced by connection links regardless of their location
- **Result**: I/O areas from parent regions that serve as interfaces are now properly displayed

#### Fix 2: Competing Display Logic Resolution
- **Previous Issue**: 3D scene was blocking creation of I/O area visualizations, preventing brain regions from displaying them
- **Current Fix**: 3D scene now creates visualizations for I/O areas of child regions, then brain region wireframes move them inside cubes
- **Architecture**: 
  - 3D scene creates all cortical area visualizations (including I/O areas)
  - Brain region components retrieve existing visualizations via `get_cortical_area_visualization()`
  - Visualizations are moved from main 3D space into wireframe cube containers
  - Inside cubes: scaled to 0.7x, positioned left (inputs) and right (outputs)

#### Fix 3: Missing Child Region Area Iteration  
- **Previous Issue**: Only iterating through root region's cortical areas, missing I/O areas in child regions (e.g., c__rig, c__lef)
- **Current Fix**: Added explicit iteration through child region cortical areas with targeted I/O detection
- **Implementation**: 
  - Process root region areas first (normal display rules)
  - Then iterate through each child region's `contained_cortical_areas`
  - Use `_is_area_input_output_of_specific_child_region()` for targeted I/O detection
  - Create visualizations for detected I/O areas to be moved into wireframe cubes

#### Fix 4: Missing Connection Chain Links (API Data Compatibility)
- **Previous Issue**: API data uses direct `inputs`/`outputs` arrays but system expects `input_open_chain_links`/`output_open_chain_links`
- **Current Fix**: Added robust fallback detection methods when chain links are missing
- **Fallback Strategy**:
  1. **Primary**: Check `input_open_chain_links` and `output_open_chain_links` (when available)
  2. **Secondary**: Check for IPU/OPU cortical area types directly
  3. **Tertiary**: Use intelligent naming heuristics for 2-area regions:
     - Input detection: "rig", "right", "input", "in", "inp" patterns (matches `c__rig`)
     - Output detection: "lef", "left", "output", "out" patterns (matches `c__lef`)

#### Fix 5: Cortical Area Scaling and Positioning
- **Previous Issue**: Attempted to set `scale` and `position` on renderer `Node` objects instead of their 3D children
- **Architecture Understanding**: 
  - `UI_BrainMonitor_CorticalArea` (Node) → Contains renderer children
  - `UI_BrainMonitor_DDACorticalAreaRenderer` (Node) → Contains `_static_body` (StaticBody3D) + `_friendly_name_label` (Label3D)
  - `UI_BrainMonitor_DirectPointsCorticalAreaRenderer` (Node) → Contains `_static_body` (StaticBody3D)
- **Current Fix**: Scale and position the actual 3D objects (`_static_body`, `_friendly_name_label`) 
- **Implementation**:
  - `_scale_cortical_area_visualization()`: Scales `_static_body` and labels within both renderer types
  - `_position_cortical_area_in_container()`: Positions 3D objects at Y-offsets within wireframe cube
  - **Inside-cube scaling**: 0.7x scale factor for compact display with label offset

## Usage

### Basic Setup
```gdscript
# Set up 3D scene for a brain region
var brain_monitor = UI_BrainMonitor_3DScene.new()
brain_monitor.setup(root_brain_region)
```

### Coordinate System
Brain regions are positioned using FEAGI's 3D coordinate system:
```gdscript
# Brain region positioning is automatic
var region = brain_region_from_feagi  # Has coordinates_3D: Vector3i(10, 20, 5)
var region_frame = UI_BrainMonitor_BrainRegion3D.new()
region_frame.setup(region)  # Automatically positions at correct 3D location

# Manual positioning (for testing)
region_frame._update_position(Vector3i(10, 20, 5))  # FEAGI coords -> Godot position
```

### Display Logic Example
```gdscript
# Root region setup
var root_region = get_root_brain_region()
var brain_monitor = UI_BrainMonitor_3DScene.new()
brain_monitor.setup(root_region)

# Result:
# ✅ Root region cortical areas shown in normal 3D positions
# 🔴 Child region "motor_cortex" appears as red wireframe cube
#    └── Contains input IPU areas on left side
#    └── Contains output OPU areas on right side  
# ❌ Child region internal CORE areas hidden (not I/O)
```

### Creating Brain Region Frame
```gdscript
# Create individual brain region frame
var region_frame = UI_BrainMonitor_BrainRegion3D.new()
add_child(region_frame)
region_frame.setup(brain_region)

# Connect interaction signals
region_frame.region_double_clicked.connect(_on_region_double_clicked)
region_frame.region_hover_changed.connect(_on_region_hover_changed)
```

## Visual Design

### Frame Structure
- **Design**: Custom ArrayMesh with LINE primitive topology (12 edges connecting 8 vertices)
- **Material**: Red line material with hover effects (normal: rgb(1.0,0.0,0.0), hover: rgb(1.0,0.5,0.0))
- **Layout**: Vertical split (input left, output right)
- **Spacing**: Automatic positioning with configurable spacing
- **Z-Level**: All cortical areas flush at region Z coordinate
- **Rendering**: Custom line geometry ensuring all cube edges are visible

### Interaction
- **Hover**: Frame highlights in bright orange
- **Click**: Selects the brain region 
- **Double-Click**: Ready for future navigation/diving functionality

## Integration Points

### Circuit Builder Compatibility  
- Follows same logic as circuit builder (root region cortical areas only)
- Child regions represented as nodes/frames consistently

### Existing 3D Components
- Reuses `UI_BrainMonitor_CorticalArea` for cortical area rendering
- Compatible with existing interaction and selection systems
- Maintains neuron selection and firing capabilities

## Future Enhancements

### 📑 **Tab System**
- Navigate between brain regions  
- Dive into child regions
- Breadcrumb navigation

### 🎨 **Visual Improvements**
- Custom materials per region type
- Connection visualization between frames
- Animated transitions

### ⚙️ **Configuration**
- User-adjustable frame sizes
- Customizable spacing and layout
- Theme support

## Files Modified/Created

### New Files
- `UI_BrainMonitor_BrainRegion3D.gd` - Main 3D frame component
- `test_brain_region_3d.gd` - Test and demonstration script
- `README_BrainRegion3D.md` - This documentation

### Modified Files  
- `UI_BrainMonitor_3DScene.gd` - Added brain region frame support

## Testing

Run the test script to see the feature in action:
```gdscript
var test = TestBrainRegion3D.new()
add_child(test)
```

The test demonstrates:
- Input/output area classification
- 3D frame creation and setup
- Interaction handling
- Integration with existing systems

## Technical Notes

### Performance
- Uses single ArrayMesh with LINE primitive (24 vertices, 12 lines)
- Extremely lightweight - single line mesh per brain region
- Scales cortical areas down (0.7x) in frames  
- Minimal overhead for frame management
- Custom line geometry optimized for consistent wireframe display

### Modularity
- Self-contained component design
- Clean separation of concerns
- Easy to extend and maintain
- Frame container (`_frame_container: MeshInstance3D`) holds custom line-based wireframe mesh

### Coordinate Conversion
- **FEAGI Origin**: Lower-front-left corner (0,0,0)
- **Godot Origin**: Object center
- **Z-Axis**: Flipped between coordinate systems (FEAGI Z = -Godot Z)
- **Formula**: `godot_pos = Vector3(feagi_pos.x, feagi_pos.y, -feagi_pos.z) + center_offset`
- **Dynamic**: Position recalculated when frame size changes

### Thread Safety
- All operations on main thread
- Signal-based communication
- No shared state issues
