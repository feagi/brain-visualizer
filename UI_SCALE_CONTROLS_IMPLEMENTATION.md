# UI Scale Controls Implementation

## Overview
Added independent, semi-transparent +/- buttons at the **far top-right corner** of the Brain Visualizer screen for adjusting UI element sizing. The scale control is completely independent from the top navigation bar.

## Changes Made

### 1. New Files Created

#### ScaleControl.gd
- **Location**: `BrainVisualizer/UI/ScaleControl/ScaleControl.gd`
- **Purpose**: Controls the UI scaling functionality independently
- **Features**:
  - Manages scale index (0-5)
  - Communicates with UIManager to switch themes
  - Enables/disables buttons at min/max scale
  - Fixed size - does not scale with theme changes

#### ScaleControl.tscn
- **Location**: `BrainVisualizer/UI/ScaleControl/ScaleControl.tscn`
- **Structure**:
  - Root Control node anchored to top-right corner
  - Semi-transparent PanelContainer (70% opacity)
  - VBoxContainer with + button on top, - button below
  - Fixed button size: 48x48 pixels (does not change with theme)
  - Positioned 10px from top, 10px from right edge
  - Total control size: 60x116 pixels

### 2. Modified Files

#### BrainVisualizer.tscn
- Added ScaleControl instance as child of UIManager
- Positioned independently at top-right corner
- Not affected by theme scaling or other UI elements

### 3. TopBar (Unchanged)
- Original ChangeSize control remains hidden
- No modifications to TopBar functionality
- Scale control is completely separate

## Scale System

### Available Scales
The UI supports the following scale multipliers:
- 0.5x (50%)
- 0.75x (75%)
- 1.0x (100%) - **Default**
- 1.25x (125%)
- 1.5x (150%)
- 2.0x (200%)

### Default Scale
- Starts at index 2, which corresponds to 1.0x (100% scale)
- This provides a sensible baseline that users can adjust up or down

### How It Works
1. Each scale value corresponds to a theme file (e.g., `1-DARK.tres`, `1.25-DARK.tres`)
2. Theme files contain size constants for all UI elements
3. Clicking + or - switches to the next/previous theme file
4. **The scale control buttons maintain fixed 48x48 size**
5. All OTHER UI elements automatically adjust to the new theme's size constants

## User Experience

### Visual Properties
- **Location**: Far top-right corner (10px from top and right edges)
- **Independence**: Completely separate from navigation bar
- **Visibility**: Semi-transparent (70% opacity) to avoid obstruction
- **Layout**: Vertically stacked with + on top, - below
- **Size**: Fixed 48x48px buttons that DO NOT change with scaling
- **Feedback**: Buttons disable when at min/max scale
- **Tooltips**: "Increase UI Size" and "Decrease UI Size"

### Interaction
- Always accessible regardless of other UI state
- Mouse filter allows interaction even when other elements are nearby
- Responds immediately to clicks
- Visual feedback on hover and press

## Technical Details

### Positioning
```gdscript
# Control node anchored to top-right
anchors_preset = 1  # Top-right
anchor_left = 1.0
anchor_right = 1.0
offset_left = -70.0   # 60px control + 10px margin
offset_top = 10.0
offset_right = -10.0
offset_bottom = 126.0  # 116px height
```

### Fixed Size Implementation
- Buttons use `custom_minimum_size = Vector2(48, 48)`
- Control node does NOT apply theme scaling
- Position is absolute, not relative to theme
- Semi-transparency is a fixed modulation value

### Button Behavior
- Clicking + calls `_increase_scale()` which increments the scale index
- Clicking - calls `_decrease_scale()` which decrements the scale index
- Buttons auto-disable at min (0) and max (5) indices
- Scale changes trigger a theme reload via `BV.UI.request_switch_to_theme()`

### Theme-Based Scaling
- Themes are loaded from `res://BrainVisualizer/UI/Themes/`
- Each theme file contains `generic_scale` constants
- The scaling factor is calculated as `size_x / 4.0`
- All UI elements that use theme variants automatically scale
- **ScaleControl itself does NOT scale with theme**

## File Structure
```
BrainVisualizer/
├── UI/
│   ├── ScaleControl/
│   │   ├── ScaleControl.gd          (new)
│   │   ├── ScaleControl.gd.uid      (new)
│   │   ├── ScaleControl.tscn        (new)
│   │   └── ScaleControl.tscn.uid    (new)
│   └── Top_Bar/
│       ├── TopBar.gd                (unchanged)
│       └── TopBar.tscn              (unchanged)
└── BrainVisualizer.tscn             (modified - added ScaleControl)
```

## Testing Checklist
- [ ] Buttons appear at far top-right corner of screen
- [ ] Buttons are independent from top navigation bar
- [ ] Buttons are semi-transparent (70% opacity)
- [ ] + button is on top, - button is below
- [ ] Clicking + increases UI element sizes
- [ ] Clicking - decreases UI element sizes
- [ ] **Scale control buttons maintain fixed 48x48 size when scaling**
- [ ] Buttons disable at min/max scales
- [ ] Default scale (1.0x) is applied on startup
- [ ] Tooltips display correctly on hover
- [ ] Theme switching is smooth and consistent
- [ ] Control remains in top-right corner during window resize
- [ ] Control is accessible even when other UI elements are open

## Key Differences from Initial Implementation
1. **Position**: Top-right corner of screen, NOT part of TopBar
2. **Independence**: Separate Control node, not nested in existing UI
3. **Fixed Size**: Buttons maintain 48x48px size regardless of theme scale
4. **Anchoring**: Anchored to top-right corner to stay in position
5. **Simplicity**: Minimal, focused implementation with single purpose

## Migration Notes
- No backward compatibility concerns (new feature)
- TopBar's hidden ChangeSize control remains untouched
- ScaleControl is additive, doesn't modify existing code
- Uses existing theme system and scale values
- No changes to UIManager's scaling logic
