# Camera Controls

Master the camera system to efficiently navigate both 2D and 3D views in Brain Visualizer. This guide covers all camera operations, navigation techniques, and shortcuts.

## 2D Camera (Circuit Builder)

The Circuit Builder uses a 2D camera for navigating the node graph.

### Panning (Moving the View)

**Mouse:**
- **Middle Mouse Drag**: Click and hold middle button, then move mouse
- **Shift + Left Mouse Drag**: Hold Shift, click and hold left button, move mouse

**Keyboard:**
- **Arrow Keys**: Move view in that direction
- **W/A/S/D**: Alternative movement keys

**Tips:**
- Pan smoothly for precision
- Use keyboard for incremental adjustments
- Combine with zoom for efficient navigation

### Zooming

**Mouse:**
- **Scroll Wheel Up**: Zoom in (get closer)
- **Scroll Wheel Down**: Zoom out (see more)
- **Shift + Scroll Wheel or trackpad scroll**: Move closer or farther at double speed

**Keyboard:**
- **Page Up**: Zoom in
- **Page Down**: Zoom out
- **+/-**: Alternative zoom keys

**Tips:**
- Zoom centers on mouse cursor position
- Scroll gradually for fine control
- Quick scroll for rapid zoom changes

### Fit All

Auto-frame all visible objects:

**Method 1:**
- Right-click empty space in Circuit Builder
- Select **Fit All**

**Method 2:**
- In Brain Monitor, move the mouse over that view and press **Home**
- This frames the whole brain from the front

**Use Cases:**
- Lost in large circuits
- After creating many areas
- Quick overview of entire circuit

### Focus on Object

Center view on a specific object:

**Method 1:**
1. Hover **Circuits**, **Inputs**, or **Outputs** on the root scene top bar, or **Circuits**, **Interconnect Areas**, or **Memory Areas** on a tab bar
2. Select an entry from the list
3. The current view focuses on it

## 3D Camera (Brain Monitor)

The Brain Monitor uses a 3D camera with full six-degree-of-freedom movement.

### Orbit

Revolve the camera around a cortical area or point of interest:

**Mouse:**
- **Middle Mouse Drag**: Click and hold the middle button, move mouse
- **Option/Alt + Left Mouse Drag**: For trackpads or mice without a middle button
  - Left/Right: Revolve around the vertical axis
  - Up/Down: Tilt over or under the pivot. The camera stops just short of straight above or below

**What it orbits around**, chosen when you start dragging:
1. The selected cortical areas (the center of all of them)
2. With nothing selected, the point on the cortical area under the center of the screen
3. With nothing there, the center of the whole brain

The camera keeps its distance from the pivot, and the pivot stays where it was on screen. An orbit drag never selects an area or opens the quick menu.

**Tips:**
- Select an area, then middle drag to look at it from every side
- Orbit turns about three times faster than right-drag turning, so a short drag covers a wide angle
- On a Mac trackpad, see Trackpad (macOS) below
- On some Linux desktops, Alt + drag moves the window instead. Use middle drag there

### Turn in Place

Turn the camera's view without moving it:

**Mouse:**
- **Right Mouse Drag**: Click and hold right button, move mouse. On macOS, Control + left drag does the same
  - Left/Right: Turn horizontally (yaw)
  - Up/Down: Turn vertically (pitch)

**Keyboard:**
- **Arrow Keys**: Rotate camera
  - Left/Right: Horizontal rotation
  - Up/Down: Vertical rotation

### Panning (Lateral Movement)

Move camera sideways without rotating:

**Mouse:**
- **Left Mouse Drag**: Click and hold left button, move mouse (Tank mode)
- **Shift + Left Mouse Drag** draws a selection rectangle over cortical areas; it does not pan

**Keyboard:**
- **A/D**: Move left/right
- **Q/E**: Move up/down

**Tips:**
- Use to reposition without changing angle
- Combine with rotation for complex navigation
- Good for framing specific views
- To select several areas at once, hold Shift and drag a box instead of panning

### Zooming (Forward/Backward)

Move camera closer or farther:

