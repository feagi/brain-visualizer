# Navigation Basics

Brain Visualizer provides multiple ways to navigate through your genome in both 2D and 3D views. This guide covers the fundamentals of moving around and finding what you need.

## Navigation Philosophy

Brain Visualizer uses two complementary views:
- **Circuit Builder (2D)**: Top-down graph view for structure and connections
- **Brain Monitor (3D)**: Spatial view for visualization and activity

Each has its own navigation system optimized for its purpose.

## Quick Navigation Methods

### Direct Navigation (Fastest)

Use the **top toolbar dropdowns** to jump directly to any object:

**Inputs Dropdown:**
1. Click **Inputs** in top toolbar
2. Select an IPU area from the list
3. View instantly focuses on that area

**Circuits Dropdown:**
1. Click **Circuits** in top toolbar
2. Select a brain circuit from the list
3. Opens Circuit Builder tab for that region

**Outputs Dropdown:**
1. Click **Outputs** in top toolbar
2. Select an OPU area from the list
3. View instantly focuses on that area

This method works from anywhere and is the fastest way to navigate.

### Focus Navigation

Jump to selected objects:

**Method 1 - Keyboard:**
1. Click to select any cortical area or region
2. Press **F** key
3. Camera focuses on object in both 2D and 3D

**Method 2 - Menu:**
1. Right-click object
2. Select **Focus** (if available)

**Method 3 - Dropdown Selection:**
- Selecting from dropdowns automatically focuses

### Manual Navigation

Pan, zoom, and rotate for exploration:

**In Circuit Builder (2D):**
- **Pan**: Middle-drag or Shift+Left-drag
- **Zoom**: Mouse wheel
- **Reset**: Fit All (right-click → Fit All)

**In Brain Monitor (3D):**
- **Rotate**: Left-drag to orbit
- **Pan**: Middle-drag or Shift+Left-drag
- **Zoom**: Mouse wheel or Right-drag
- **Reset**: Home key

See [Camera Controls](camera_controls.md) for complete details.

## Finding Objects

### Using Search (if available)

Some versions include a search feature:
1. Open search bar (Ctrl+F or search icon)
2. Type cortical area or region name
3. Select from results
4. View focuses on selection

### Using Lists

Browse organized lists in dropdowns:
- **Inputs**: All IPU areas alphabetically
- **Circuits**: All regions in hierarchy
- **Outputs**: All OPU areas alphabetically

Click any item to navigate there.

### Using Hierarchy

Navigate through region hierarchy:
1. Start at Main Circuit
2. Double-click regions to enter them
3. View contents
4. Navigate up/down through structure

## Selection Techniques

### Single Selection

**In Circuit Builder:**
- **Click** on cortical area node
- Selected object highlights
- Properties become available

**In Brain Monitor:**
- **Click** on cortical volume
- Selected object highlights
- Both views sync

### Multi-Selection

**Add to Selection:**
- **Ctrl + Click** to add/remove objects
- Works in both 2D and 3D
- Useful for bulk operations

**Box Selection:**
- Click and drag in empty space (if enabled)
- All objects in box are selected

### Clear Selection

- Click empty space
- Press **Escape** key
- Select different object

## Cross-View Navigation

Selections and focus sync between views:

**Example Workflow:**
1. Click cortical area in Circuit Builder
2. It highlights in Brain Monitor too
3. Press F to focus
4. Both views frame the object

This tight integration helps you understand both structure and spatial layout.

## Navigation by Context

### Viewing Connections

To see what's connected to an area:

**In Circuit Builder:**
1. Click cortical area
2. Connection lines highlight
3. Follow lines to connected areas

**In Brain Monitor:**
1. Hover over cortical volume
2. Connection lines appear
3. See spatial relationships

### Following Data Flow

Trace information path:
1. Start at Input (IPU)
2. Note outgoing connections
3. Navigate to connected processing areas
4. Continue to Output (OPU)

Understanding flow helps navigate purposefully.

### Exploring Regions

Navigate hierarchically:
1. View Main Circuit (top level)
2. Identify major regions
3. Double-click or use dropdown to enter
4. Explore contents
5. Return to parent as needed

## Navigation Tips

### In Circuit Builder (2D)

**Finding Lost Objects:**
- Right-click → Fit All to see everything
- Use dropdowns to jump directly
- Check you're in the correct region

**Organizing for Navigation:**
- Group related areas close together
- Use regions to organize hierarchically
- Name areas descriptively

