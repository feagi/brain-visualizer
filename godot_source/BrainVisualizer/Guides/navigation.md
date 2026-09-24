# Navigation Basics

Brain Visualizer provides multiple ways to navigate through your genome in both 2D and 3D views. This guide covers the fundamentals of moving around and finding what you need.

## Navigation Philosophy

Brain Visualizer uses two complementary views:
- **Circuit Builder (2D)**: Top-down graph view for structure and connections
- **Brain Monitor (3D)**: Spatial view for visualization and activity

Each has its own navigation system optimized for its purpose.

## Quick Navigation Methods

### Direct Navigation (Fastest)

Use the **top bar lists** to jump directly to an object. Hover the title. The list opens. There is no separate list icon.

**Root scene top bar:**
1. Hover **Circuits**, **Inputs**, **Outputs**, or **Connectivity Rules**
2. Select an entry
3. A circuit, input, or output is shown in the current view. A connectivity rule opens the Connectivity Rules Manager on that rule.

**Circuit Builder and Brain Monitor tab bars:**
The bar is shown only while the pointer is on that tab.
1. Hover **Circuits**, **Interconnect Areas**, or **Memory Areas**
2. Select an entry
3. The current view moves to that object
4. A tab opened on the main circuit also lists Inputs and Outputs the same way

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

**Method 3 - Top bar list:**
- Hover a category title and select an entry. The current view focuses on it. Connectivity Rules is the exception: that selection opens the manager.

### Manual Navigation

Pan, zoom, and rotate for exploration:

**In Circuit Builder (2D):**
- **Pan**: Middle-drag or Shift+Left-drag
- **Zoom**: Mouse wheel
- **Reset**: Fit All (right-click → Fit All)

**In Brain Monitor (3D):**
- **Pan**: Left-drag
- **Rotate**: Right-drag
- **Zoom**: Mouse wheel
- **Box-select areas**: Shift+Left-drag a rectangle
- **Reset**: R (when the mouse is over that Brain Monitor viewport)

See [Camera Controls](camera_controls.md) for complete details.

## Finding Objects

### Using Search (if available)

Some versions include a search feature:
1. Open search bar (Ctrl+F or search icon)
2. Type cortical area or region name
3. Select from results
4. View focuses on selection

### Using Lists

Browse the hover lists:
- **Inputs** and **Outputs** on the root scene top bar, and on a tab opened on the main circuit: areas of that type, by name
- **Circuits** on the root scene top bar: every circuit under the main circuit, by name. On a tab bar, Circuits lists the circuits directly inside the open region.
- **Interconnect Areas** and **Memory Areas**: on Circuit Builder and Brain Monitor tab bars
- **Connectivity Rules** on the root scene top bar: the same rows as the manager's left list. Selecting one opens that rule in the manager.

Selecting a circuit or cortical area moves the current view to it. It does not open a new tab.

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
- **Ctrl + Click** toggles cortical areas in multi-selection and opens one shared multi-edit quick menu

### Multi-Selection

**Add to Selection:**
- **Ctrl + Click** to add/remove objects
- In 3D, applies to cortical areas (and uses the shared multi-edit quick menu)
- In 3D camera focus mode, use **Ctrl + 1/2/3 + Click** for plane-based focus
- Useful for bulk operations

**Box Selection (Brain Monitor):**
- **Shift + Left Drag** draws a rectangle in the 3D scene
- All cortical areas whose volumes intersect that rectangle are selected
- The box replaces the current area highlight set and opens the shared multi-edit quick menu
- Camera pan is paused while the box is being drawn
- A Shift+click that does not drag still toggles voxels (see below)
- **Escape** or moving the mouse out of the viewport cancels an in-progress box

**Arrange (multi-area quick menu):**
- Select at least 2 cortical areas in the same circuit. The quick menu shows **Arrange**
- Hover or click **Arrange** to open **Align** and **Distribute**. Each has **X**, **Y**, and **Z**
- **Align** moves every selected area so the chosen axis matches the lowest value in the selection. The other two axes stay put
- **Distribute** needs at least 3 areas. The outermost areas stay fixed, and the areas between them are spaced evenly on that axis. Spacing uses whole voxels, so neighboring gaps differ by at most one
- Reserved core areas cannot be arranged. If the selection mixes circuits, or includes a reserved core area, Arrange stays disabled
- The quick menu stays open after a successful arrange
- Arrange is one undo step

