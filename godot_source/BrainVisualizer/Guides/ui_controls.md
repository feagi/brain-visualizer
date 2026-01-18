# UI Controls

Brain Visualizer provides flexible interface controls to customize the appearance and scale of the application. This guide covers all UI customization options to optimize your workflow.

## UI Scaling

The interface scale affects all UI elements including text, buttons, windows, and panels.

### Quick Scale Controls

Located in the top-right corner of the toolbar:

**Increase Size:**
- Click the **+** (bigger) button
- UI elements scale up
- Useful for high-DPI displays or presentations

**Decrease Size:**
- Click the **-** (smaller) button
- UI elements scale down
- Useful for seeing more content

**Incremental Changes:**
- Each click adjusts by one scale step
- Changes apply immediately
- Smooth scaling transitions

### Available Scale Levels

Brain Visualizer typically offers multiple scale presets:
- **Very Small**: Maximum content visibility
- **Small**: Compact interface
- **Medium**: Default comfortable size
- **Large**: Easier reading
- **Very Large**: Accessibility and presentations

The exact number of levels may vary by version.

### Scale Persistence

- Your chosen scale is remembered between sessions
- Applies to all windows and UI elements
- Consistent across different views

## Theme System

### Current Theme

Brain Visualizer currently uses:
- **Dark Theme**: Default and recommended
- Dark backgrounds reduce eye strain
- High contrast for readability
- Professional appearance

### Theme Components

The theme affects:
- **Background Colors**: Window and panel backgrounds
- **Text Colors**: All text and labels
- **Accent Colors**: Highlights and selections
- **Button Styles**: All interactive elements
- **Panel Styles**: Window frames and separators

## Top Toolbar

The main toolbar provides quick access to essential features:

### Left Section (Information Display)

**Burst Rate:**
- Shows neural processing frequency (Hz)
- Editable field to change rate
- 0 Hz = paused, higher = faster processing

**Neuron Count:**
- Current neurons / Maximum neurons
- Formatted with thousands separators
- Updates as areas are added/removed

**Synapse Count:**
- Current synapses / Maximum synapses
- Formatted with thousands separators
- Updates as connections are created

**State Indicator:**
- Shows FEAGI connection status
- Color-coded (green = connected, red = disconnected)
- Hover for details

### Middle Section (Quick Access)

**Inputs Button:**
- Dropdown showing all IPU areas
- **+** button to create new input
- Quick navigation to any input area

**Circuits Button:**
- Dropdown showing all brain regions
- **+** button to create new region
- Hierarchical region navigation

**Outputs Button:**
- Dropdown showing all OPU areas
- **+** button to create new output
- Quick navigation to any output area

**Morphologies Button:**
- Opens Morphology Manager
- View and edit all morphologies
- Create new morphologies

### Right Section (Tools and Settings)

**Options Button:**
- Opens Options/Settings window
- Configure application preferences
- Access advanced settings

**Camera Animations Button:**
![Camera Icon](../UI/GenericResources/ButtonIcons/camera_C.jpg)
- Opens Camera Animations window
- Record and play camera paths
- Save important viewpoints

**Guide Button:**
![Guide Icon](../UI/GenericResources/ButtonIcons/guide_C.jpg)
- Opens this help system
- Search and browse topics
- Quick reference

**View Previews Button:**
- Opens View Previews window
- Access video feed preview (if available)
- Shared memory video display

**Activity Rendering Toggle:**
- Show/hide global neural connections
- Toggle all connection lines
- Performance optimization

**UI Scale Controls:**
- **+** button: Increase UI size
- **-** button: Decrease UI size
- Immediate visual feedback

## Windows and Panels

### Window Management

**Moving Windows:**
- Click and drag title bar
- Position anywhere on screen
- Windows remember positions

**Resizing Windows:**
- Drag window edges (if resizable)
- Or corners for two-axis resize
- Some windows have fixed size

**Closing Windows:**
- Click **X** button in title bar
- Or press Escape key (for some windows)
- Can reopen from menus

### Window Types

**Modal Windows:**
- Block interaction with other elements
- Must complete or cancel
- Used for critical operations

**Non-Modal Windows:**
- Float above main interface
- Can interact with main view
- Can have multiple open simultaneously

**Panels:**
- Integrated into main interface
- Cannot be closed individually
- Part of main layout

### Z-Order (Window Layering)

Windows stack on top of each other:

**Bring to Front:**
- Click anywhere on window
- Automatically comes to front
- Or use window manager functions

**Behind:**
- Click different window to send current to back
- Or close to remove from stack

## Display Settings

Access via **Options** → **Display**:

### Visualization Options

**Grid Floor:**
- Show/hide reference grid in Brain Monitor
- Helps with spatial orientation
- On by default

**Connection Lines:**
- Always show
- Show on hover only
- Never show
- Affects performance

**Activity Rendering:**
- Quality level (Low/Medium/High)
- Affects visual fidelity and performance
- Balance quality vs. speed