**Mouse:**
- **Scroll Wheel Up**: Move forward (zoom in)
- **Scroll Wheel Down**: Move backward (zoom out)
- **Shift + Scroll Wheel or trackpad scroll**: Move closer or farther at double speed

**Keyboard:**
- **W/S**: Move forward/backward
- **Page Up/Down**: Alternative zoom

**Tips:**
- Use to get close for details
- Pull back for overview
- Combines with rotation for orbiting

### Focus on Object

Auto-frame cortical areas or regions:

**Method 1:**
1. **Click** on a cortical area volume
2. The quick menu opens for that area

**Method 2:**
1. Hover the matching title on the root scene top bar or on a tab bar
2. Select the area or circuit
3. The camera focuses on it

**Method 3:**
With the mouse over that Brain Monitor, press a view key to frame the whole brain:
- **T** top, **B** bottom, **F** front, **L** left, **R** right
- **Home** frames the whole brain from the front

### Free Flight Mode

Unrestricted camera movement:

**Enable:**
- Hold **Shift** while moving
- Camera moves in view direction

**Controls:**
- **W**: Forward in view direction
- **S**: Backward in view direction
- **A/D**: Strafe left/right
- **Q/E**: Move up/down in world space

**Use Cases:**
- Flying through complex structures
- Cinematic views
- Exploring large genomes

### Reset View

Return to a full view of the brain:

**Method:**
- Move the mouse over the Brain Monitor and press **Home**
- The camera frames the whole brain from the front

**Default View:**
- Shows the brain in that viewport
- Front facing
- Zoomed to fit

## Camera Settings

Customize camera behavior:

### Access Settings

1. Click **Options** in top toolbar
2. Navigate to **Camera** section
3. Adjust preferences

### Available Settings

**Movement Speed:**
- Faster: Navigate large genomes quickly
- Slower: Precise positioning and fine control
- Adjustable per axis (X, Y, Z)

**Rotation Sensitivity:**
- Higher: Quick rotation with small movements
- Lower: Smooth, controlled rotation
- Separate horizontal and vertical sensitivity

**Zoom Speed:**
- Fast: Rapid in/out transitions
- Slow: Gradual zoom for precision

**Inertia:**
- Enabled: Camera continues moving after release (smooth)
- Disabled: Camera stops immediately (precise)

**Smoothing:**
- Amount of motion smoothing
- Reduces jitter
- More natural feel

**Field of View (FOV):**
- Wider: See more, fish-eye effect
- Narrower: Telephoto, focused view
- Typical: 60-90 degrees

## Advanced Navigation

### Waypoints

Save and return to positions:

**Using Camera Animations:**
1. Position camera at desired view
2. Open Camera Animations window
3. Save current position as animation
4. Play animation to return

See [Camera Animations](camera_animations.md) for details.

### Quick Positions

Keyboard shortcuts for common views, while the mouse is over that Brain Monitor:

**T:** Top
**B:** Bottom
**F:** Front
**L:** Left
**R:** Right
**Home:** Frame the whole brain from the front

### Multi-Monitor Setup

Use split views on multiple screens:

1. Open multiple Brain Monitor tabs
2. Drag tabs to separate windows
3. Move windows to different monitors
4. Navigate independently

## Navigation Strategies

### Exploring New Genome

1. **Start zoomed out**: Get overview with Fit All
2. **Identify regions**: Note spatial organization
3. **Focus on a circuit**: Hover **Circuits** and select it
4. **Explore details**: Zoom in on specific areas
5. **Return to overview**: Press **Home**

### Working on Specific Area

1. **Use a top bar list**: Hover the matching title and select the area
2. **Press F**: Frame the brain from the front
3. **Zoom in**: Get close for details
4. **Isolate in tab**: Open region in dedicated 3D tab

### Comparing Areas

1. **Split View**: See two areas side-by-side
2. **Or Toggle**: Focus on one, remember position, focus on other
3. **Or Tabs**: Open each in separate tab

### Presenting/Demonstrating

1. **Plan route**: Decide what to show
2. **Save waypoints**: Use camera animations
3. **Practice**: Play through sequence
4. **Present**: Smooth navigation with saved paths

See [Camera Animations](camera_animations.md) for demo techniques.