**Undo and redo:**
- **Ctrl+Z** (Cmd+Z on macOS) reverses the last saved step
- **Shift+Ctrl+Z** (Shift+Cmd+Z) applies that step again
- You can step backward through several changes, then forward again
- One step is one 3D drag, Arrange, Circuit Builder move, automatic layout, circuit position edit, area position edit, or area delete
- A text field keeps its own undo. Ctrl+Z there does not change the genome
- Ctrl+Z is ignored while a 3D move is still being dragged
- The history lasts for this genome session and clears when another genome loads

**Undoing an area delete:**
- The area is created again with its properties and its mappings in and out
- FEAGI assigns a new id. A memory area's replay target is created again from those mappings
- Learned synapse weights are not restored
- One multi-select delete is one step. Only the areas FEAGI deleted are in that step
- Custom areas, memory areas, and input/output areas can be restored. Input and output areas need their device type to still be available
- Circuit deletes, classifier deletes, core-area deletes, and interconnect deletes are not undone

### Clear Selection

- Click empty space
- Press **Escape** key (also cancels an in-progress box select)
- Select different object

## Voxel Selection and Clipboard (Brain Monitor)

Use these workflows in the 3D Brain Monitor to pick voxels, copy their coordinates, and reuse them for mapping or further selection.

### Select Voxels (Shift + Click)

1. Hold **Shift** while the mouse is over a Brain Monitor viewport
2. **Click** individual voxels inside a cortical area to toggle them on or off
3. Selected voxels stay highlighted until you clear them
4. Selections can span **multiple cortical areas**

This is additive selection: each Shift+click toggles that voxel without clearing others.

### Fire Selected Voxels

With voxels selected in a Brain Monitor viewport:

- **Space**: Stimulate the selection once
- **Shift + Space**: Stimulate the selection once per burst until you press **Space** again
- **Delete**: Clear all selected voxels (also stops continuous stimulation)

If Shift is still held from picking voxels, **Space** is treated as **Shift + Space** and starts continuous stimulation. Release Shift first for a single pulse. Press **Space** (with or without Shift) to stop continuous stimulation.

See [Brain Monitor](brain_monitor.md) for the full probing workflow.

### Voxel Selection Capture Panel

When you have **2 or more voxels** selected, a **Voxel Selection Capture** panel appears at the bottom-right of the view.

The panel shows:
- Total voxel count and number of source areas
- A live JSON preview grouped by cortical area
- **Copy JSON to clipboard** — copies the selection in a standard format for mapping workflows

You can also copy at any time with **Ctrl + C** (Cmd + C on macOS) while voxels are selected. This works even when the panel is hidden, as long as a text field is not focused.

You can hide the panel with **X**; it reappears when your selection changes.

### Record Fired Voxels (Area Firing Recorder)

Capture voxels that fire during live simulation instead of picking them manually:

1. **Ctrl + Click** (Cmd + Click on macOS) one or more cortical areas to multi-select them
2. The **Area Firing Recorder** panel opens at the bottom-right
3. Click **Start Recording** while FEAGI is running
4. Fired voxels accumulate for all monitored areas as activity arrives
5. Click **Stop + Copy** to stop recording and copy the captured voxels as JSON to the clipboard

The recorder deduplicates voxels per area while recording. Use **X** to hide the panel when not recording.

### Paste Voxels onto a Hovered Area (Ctrl + V)

Paste copied voxel JSON directly into the 3D scene:

1. Copy voxels using **Voxel Selection Capture** or **Area Firing Recorder** (or any compatible JSON on the clipboard)
2. Hover the target cortical area in Brain Monitor (aqua outline / bottom-left context label)
3. Press **Ctrl + V** (Cmd + V on macOS)