**Transparency:**
- Transparent cortical volumes
- See-through effects
- Visual clarity options

### Performance Options

**Frame Rate Cap:**
- Limit maximum FPS
- Reduce power consumption
- Smoother vs. performance trade-off

**VSync:**
- Synchronize with monitor refresh
- Reduce screen tearing
- May increase input latency

**Anti-Aliasing:**
- Smooth edges
- Better visual quality
- Performance impact

## Accessibility Features

### Text and UI

**Large UI Scale:**
- Use larger scale settings
- Improves readability
- Better for vision impairment

**High Contrast:**
- Dark theme provides good contrast
- Clear text on backgrounds
- Easily distinguishable elements

### Interaction

**Keyboard Navigation:**
- Most operations have keyboard shortcuts
- Reduces mouse dependency
- Faster workflow

**Click Targets:**
- Buttons and controls have adequate size
- Easy to click/select
- Touch-friendly

## Workspace Layouts

### Single View

- One main panel showing Circuit Builder or Brain Monitor
- Full screen real estate for one view
- Simple and focused

### Split View

- Two panels side-by-side or top-bottom
- Circuit Builder + Brain Monitor
- Best for active work

See [Split View](split_view.md) for details.

### Tab System

- Multiple tabs in each panel
- Switch between different regions
- Keep multiple views accessible

### Multi-Window

- Drag tabs out to separate windows
- Position on multiple monitors
- Ultimate flexibility

## Customizing Your Workspace

### For Large Displays

**Recommendations:**
- Medium or Large UI scale
- Split View with 50/50 ratio
- Multiple tabs open
- Horizontal split layout

### For Small Displays

**Recommendations:**
- Small UI scale to maximize content
- Single view or heavily asymmetric split
- Minimize open windows
- Use dropdowns for navigation

### For Presentations

**Recommendations:**
- Large or Very Large UI scale
- Clean, simple layout
- Hide unnecessary panels
- Full screen mode (if available)

### For Development

**Recommendations:**
- Medium UI scale
- Split View for editing + monitoring
- Multiple tabs for different regions
- Developer options enabled

## Shortcuts and Quick Actions

### UI Shortcuts

- **F11**: Full screen toggle (if available)
- **Ctrl + +**: Increase UI scale
- **Ctrl + -**: Decrease UI scale
- **Escape**: Close current window/dialog

### View Shortcuts

- **Tab**: Switch between panels
- **Ctrl + Tab**: Next tab
- **Ctrl + Shift + Tab**: Previous tab
- **Ctrl + W**: Close current tab

(Shortcuts may vary by version)

## Performance Optimization

### Improve Responsiveness

**Close Unused:**
- Close windows not in use
- Close extra tabs
- Minimize background processes

**Reduce Visual Quality:**
- Lower activity rendering quality
- Disable global connection lines
- Reduce anti-aliasing

**Focus on Region:**
- Open specific regions in 3D tabs
- Don't visualize entire large genome
- Work on subsystems

### Balance Quality and Speed

**High-End Systems:**
- Can use highest quality settings
- Multiple windows and tabs
- Complex visualizations

**Low-End Systems:**
- Reduce UI scale slightly
- Lower rendering quality
- Single view workflow
- Close unnecessary elements

## Troubleshooting

**"UI is too small to read"**
- Click **+** button repeatedly to increase scale
- Or use Options → Display → UI Scale
- Consider monitor/display settings

**"UI is too large, can't see everything"**
- Click **-** button to decrease scale
- Adjust window positions
- Consider using higher resolution

**"Buttons are unresponsive"**
- Check if a modal window is open
- Ensure genome is loaded
- Try clicking again or using keyboard
- Restart application if persistent

**"Windows won't stay where I put them"**
- Some windows reset on close
- Try leaving them open instead
- Position may not persist between sessions

**"Can't find a feature"**
- Check all toolbar buttons
- Look in Options menu
- Use this Guide system to search
- Feature may be version-specific

**"Interface is laggy"**
- Reduce UI scale slightly
- Close unnecessary windows
- Check system resources
- Disable visual effects

## Tips for Efficient UI Usage

1. **Learn Toolbar Layout**: Memorize common button positions
2. **Use Keyboard Shortcuts**: Faster than mouse for many operations
3. **Optimize Scale**: Find your comfortable size and stick with it
4. **Close When Done**: Don't leave many windows open
5. **Organize Workspace**: Position windows logically
6. **Use Dropdowns**: Quick access is faster than manual navigation
7. **Practice**: UI becomes second nature with use

## Related Topics

- [Getting Started](getting_started.md) - Initial interface tour
- [Split View](split_view.md) - Multi-panel layouts
- [Camera Controls](camera_controls.md) - View navigation
- [Quick Menu](quick_menu.md) - Context operations
- [Navigation Basics](navigation.md) - Finding your way

[Back to Overview](index.md)
