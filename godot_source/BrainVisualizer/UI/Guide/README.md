# Guide Overlay

The guide overlay provides an in-app user guide for Brain Visualizer. It is a full-screen UI layer that
renders markdown content on the right and lists available guide topics on the left with search.

## Components

- `GuideOverlay.gd`: Orchestrates layout, topic discovery, and markdown loading.
- `GuideMarkdownView.gd`: Converts markdown into BBCode and renders it in a `RichTextLabel`.
- `GuideTopicButton.gd`: Reusable topic button emitting a selection signal.

## Content

Guide markdown files live under `res://BrainVisualizer/Guides`. Markdown files can link to other guides
using relative paths, and can embed images using standard markdown image syntax.
