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
- Right-click empty space
- Select **Fit All** or **Frame All**

**Method 2:**
- Press **Home** key (if bound)

**Method 3:**
- Menu → View → Fit All

**Use Cases:**
- Lost in large circuits
- After creating many areas
- Quick overview of entire circuit

### Focus on Object

Center view on specific object:

**Method 1:**
1. Select cortical area or region
2. Press **F** key

**Method 2:**
1. Use top toolbar dropdowns (Inputs/Circuits/Outputs)
2. Select area from list
3. View auto-focuses

**Method 3:**
- Right-click object → **Focus**

## 3D Camera (Brain Monitor)

The Brain Monitor uses a 3D camera with full six-degree-of-freedom movement.

### Rotation (Orbit)

Rotate camera around focus point:

**Mouse:**
- **Left Mouse Drag**: Click and hold left button, move mouse
  - Left/Right: Rotate horizontally (yaw)
  - Up/Down: Rotate vertically (pitch)

**Keyboard:**
- **Arrow Keys**: Rotate camera
  - Left/Right: Horizontal rotation
  - Up/Down: Vertical rotation

**Tips:**
- Camera orbits around point of interest
- Combined with pan for full control
- Smooth movements for best view

### Panning (Lateral Movement)

Move camera sideways without rotating:

**Mouse:**
- **Middle Mouse Drag**: Click and hold middle button, move mouse
- **Shift + Left Mouse Drag**: Hold Shift, click and hold left button, move mouse

**Keyboard:**
- **A/D**: Move left/right
- **Q/E**: Move up/down

**Tips:**
- Use to reposition without changing angle
- Combine with rotation for complex navigation
- Good for framing specific views

### Zooming (Forward/Backward)

Move camera closer or farther:

**Mouse:**
- **Scroll Wheel Up**: Move forward (zoom in)
- **Scroll Wheel Down**: Move backward (zoom out)
- **Right Mouse Drag**: Drag up to zoom in, down to zoom out

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
2. Camera smoothly transitions to frame it

**Method 2:**
1. Select area in Circuit Builder
2. Press **F** key
3. Both views focus

**Method 3:**
1. Use top toolbar dropdowns
2. Select area or region
3. Camera focuses and flashes indicator

**Transition:**
- Smooth animation to target
- Maintains approximate angle
- Adjusts distance to frame object

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

Return to default position:

**Method:**
- Press **Home** key
- OR Menu → Camera → Reset
- OR Re-focus on main region

**Default View:**
- Shows entire genome
- Standard orientation
- Appropriate zoom distance

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

Keyboard shortcuts for common views:

**Front View:** Top toolbar → Camera → Front
**Top View:** Top toolbar → Camera → Top
**Side View:** Top toolbar → Camera → Side
**Isometric:** Top toolbar → Camera → Isometric

(If available in your version)

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
3. **Focus on region**: Use dropdowns to navigate
4. **Explore details**: Zoom in on specific areas
5. **Return to overview**: Press Home or Fit All

### Working on Specific Area

1. **Use dropdowns**: Navigate directly to area
2. **Focus (F key)**: Frame the area
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

## Touch and Tablet Support

If using a touch device:

**Gestures:**
- **One finger drag**: Rotate camera
- **Two finger drag**: Pan camera
- **Pinch**: Zoom in/out
- **Double tap**: Focus on object

**Stylus:**
- Stylus functions as mouse
- Use stylus buttons for middle/right-click

## Keyboard Shortcuts Reference

### Circuit Builder (2D)
- **Arrow Keys**: Pan view
- **Page Up/Down**: Zoom in/out
- **Home**: Fit all
- **F**: Focus on selected
- **Shift + Drag**: Pan with mouse

### Brain Monitor (3D)
- **W/S**: Move forward/backward
- **A/D**: Move left/right
- **Q/E**: Move up/down
- **Arrow Keys**: Rotate camera
- **Page Up/Down**: Zoom in/out
- **Home**: Reset camera
- **F**: Focus on selected
- **Shift + WASD**: Free flight mode

## Tips for Efficient Navigation

### In Circuit Builder

1. **Use dropdowns for long distances**: Faster than panning
2. **Fit All frequently**: Regain orientation
3. **Focus shortcuts**: Quick navigation to specific objects
4. **Tabs**: Keep important views open

### In Brain Monitor

1. **Click to focus**: Fastest way to target
2. **Orbit around focus**: Use rotation after focusing
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
- Press Home to reset
- Use Focus (F) on any object
- Use dropdowns to navigate to known regions

**"Can't see what I'm looking for"**
- Use Fit All to see everything
- Try different zoom levels
- Check you're in the correct region/tab
- Use Search or dropdowns to find objects

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
- Ensure you're clicking on background (not object)
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