**Quick Operations:**
- Focus (F key) after selection
- Dropdowns for long-distance jumps
- Tabs to keep multiple views open

### In Brain Monitor (3D)

**Getting Oriented:**
- Click areas to focus automatically
- Use rotation to see from different angles
- Zoom out for overview, in for details

**Understanding Spatial Layout:**
- Hover to see connections
- Notice which areas are close together
- Look for organizational patterns

**Efficient Movement:**
- Click-to-focus is fastest
- Orbit after focusing for different angles
- Save camera positions for important views

## Using Split View

Work with both views simultaneously:

**Benefits:**
- See 2D topology and 3D space together
- Edit structure while watching activity
- Understand both perspectives at once

**Setup:**
1. Right-click region → **Open 3D Tab**
2. Circuit Builder (left/top) + Brain Monitor (right/bottom)
3. Navigate independently or sync via selection

See [Split View](split_view.md) for more details.

## Navigation Shortcuts

### Essential Shortcuts

- **F**: Focus on selected object
- **Home**: Reset view / Fit All
- **Arrow Keys**: Pan (2D) or Rotate (3D)
- **Page Up/Down**: Zoom in/out
- **Escape**: Clear selection

### Mouse Shortcuts

- **Left Click**: Select object
- **Left Drag**: Rotate (3D) or Move object (2D)
- **Middle Drag**: Pan view
- **Wheel**: Zoom in/out
- **Ctrl + Click**: Multi-select

See [Keyboard Shortcuts](keyboard_shortcuts.md) for complete list.

## Advanced Navigation

### Camera Animations

Save and replay camera paths:

1. Position camera at interesting views
2. Record waypoints
3. Play back for presentations or demos
4. Quick return to saved positions

See [Camera Animations](camera_animations.md) for details.

### Tab Management

Work on multiple areas simultaneously:

**Circuit Builder Tabs:**
- Open multiple regions in separate tabs
- Switch tabs to jump between views
- Independent navigation per tab

**Brain Monitor Tabs:**
- Dedicated 3D view per region
- Better performance
- Focused work environment

### Custom Views

Configure views for specific tasks:

**Developer Mode:**
- Additional camera controls
- Advanced visualization options
- Grid and overlay options

Access via **Options** → **Display** or **Developer Options**.

## Navigation Strategies

### For Small Genomes (< 20 areas)

- Fit All usually shows everything
- Direct manual navigation works well
- Minimal region organization needed

### For Medium Genomes (20-100 areas)

- Use regions to organize
- Combine manual and dropdown navigation
- Split view for efficiency

### For Large Genomes (100+ areas)

- Heavy use of regions and hierarchy
- Primarily dropdown navigation
- Region-specific tabs
- Camera animations for presentations

## Troubleshooting

**"I'm lost and can't find anything"**
- Press Home or Fit All
- Use Circuits dropdown to go to Main Circuit
- Close all tabs and start over

**"Object isn't where I expected"**
- Check which region it's in (use dropdowns)
- Verify you're viewing correct region
- Use global search if available

**"Navigation is too slow"**
- Use dropdowns instead of manual panning
- Learn and use keyboard shortcuts
- Increase camera speed in Options

**"Can't see connections"**
- Zoom out for overview
- Hover over areas to highlight connections
- Use Circuit Builder for clearer topology

**"Lost track of what I was looking at"**
- Use browser-style back button (if available)
- Maintain organization (descriptive names)
- Use camera animations to save positions

## Best Practices

1. **Learn Keyboard Shortcuts**: Much faster than mouse-only
2. **Use Dropdowns for Long Distances**: Don't manually pan across large circuits
3. **Name Objects Clearly**: Makes navigation via dropdowns much easier
4. **Organize with Regions**: Essential for large genomes
5. **Use Split View**: Best for understanding structure + activity
6. **Save Important Views**: Camera animations preserve your work
7. **Practice**: Navigation becomes intuitive with use

## Related Topics

- [Camera Controls](camera_controls.md) - Detailed camera operations
- [Camera Animations](camera_animations.md) - Saving and playing camera paths
- [Split View](split_view.md) - Working with multiple views
- [Circuit Builder](circuit_builder.md) - 2D navigation and editing
- [Brain Monitor](brain_monitor.md) - 3D visualization and navigation
- [Keyboard Shortcuts](keyboard_shortcuts.md) - Complete shortcut reference

[Back to Overview](index.md)
