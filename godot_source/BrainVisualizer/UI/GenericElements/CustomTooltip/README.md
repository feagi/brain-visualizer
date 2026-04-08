# Custom Top Bar Tooltip System

## Overview

This custom tooltip system provides stylish, message-box style tooltips that appear below UI elements in the top bar area. The tooltips remain visible and styled with modern design, featuring smooth fade animations and intelligent positioning.

## Components

### 1. CustomTopBarTooltip.gd/.tscn
The visual tooltip component itself. Features:
- Stylish dark panel with blue border and shadow
- Smooth fade-in/fade-out animations
- Auto-positioning below the anchor element
- Viewport boundary detection to prevent overflow
- Centered text with proper padding

### 2. CustomTopBarTooltipManager.gd
Manager that controls a single shared tooltip instance. Features:
- Creates and manages a global tooltip overlay
- Supports both standard anchoring and tab-specific positioning
- Virtual anchor system for TabBar tabs
- Automatic cleanup on exit

### 3. CustomTooltipTrigger.gd
A helper node that can be attached to any Control to trigger tooltips on hover. Features:
- Automatic parent control detection
- Mouse enter/exit event handling
- Auto-discovery of tooltip manager in scene tree
- Dynamic tooltip text updates

## Usage

### For Top Bar Buttons

In `TopBar.gd`, tooltips are automatically added in the `_setup_custom_tooltips()` method:

```gdscript
func _setup_custom_tooltips() -> void:
    # Create the tooltip manager
    var tooltip_manager_script = load("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTopBarTooltipManager.gd")
    _tooltip_manager = Node.new()
    _tooltip_manager.set_script(tooltip_manager_script)
    add_child(_tooltip_manager)
    
    # Add tooltips to specific controls
    _add_tooltip_to_control($SomeButton, "Button description")

func _add_tooltip_to_control(control: Control, tooltip_text: String) -> void:
    control.tooltip_text = ""  # Disable built-in tooltip
    
    var trigger_script = load("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")
    var trigger = Node.new()
    trigger.set_script(trigger_script)
    control.add_child(trigger)
    trigger.set("tooltip_text", tooltip_text)
```

### For Tab Containers

In `UITabContainer.gd`, tooltips are shown via mouse motion detection on the TabBar:

```gdscript
func _setup_custom_tooltip_manager() -> void:
    # Create manager
    _tooltip_manager = Node.new()
    _tooltip_manager.set_script(tooltip_manager_script)
    add_child(_tooltip_manager)
    
    # Connect to tab bar events
    _tab_bar.gui_input.connect(_on_tab_bar_gui_input)
    _tab_bar.mouse_exited.connect(_on_tab_bar_mouse_exited)

func _on_tab_bar_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var tab_idx = _get_tab_at_position(event.position)
        if tab_idx >= 0:
            _tooltip_manager.show_tooltip_at_tab(tooltip_text, _tab_bar, tab_idx)
```

## Styling

The tooltip uses inline StyleBoxFlat styling with these properties:
- Background: Dark blue-gray (0.12, 0.15, 0.20, 0.95)
- Border: 2px, bright blue (0.35, 0.55, 0.85, 0.8)
- Corner radius: 6px
- Shadow: Black with 8px blur, 3px offset
- Text: Light gray (0.95, 0.95, 0.98), 14px font size

## Integration Points

### Top Bar Elements (TopBar.gd)
- Brain Regions list/add buttons
- Inputs list/add buttons
- Outputs list/add buttons
- Brain Areas list
- Split view dropdown
- Activity visualization dropdown
- Camera animations button
- Guide button
- Settings button

### Tab Elements (UITabContainer.gd)
- Circuit Builder tabs
- Brain Monitor tabs

## Technical Details

### Positioning Logic
1. Tooltip centers horizontally under the anchor control
2. Appears 8px below the anchor control
3. Checks viewport boundaries and adjusts position if needed
4. Maintains 10px minimum margin from screen edges

### Animation
- Fade in: 0.15 seconds
- Fade out: 0.15 seconds
- Uses Godot's Tween system for smooth transitions

### Z-Index
- Tooltip container: No specific z-index (uses default scene hierarchy)
- Tooltip: z-index 1000 (ensures it appears above most UI elements)

## Maintenance Notes

- All tooltip strings are defined in the parent components (TopBar.gd, UITabContainer.gd)
- To add new tooltips, use `_add_tooltip_to_control()` in the setup phase
- Tooltip manager is automatically cleaned up when parent is removed from tree
- No theme file modifications needed - styling is self-contained
