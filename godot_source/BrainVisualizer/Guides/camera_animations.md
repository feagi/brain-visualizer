# Camera Animations

Camera animations allow you to record camera paths and positions, then play them back for presentations, demonstrations, or quick returns to important viewpoints. This powerful feature makes Brain Visualizer ideal for showcasing your genome.

## What are Camera Animations?

Camera animations are recorded sequences of camera positions and rotations that play back smoothly. You can:

- **Save single positions**: Quick return to important views
- **Record paths**: Smooth fly-through sequences
- **Create presentations**: Guided tours of your genome
- **Document architecture**: Consistent viewpoints for screenshots

## Opening Camera Animations

**From Top Toolbar:**
1. Click the **Camera Animations** button (camera icon)
2. Camera Animations window opens

![Camera Icon](../UI/GenericResources/ButtonIcons/camera_C.jpg)

The window provides tools for recording, editing, and playing animations.

## Basic Workflow

### 1. Recording Positions

**Single Position (Waypoint):**
1. Navigate camera to desired position
2. Open Camera Animations window
3. Click **Capture Current Frame**
4. Position is saved to the sequence

**Multiple Positions:**
1. Capture first position
2. Navigate to next position
3. Capture again
4. Repeat for all waypoints

Each captured frame records:
- Camera position (X, Y, Z)
- Camera rotation (quaternion)
- Time to next frame

### 2. Configuring Timing

**Time Between Frames:**
- Set duration to hold each position
- Or transition time to next position
- Adjustable per frame

**Default Transition Time:**
- Configure default (e.g., 2 seconds)
- Applied to new frames automatically
- Can be changed per frame

### 3. Playing Animation

**Play Sequence:**
1. Click **Play** button
2. Camera animates through all frames
3. Smooth interpolation between positions

**Playback Options:**
- Play once
- Loop continuously
- Play from specific frame

## Creating Your First Animation

### Quick Viewpoint Save

Save a single position for quick return:

1. Navigate to important view
2. Open Camera Animations
3. Click **Capture Current Frame**
4. Set time to 0 seconds (instant)
5. Name it descriptively (optional)
6. Click **Export** to save

To return later:
1. Open Camera Animations
2. Paste the saved animation data
3. Click **Play**
4. Camera instantly jumps to position

### Simple Fly-Through

Create a smooth path through your genome:

1. Open Camera Animations window
2. Navigate to starting position
3. Click **Capture Current Frame** (Frame 1)
4. Set transition time (e.g., 3 seconds)
5. Navigate to next position
6. Click **Capture Current Frame** (Frame 2)
7. Repeat for 3-5 positions
8. Click **Play** to preview
9. Click **Export** to save

The camera smoothly flies through all positions.

## Animation Configuration

### Frame Management

**Adding Frames:**
- **Capture Current**: Adds camera's current position
- **Manual Entry**: Enter position/rotation values
- **Import**: Load from saved data

**Editing Frames:**
- Click frame in list to select
- Modify position values
- Adjust timing
- Reorder frames (if available)

**Deleting Frames:**
- Select frame
- Click **Delete Frame**
- Or use **Clear All** to start over

### Interpolation Settings

Control how camera moves between frames:

**Linear Interpolation (Movement):**
- **Linear**: Constant speed, sharp corners
- **Cubic**: Smooth acceleration/deceleration
- **Smooth**: Bezier-like curves

**Rotation Interpolation:**
- **Linear**: Direct rotation
- **Spherical**: Smooth rotation along shortest path
- **Cubic**: Smooth with easing

Access via dropdowns in animation window.

### Timing Control

**Per-Frame Timing:**
- Each frame has its own duration
- Time to transition to next frame
- Allows variation (fast/slow sections)

**Global Speed:**
- Adjust playback speed
- 0.5x = half speed (slower)
- 2.0x = double speed (faster)

## Exporting and Importing

### Exporting Animations

Save animation for later use:

1. Create and configure animation
2. Click **Export** button
3. JSON data appears in text field
4. Copy to clipboard
5. Paste into text file or document

**Export Data Includes:**
- All frame positions and rotations
- Timing information
- Interpolation settings

### Importing Animations

Load previously saved animation:

1. Open Camera Animations window
2. Paste JSON data into text field
3. Click **Import** or just close the window
4. Frames load into the sequence

**Sharing Animations:**
- Export to text file
- Share with team members
- Import on any Brain Visualizer instance
- Works across systems

## Advanced Techniques

### Multi-Segment Tours

Create complex presentations:

