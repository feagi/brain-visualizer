# Brain Region 3D Visualization

## Overview

This feature introduces 3D visualization of FEAGI Brain Regions as composite 3D objects in the brain monitor. Brain regions are represented as 3D frames with vertical splits showing input and output cortical areas.

## Key Features

### 🏗️ **3D Frame Component**
- **File**: `UI_BrainMonitor_BrainRegion3D.gd`
- **Purpose**: Reusable 3D component for visualizing brain regions
- **Design**: Single red wireframe cube with vertical split - input areas on left, output areas on right
- **Material**: Red wireframe material showing only cube edges, completely hollow interior

### 🧠 **Region-Based Scene Management**  
- **Modification**: Updated `UI_BrainMonitor_3DScene.gd`
- **Behavior**: Shows only cortical areas directly in root region
- **Child Regions**: Displayed as interactive 3D frames

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

## Input/Output Classification

The system determines input and output cortical areas using:

1. **Connection Chain Links**:
   - `input_open_chain_links`: Areas receiving input
   - `output_open_chain_links`: Areas providing output

2. **Cortical Area Types**:
   - `IPU` (Input Processing Unit): Treated as input
   - `OPU` (Output Processing Unit): Treated as output

3. **Non-IO Areas**: Not visualized at the frame level (CORE, MEMORY, CUSTOM, etc.)

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
