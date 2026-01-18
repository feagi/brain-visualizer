# Circuit Builder

The Circuit Builder is a 2D node-based graph editor that provides a high-level view of your neural circuits. It's your primary tool for organizing, connecting, and understanding the structure of your genome.

## Overview

Circuit Builder displays cortical areas as colored boxes and their connections as lines. Each box represents a volume of neurons, and you can create, move, connect, and organize these boxes to build complex neural architectures.

## Interface Elements

### Cortical Area Nodes

Cortical areas appear as rectangular boxes with:
- **Title**: The name of the cortical area
- **Color**: Indicates the type (Input, Output, Memory, Custom, Core)
- **Ports**: Connection points for linking to other areas
  - Top port: Recursive connections (to itself)
  - Left port: Incoming connections (inputs)
  - Right port: Outgoing connections (outputs)

### Brain Region Nodes

Sub-regions appear as larger boxes that can contain cortical areas and other sub-regions. Double-click a region to navigate inside it and view its contents.

### Connection Lines

Lines between nodes represent neural mappings:
- Click on a line to view or edit mapping properties
- Multiple lines between the same areas indicate different mapping types
- Line color and style indicate connection properties

## Basic Operations

### Creating Cortical Areas

**Quick Method:**
1. Click **Inputs**, **Circuits**, or **Outputs** in the top toolbar
2. Click the **+** button
3. Configure the area properties
4. Click **Add**

**From Circuit Builder:**
1. Right-click empty space
2. Select **Create Cortical Area**
3. Choose the type and configure

### Connecting Cortical Areas

**Method 1: Drag Connection**
1. Click and drag from the output port (right side) of one area
2. Drag to the input port (left side) of another area
3. Release to open the Mapping Editor

**Method 2: Quick Connect**
1. Right-click a cortical area
2. Select **Quick Connect** from the menu
3. Choose the destination area
4. Configure the mapping

See [Mapping Connections](mapping_connections.md) for more details.

### Moving Objects

**Single Object:**
- Click and drag a cortical area or region to move it
- Position changes are automatically saved to FEAGI after a short delay

**Multiple Objects:**
1. Select multiple objects (Ctrl + Click)
2. Drag any selected object
3. All selected objects move together

**Precise Positioning:**
1. Right-click an object
2. Select **Relocate 2D**
3. Enter exact coordinates

### Selecting Objects

- **Single select**: Click on an object
- **Multi-select**: Ctrl + Click to add/remove from selection
- **Box select**: Click and drag in empty space (if enabled)
- **Clear selection**: Click on empty space

## Navigation

### Pan (Move the View)
- **Middle mouse drag**: Click and hold middle mouse button while moving
- **Shift + Left mouse drag**: Hold Shift, then click and drag with left mouse
- **Keyboard**: Arrow keys to move in that direction

### Zoom
- **Mouse wheel**: Scroll up to zoom in, down to zoom out
- **Keyboard**: Page Up/Down keys
- **Zoom to fit**: Right-click empty space, select "Fit All"

### Focus on Object
1. Select a cortical area or region
2. Press **F** key
   
OR

1. Click **Inputs/Circuits/Outputs** in top bar
2. Select an area from the dropdown
3. The view automatically focuses on it

## Working with Regions

### Viewing Region Contents

**Method 1: Double-click**
- Double-click a brain region node to open it

**Method 2: Dropdown Menu**
- Click **Circuits** in the top toolbar
- Select a region from the list
- A new tab opens showing that region's contents

### Creating Regions

1. Select cortical areas you want to group (optional)
2. Right-click in Circuit Builder
3. Select **Create Region**
4. Enter a name and properties
5. Click **Create**

Selected areas will automatically be added to the new region.

### Moving Areas Between Regions

1. Right-click a cortical area
2. Select **Add to Region**
3. Choose the destination region
4. Confirm

See [Brain Regions](brain_regions.md) for more details.

## Circuit Builder Tabs

You can open multiple Circuit Builder tabs to view different regions simultaneously:

1. Right-click a region node
2. Select **Open in New Tab** (if available)

OR

1. Use the **Circuits** dropdown in the top bar
2. Each selection opens a new tab

Switch between tabs using the tab bar at the top of the Circuit Builder area.

## Layout and Organization

### Auto-Layout

Circuit Builder provides automatic layout algorithms (accessed via developer options):

- **Column Layout**: Arranges areas in vertical columns
- **Row Layout**: Arranges areas in horizontal rows
- **Hierarchical Layout**: Organizes based on connection flow

### Manual Organization