**Paste behavior:**
- All voxels from **every area** in the clipboard JSON are **unioned** (duplicates removed by coordinate)
- The combined set is **additively selected** in the hovered area — same as Shift+click (existing selections are kept)
- A notification confirms how many voxels were added

Paste only runs when the mouse is over a Brain Monitor viewport and a cortical area is under the cursor. It does not run while a text field has focus.

### Use Copied Voxels in Quick Connect Mapping

The same JSON format works in **Quick Connect Neuron** mapping workflows:

1. Open Quick Connect from a cortical area's quick menu
2. Use the **Paste** button on the source or destination side when prompted for voxel selection
3. Clipboard JSON from manual selection or firing capture is applied to the mapping step

See [Mapping Connections](mapping_connections.md) for full Quick Connect mapping details.

### Clipboard JSON Format (Reference)

Copied payloads share one schema. Example structure:

```json
{
  "area_count": 2,
  "total_voxel_count": 5,
  "by_cortical_id": {
    "area_id_1": [[x, y, z], [x, y, z]],
    "area_id_2": [[x, y, z]]
  },
  "areas": [
    {
      "cortical_id": "area_id_1",
      "friendly_name": "Visual Cortex",
      "voxel_count": 2,
      "voxels": [[x, y, z], [x, y, z]]
    }
  ]
}
```

Coordinates are local `(x, y, z)` positions within each cortical area.

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
3. Double-click a circuit, or hover **Circuits** and select it, to focus it
4. Explore contents
5. Return to parent as needed

## Navigation Tips

### In Circuit Builder (2D)

**Finding Lost Objects:**
- Right-click → Fit All to see everything
- Hover a top bar title and select the object
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
- **Escape**: Clear selection (cancels an in-progress box select, then clears area and voxel selection in Brain Monitor)
- **Ctrl+Z** (Cmd+Z on macOS): Undo the last saved move or area delete
- **Shift+Ctrl+Z** (Shift+Cmd+Z): Redo that step

### Brain Monitor Selection Shortcuts

- **Shift + Left Drag**: Draw a rectangle to select multiple cortical areas
- **Ctrl + Click**: Add or remove a cortical area from multi-selection
- **Shift + Click**: Toggle voxel selection (hold Shift, then click voxels)
- **Space**: Fire selected voxels once (release Shift first if you were picking voxels)
- **Shift + Space**: Continuously fire selected voxels until Space
- **Delete**: Clear all selected voxels (also stops continuous fire)
- **Ctrl + C** (Cmd + C on macOS): Copy selected voxels JSON to clipboard
- **Ctrl + V** (Cmd + V on macOS): Paste clipboard voxels into hovered cortical area

### Mouse Shortcuts

- **Left Click**: Select object
- **Left Drag**: Pan camera (3D) or move object (2D)
- **Shift + Left Drag**: Box-select cortical areas (3D) or pan view (2D)
- **Middle Drag**: Pan view
- **Wheel**: Zoom in/out
- **Ctrl + Click**: Multi-select cortical areas (opens Area Firing Recorder when used in Brain Monitor)

See [Navigation Action Reference](navigation_actions_reference.md) for the complete list.

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
- Combine manual navigation with the top bar lists
- Split view for efficiency

### For Large Genomes (100+ areas)

- Heavy use of regions and hierarchy
- Primarily the top bar lists
- Region-specific tabs
- Camera animations for presentations

## Troubleshooting

**"I'm lost and can't find anything"**
- Press Home or Fit All
- Close the region tab, or open the main circuit from its parent view. The Circuits list does not include the main circuit itself.
- Close all tabs and start over

**"Object isn't where I expected"**
- Check which region it is in. Hover **Circuits** to list circuits by name.
- Verify you're viewing correct region
- Use global search if available

**"Navigation is too slow"**
- Hover a top bar title instead of panning across the genome
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
2. **Use the Top Bar Lists for Long Distances**: Don't manually pan across large circuits
3. **Name Objects Clearly**: Makes the hover lists easier to scan
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
- [Mapping Connections](mapping_connections.md) - Quick Connect and mapping workflows
- [Keyboard Shortcuts](keyboard_shortcuts.md) - Complete shortcut reference

[Back to Overview](index.md)
