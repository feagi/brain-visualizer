# Brain Visualizer - Split View Implementation

## Overview
Completely redesigned the View Previews window to display **Raw Video** and **FEAGI Preview** side-by-side in a split-screen layout.

## Key Changes

### UI Architecture
- **Removed**: Dropdown view toggle, scale buttons, single-view logic
- **Added**: HSplitContainer with independent Raw and FEAGI panels
- **Layout**: 50/50 split with adjustable divider (200px minimum per side)
- **Window Sizing**: Default 1200x600, resizable via drag handle at bottom-right corner

### Each Panel Contains:
1. **Header Bar** (fixed):
   - Stream name (Raw Video / FEAGI Preview)
   - Resolution (e.g., "1280x720")
   - Aspect ratio (e.g., "(16:9)")
   - FPS (e.g., "12.0 FPS")

2. **ScrollContainer** (auto-scrolling if content exceeds container)

3. **TextureRect** (auto-scaling):
   - `expand_mode = 1` (fit aspect)
   - `stretch_mode = 5` (keep aspect centered)
   - Videos automatically fill available width/height while maintaining aspect ratio

4. **Placeholder Label**:
   - "Waiting for raw video stream..." (left panel)
   - "Waiting for FEAGI preview stream..." (right panel)
   - Hidden when video is active

### Shared Controls (Single Instance)
- **Gaze Control** (FEAGI): Eccentricity and Modularity sliders
- **Image Pre-Processing**: Brightness, Contrast, Grayscale
- **Motion Detection**: Pixel intensity, Receptive field, Motion intensity, Min blob size
- All controls remain below the split-view container

### Auto-Scaling Behavior
- Videos automatically scale to fill their container while maintaining aspect ratio
- No manual scale buttons needed
- Each panel has independent scroll if content overflows
- Split divider can be dragged left/right to adjust panel widths
- Window can be resized by dragging the bottom-right corner handle
- Minimum window size: 450px width (225px per panel), 400px height

### FPS Tracking
- Independent FPS tracking for Raw and FEAGI streams
- Rolling 30-frame average for smooth display
- Accurate `frame_seq` based tracking (only counts new frames)

### Aspect Ratio Display
- Calculated using GCD (Greatest Common Divisor)
- Simplified to common ratios (e.g., 16:9, 4:3, 1:1)
- Updates dynamically when resolution changes

### SHM Restart Handling
- Detects video agent restarts via `frame_seq` jump backward
- Automatically closes and reopens SHM file for new memory mapping
- Independent restart handling for each stream

## Files Modified

### 1. WindowViewPreviews.tscn
- Replaced single `Scroll/PanelContainer/TextureRect` with `SplitViewContainer/HSplitContainer`
- Added `RawVideoPanel` (left):
  - `RawHeader` → `RawHeaderInfo` (resolution, aspect, FPS labels)
  - `RawScroll` → `RawViewport` → `RawTextureRect` + `RawPlaceholder`
- Added `FeagiVideoPanel` (right):
  - `FeagiHeader` → `FeagiHeaderInfo` (resolution, aspect, FPS labels)
  - `FeagiScroll` → `FeagiViewport` → `FeagiTextureRect` + `FeagiPlaceholder`
- Removed: `ViewToggle` dropdown, `sizes` container (scale buttons)

### 2. WindowViewPreviews.gd
- **Removed 700+ lines** of old code (scale logic, toggle handling, old UI references)
- **Rewrote from scratch** with clean split-view architecture
- **New functions**:
  - `_update_stream_info(is_raw, resolution, fps)` - Updates header labels
  - `_gcd(a, b)` - Calculates aspect ratio
  - `_on_resize_handle_gui_input(event)` - Handles window resizing
- **Updated `_process()`**:
  - Polls both SHM readers independently
  - Updates both panels separately
  - Maintains independent FPS tracking
- **Segmentation overlay** now only on FEAGI panel
- **Window resizing**:
  - Default size: 1200x600 pixels (double the original width)
  - Drag handle at bottom-right corner for manual resizing
  - Enforces minimum size constraints
- **No fallbacks** - clean, robust implementation

## Benefits

### User Experience
✅ **Side-by-side comparison**: See raw and processed video simultaneously  
✅ **No more flipping**: Both streams always visible  
✅ **Intuitive layout**: Clear headers with all relevant info  
✅ **Auto-scaling**: Videos automatically fit available space  
✅ **Adjustable**: Drag divider to prioritize one stream over the other  

### Technical
✅ **Independent scrolling**: Each panel maintains its own scroll state  
✅ **Independent FPS tracking**: Accurate per-stream performance metrics  
✅ **Clean code**: ~600 lines vs. 1090 lines (45% reduction)  
✅ **No dead code**: Removed all old scale/toggle logic  
✅ **Robust**: Proper SHM restart handling per stream  

## Testing Checklist

- [ ] Both streams display correctly when video agent is running
- [ ] Placeholder messages show when streams are not available
- [ ] Headers update correctly (resolution, aspect, FPS)
- [ ] Aspect ratio calculated correctly (16:9, 4:3, etc.)
- [ ] FPS displays accurately (matches video source)
- [ ] Split divider can be dragged left/right
- [ ] Each panel maintains minimum 200px width
- [ ] Window opens at 1200x600 (double width for side-by-side view)
- [ ] Window can be resized by dragging bottom-right corner
- [ ] Minimum window size enforced (450x400)
- [ ] Videos auto-scale to fill available space after resize
- [ ] Aspect ratio is maintained (no stretching)
- [ ] Independent scrolling works if videos are large
- [ ] Gaze control overlay shows on FEAGI panel only
- [ ] Shared controls (Gaze, PreProc, Motion) work correctly
- [ ] Video agent restart auto-recovery works for both streams
- [ ] Selecting different agent from dropdown switches streams

## Notes

- **Default window size**: 1200x600 (double the original 600px width for side-by-side view)
- **Minimum width**: 200px per panel prevents UI from breaking (450px total minimum)
- **Minimum height**: 400px total (300px for split container + ~100px for controls)
- **Default split**: 50/50 (equal width)
- **Stretch mode 5**: Keep aspect centered (Godot TextureRect feature)
- **Header font sizes**: Title=12, Info=11 (consistent hierarchy)
- **Auto-scaling**: Built into Godot TextureRect, no custom logic needed
- **Segmentation overlay**: Only drawn on FEAGI panel where it's relevant
- **Resize handle**: 16x16 pixel drag area at bottom-right corner (diagonal cursor)

