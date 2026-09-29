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
- **25/75 Split Layout**: Sidebar (25%) of expandable topics, content area (75%) for markdown
- **Two-level topics**: Each guide file is a collapsible topic. Each `##` section inside it is a selectable subtopic. `###` headings stay in the page.
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
BV.WM.spawn_guide_page("pattern_connectivity.md")
BV.WM.spawn_guide_page("vector_connectivity.md")
```

`spawn_guide()` is the top-bar guide button. `spawn_guide_page()` is used by the
help icons on the pattern and vector editors.

## Adding New Guide Topics

1. Create a new `.md` file in `Guides/` folder
2. Start with one H1 heading. That title is the expandable topic in the sidebar
3. Add an H2 for each subtopic. Keep H2 labels short enough to read in the sidebar
4. Use H3 for detail inside a subtopic. Those are not separate sidebar entries
5. Put any introduction before the first H2. It shows as **Overview**
6. Use bullets for lists. The guide view does not render markdown tables
7. Link to other guides using relative paths: `[Link Text](other_guide.md)`
8. Add the filename to `_guide_order.txt`
9. The window lists new guides on open

## Migration from Overlay

This replaces the previous full-screen `GuideOverlay` with a draggable window, allowing users to read guides while interacting with Brain Visualizer.

**Changes:**
- Removed `GuideOverlay` from `UIManager` and `BrainVisualizer.tscn`
- Added `spawn_guide()` to `WindowManager`
- Updated top bar to call `BV.WM.spawn_guide()`
- Reused `GuideMarkdownView` and `GuideTopicButton` components
