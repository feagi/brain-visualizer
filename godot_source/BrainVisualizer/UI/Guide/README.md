# Guide Overlay

The guide overlay provides an in-app user guide for Brain Visualizer. It displays markdown content 
with a toolbar for search and text size controls, a left sidebar for topic navigation, and a 
right content area for markdown rendering.

## Components

- `GuideOverlay.gd`: Orchestrates layout, topic discovery, markdown loading, and toolbar controls
- `GuideMarkdownView.gd`: Converts markdown into BBCode, renders it in a `RichTextLabel`, supports dynamic font scaling
- `GuideTopicButton.gd`: Reusable topic button emitting a selection signal

## Layout Structure

1. **Top Toolbar** (HBoxContainer):
   - Search bar for filtering topics
   - Text size controls (+/- buttons)
   - Expandable for future features

2. **Content Area** (HBoxContainer with 25/75 split):
   - Left sidebar (25%): Topic list with scroll
   - Right content area (75%): Markdown rendering with scroll

## Content

Guide markdown files live under `res://BrainVisualizer/Guides`. Markdown files can link to other guides
using relative paths, and can embed images using standard markdown image syntax.
