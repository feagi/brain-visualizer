# Guide Window

Draggable and resizable user guide window for Brain Visualizer.

## Features

- **Draggable**: Move the window anywhere on screen via title bar
- **Resizable**: 
  - Drag the **right edge** to adjust width only
  - Drag the **bottom-right corner** to adjust both width and height
  - Minimum size: 600x400 pixels
- **Toolbar Controls**:
  - **Search Bar**: Search through guide topics and content (searches both titles and full text)
  - **Text Size Controls**: Small **A** / Large **A** buttons to decrease/increase font size (0.5x to 2.0x)
    - Matches the UI scale control style in the main toolbar
  - **Expandable**: Room for future toolbar additions
- **25/75 Split Layout**: Fixed sidebar (25%) with topic list, content area (75%) for markdown
- **Markdown Support**: Headings, bold, italics, bullets, links, inline code, images
- **Inter-page Links**: Navigate between guide pages using relative links
- **Theme Integration**: Base fonts scale with UI theme, user can further adjust
- **ESC to close**: Press ESC key to close the window

## Architecture

### Components

- **WindowGuide.gd**: Main window controller (extends `BaseDraggableWindow`)
- **WindowGuide.tscn**: Scene structure with title bar, sidebar, and content panels
- **GuideMarkdownView**: Markdown-to-BBCode converter (shared with old overlay)
- **GuideTopicButton**: Topic list item button (shared with old overlay)

### Content Location

Markdown guides are stored in: `godot_source/BrainVisualizer/Guides/`

### Spawning

The guide window is spawned via `WindowManager`:
```gdscript
BV.WM.spawn_guide()
```

Called from the top bar guide icon button.

## Adding New Guide Topics

1. Create a new `.md` file in `Guides/` folder
2. Start with a H1 heading (used as topic title in sidebar)
3. Use standard markdown syntax
4. Link to other guides using relative paths: `[Link Text](other_guide.md)`
5. Window will automatically detect and list new guides

## Migration from Overlay

This replaces the previous full-screen `GuideOverlay` with a draggable window, allowing users to read guides while interacting with Brain Visualizer.

**Changes:**
- Removed `GuideOverlay` from `UIManager` and `BrainVisualizer.tscn`
- Added `spawn_guide()` to `WindowManager`
- Updated top bar to call `BV.WM.spawn_guide()`
- Reused `GuideMarkdownView` and `GuideTopicButton` components