## Trackpad (macOS)

In Brain Monitor:
- **Click-drag**: Pan
- **Option + click-drag**: Orbit around the selected cortical areas. Press the trackpad down until it clicks, keep holding, and slide. You can let go of Option once the drag starts
- **Two-finger click-drag**, or **Control + click-drag**: Turn in place
- **Two-finger scroll up/down**: Move closer or farther
- **Two-finger scroll left/right**: Move sideways
- **Shift + two-finger scroll**: Move closer or farther at double speed

Tap to click cannot orbit, because the tap releases right away. If holding the click while sliding is awkward, turn on three-finger drag: **System Settings** → **Accessibility** → **Pointer Control** → **Trackpad Options**, then set **Use trackpad for dragging** to **Three Finger Drag**. Then hold Option and drag with three fingers.

Pinch does not zoom. Use two-finger scroll instead.

## Touch Screens and Stylus

Brain Monitor does not respond to touch-screen gestures. A stylus that acts as a mouse works like one: use its buttons for middle-drag (orbit) and right-drag (turn in place).

## Keyboard Shortcuts Reference

### Circuit Builder (2D)
- **Arrow Keys**: Pan view
- **Mouse wheel**: Zoom
- **Right-click empty space → Fit All**: Show everything
- **Shift + Drag**: Pan with mouse

### Brain Monitor (3D)
- **W/S**: Move forward/backward
- **A/D**: Move left/right
- **Q/E**: Move up/down
- **Arrow Keys**: Rotate camera
- **T**: Top view
- **B**: Bottom view
- **F**: Front view
- **L**: Left view
- **R**: Right view
- **Home**: Frame the whole brain from the front
- **Shift + WASD**: Move faster
- **Shift + Left Drag**: Box-select cortical areas
- **Middle Drag** or **Option/Alt + Left Drag**: Orbit around the selection
- **Right Drag**: Turn the camera in place

## Tips for Efficient Navigation

### In Circuit Builder

1. **Use a top bar list for long distances**: Faster than panning
2. **Fit All frequently**: Regain orientation
3. **Focus shortcuts**: Quick navigation to specific objects
4. **Tabs**: Keep important views open

### In Brain Monitor

1. **Click to focus**: Fastest way to target
2. **Orbit around focus**: Select an area, then middle drag (or Option/Alt + left drag)
3. **Save positions**: Use camera animations for important views
4. **Split View**: Work with 2D and 3D simultaneously

### General

1. **Learn keyboard shortcuts**: Much faster than mouse-only
2. **Customize speeds**: Adjust to your preference
3. **Use the right tool**: Dropdown vs manual navigation
4. **Practice**: Muscle memory makes navigation effortless

## Troubleshooting

**"Camera moves too fast/slow"**
- Adjust camera speed in Options
- Use keyboard for fine control
- Scroll gradually for smooth zoom

**"Lost my position"**
- Press **Home** to frame the whole brain from the front
- Press **T**, **B**, **F**, **L**, or **R** for top, bottom, front, left, or right
- Hover **Circuits** and select a known circuit

**"Can't see what I'm looking for"**
- Use Fit All to see everything
- Try different zoom levels
- Check you're in the correct region/tab
- Use Search, or hover a top bar title, to find objects

**"Camera feels sluggish"**
- Disable inertia in Options
- Reduce smoothing amount
- Check system performance
- Close unnecessary tabs

**"Camera jumps or jitters"**
- Enable smoothing in Options
- Check mouse/trackpad settings
- Reduce sensitivity
- Ensure stable input device

**"Can't rotate in 3D"**
- Use middle drag or Option/Alt + left drag to orbit, or right drag to turn in place
- Try arrow keys instead
- Check camera isn't locked (if feature exists)
- Reset camera and try again

## Related Topics

- [Navigation Basics](navigation.md) - Basic movement concepts
- [Camera Animations](camera_animations.md) - Recording and playback
- [Brain Monitor](brain_monitor.md) - 3D visualization features
- [Circuit Builder](circuit_builder.md) - 2D graph navigation
- [Split View](split_view.md) - Multiple view navigation

[Back to Overview](index.md)