For best results:
1. **Group by Function**: Keep related cortical areas close together
2. **Flow Direction**: Arrange inputs on the left, outputs on the right
3. **Use Regions**: Group areas into logical regions
4. **Spacing**: Leave room for connections to be visible

## Context Menu (Right-Click)

Right-clicking in Circuit Builder provides different options based on what you click:

**On a Cortical Area:**
- Details - View/edit properties
- Quick Connect - Create connection
- Clone - Duplicate area
- Relocate 2D - Set position
- Move 3D - Position in 3D space
- Add to Region - Move to different region
- Reset - Clear neural state
- Delete - Remove area

**On a Region:**
- Details - View/edit properties
- Open 3D Tab - Open in Brain Monitor
- Clone - Duplicate entire region
- Add to Region - Nest in another region
- Delete - Remove region

**On Empty Space:**
- Create Cortical Area
- Create Region
- Fit All - Zoom to show everything
- Layout Options (if available)

See [Quick Menu](quick_menu.md) for complete details.

## Advanced Features

### Connection Visualization

- **Hover over area**: See all connections to/from that area highlighted
- **Click connection line**: View mapping properties
- **Follow connections**: Visual indicators show data flow direction

### Recursive Connections

Some cortical areas can connect to themselves:
1. Drag from the top port (recursive port)
2. Connect back to the same area's input port
3. Useful for feedback loops and temporal processing

### Multi-Selection Operations

Select multiple areas to perform bulk operations:
- Move them together
- Delete multiple areas at once
- View combined properties
- Add all to a region at once

## Keyboard Shortcuts

- **Arrow Keys**: Pan view
- **Page Up/Down**: Zoom in/out
- **F**: Focus on selected object
- **Delete**: Delete selected objects (with confirmation)
- **Ctrl + C**: Copy selected objects
- **Ctrl + V**: Paste objects
- **Ctrl + Z**: Undo last operation
- **Ctrl + A**: Select all in current view

## Tips for Effective Circuit Building

1. **Start with I/O**: Create your inputs and outputs first, then connect them
2. **Use Meaningful Names**: Name areas based on their function
3. **Group Logically**: Use regions to organize related functionality
4. **Watch the Connections**: Too many connections can indicate complexity
5. **Test Incrementally**: Build and test small circuits before expanding
6. **Use Colors**: The color coding helps you quickly identify area types
7. **Keep it Clean**: Regularly reorganize and clean up your circuit layout
8. **Document**: Use region names and descriptions to document your architecture

## Integration with Brain Monitor

Circuit Builder and Brain Monitor are tightly integrated:

- **Selection Sync**: Selecting in one view highlights in the other
- **Focus Sync**: Focusing on an area in one view focuses in the other
- **Split View**: View both simultaneously for best workflow

Use [Split View](split_view.md) to work with both views at once.

## Common Workflows

### Creating a Simple Circuit

1. Create an input cortical area (IPU)
2. Create a processing area (Custom)
3. Create an output cortical area (OPU)
4. Connect Input → Processing → Output
5. Test with data flowing through FEAGI

### Organizing Complex Circuits

1. Identify functional groups (e.g., "Vision", "Motor", "Memory")
2. Create regions for each group
3. Move cortical areas into appropriate regions
4. Create inter-region connections as needed
5. Name and document each region

### Refactoring Circuits

1. Review current organization in Circuit Builder
2. Identify areas that should be grouped
3. Create or modify regions
4. Move areas to new locations
5. Verify connections remain intact
6. Test neural activity

## Troubleshooting

**"Can't see my cortical areas"**
- Use Fit All (right-click → Fit All) to zoom out
- Check if you're viewing the correct region
- Verify areas exist in FEAGI

**"Connections won't create"**
- Ensure you're dragging from output port to input port
- Verify both areas exist in FEAGI
- Check that areas are compatible for connection

**"Objects move slowly or lag"**
- This is normal - position updates are batched and sent to FEAGI
- Wait a few seconds for the update to complete

**"Lost my place after double-clicking"**
- Use the Circuits dropdown to navigate back
- Use browser-style back button (if available)
- Click parent region to go up one level

## Related Topics

- [Brain Regions](brain_regions.md) - Organizing circuits into hierarchies
- [Cortical Areas](cortical_areas.md) - Creating and managing areas
- [Mapping Connections](mapping_connections.md) - Connecting areas together
- [Brain Monitor](brain_monitor.md) - 3D visualization companion
- [Navigation Basics](navigation.md) - Movement and camera controls
- [Split View](split_view.md) - Side-by-side workflow

[Back to Overview](index.md)