**Structure:**
1. **Introduction**: Overview of entire genome
2. **Detail Section 1**: Focus on inputs
3. **Detail Section 2**: Processing layers
4. **Detail Section 3**: Outputs
5. **Conclusion**: Return to overview

**Implementation:**
- Capture frames for each section
- Use longer times for important views
- Quick transitions for positioning
- Pause at key areas (longer duration)

### Demo Choreography

Coordinate with genome activity:

1. Start animation
2. Trigger neural activity (via inputs)
3. Camera shows key areas as they activate
4. Timing matches data flow

**Tips:**
- Practice timing
- Adjust frame durations to match activity
- Use loops for continuous demos

### Comparative Views

Show multiple perspectives:

1. Create animation A: Side view fly-through
2. Create animation B: Top view fly-through
3. Play side-by-side in split view
4. Or sequence them (A then B)

### Documentation Snapshots

Consistent screenshots:

1. Navigate to each view for documentation
2. Capture as animation frames
3. Play animation, pause at each frame
4. Take screenshot at each pause
5. All screenshots from exact same angles

## Performance Considerations

### Frame Count

- **1-5 frames**: Quick position saves
- **5-20 frames**: Short fly-throughs
- **20-50 frames**: Detailed tours
- **50+ frames**: Cinematic sequences

More frames = longer creation time but smoother paths.

### Transition Times

- **0 seconds**: Instant jump (snapshots)
- **0.5-1 seconds**: Quick movements
- **2-3 seconds**: Normal transitions
- **5+ seconds**: Slow, detailed views

Adjust based on audience and purpose.

### Large Genomes

For complex genomes:
- Focus on specific circuits
- Use region-specific 3D tabs
- Shorter sequences
- Higher frame counts for smoothness

## Use Cases

### Presentations

**Conference Demos:**
1. Record polished fly-through
2. Narrate over playback
3. Consistent timing
4. Professional appearance

**Team Reviews:**
1. Show architecture evolution
2. Highlight problem areas
3. Demonstrate solutions
4. Repeatable for discussions

### Documentation

**Architecture Documentation:**
- Save standard views (front, top, side)
- Capture overview and detail views
- Use for diagrams and explanations

**Tutorial Creation:**
- Record step-by-step walkthroughs
- Consistent camera angles
- Easy to follow

### Development

**Quick Navigation:**
- Save positions for frequently-accessed areas
- Instant return to work areas
- No manual navigation needed

**Testing:**
- Record test scenarios
- Replay for verification
- Consistent test conditions

### Artistic

**Cinematic Sequences:**
- Dramatic camera movements
- Aesthetic presentations
- Promotional material

## Troubleshooting

**"Animation is jerky"**
- Increase frame count (more waypoints)
- Use Cubic or Smooth interpolation
- Adjust transition times
- Ensure smooth camera movements when recording

**"Camera moves too fast/slow"**
- Adjust per-frame timing
- Or modify global playback speed
- Test and iterate

**"Can't see important details"**
- Add more frames at areas of interest
- Increase duration for detail frames
- Adjust camera position and zoom

**"Export/Import doesn't work"**
- Ensure complete JSON data is copied
- Check for formatting errors
- Try smaller animations first

**"Lost my animation"**
- Always export immediately after creation
- Save to file for permanent storage
- Consider version control for important animations

## Best Practices

### Recording

1. **Plan the Route**: Know what you want to show
2. **Move Smoothly**: Avoid jerky movements between captures
3. **Pause at Key Areas**: Longer duration frames for important views
4. **Test Frequently**: Play back often while creating
5. **Export Immediately**: Don't lose work

### Playback

1. **Preview First**: Always test before presenting
2. **Adjust Speed**: Match audience pace
3. **Consider Context**: Presentation vs quick navigation
4. **Provide Narration**: Explain what's being shown
5. **Use Loops**: For continuous displays

### Organization

1. **Name Animations**: Descriptive names in saved files
2. **Version Control**: Save iterations
3. **Document Purpose**: Note what each animation shows
4. **Share Library**: Build team animation collection

## Keyboard Shortcuts

While in Camera Animations window:

- **Space**: Play/Pause
- **R**: Reset to start
- **Delete**: Remove selected frame
- **Escape**: Close window

(Shortcuts may vary by version)

## Related Topics

- [Camera Controls](camera_controls.md) - Manual navigation
- [Navigation Basics](navigation.md) - Moving around efficiently
- [Brain Monitor](brain_monitor.md) - 3D visualization system
- [Split View](split_view.md) - Multiple view presentations

[Back to Overview](index.md)
