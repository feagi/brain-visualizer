extends Control
class_name GuideOverlay

signal close_requested

@export var guides_directory: String = "res://BrainVisualizer/Guides"

var _search_bar: LineEdit
var _topic_container: VBoxContainer
var _markdown_view: GuideMarkdownView
var _sidebar: VBoxContainer
var _title_label: Label
var _topics: Array[Dictionary] = []

## Initialize the overlay layout and load guide topics.
func _ready() -> void:
	_search_bar = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideSidebar/SearchBar
	_topic_container = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideSidebar/TopicsScroll/TopicsList
	_markdown_view = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideBody/ContentScroll/ContentMargin/GuideMarkdownView
	_sidebar = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideSidebar
	_title_label = $OverlayPanel/PanelMargin/PanelContent/Header/TitleLabel
	$OverlayPanel/PanelMargin/PanelContent/Header/CloseButton.pressed.connect(_on_close_pressed)
	_search_bar.text_changed.connect(_on_search_changed)
	_markdown_view.markdown_link_clicked.connect(_on_markdown_link_clicked)
	visible = false
	_refresh_topics()
	_apply_header_scaling()
	# Set sidebar width dynamically after scene loads
	call_deferred("_update_sidebar_width")
	resized.connect(_update_sidebar_width)

## Show the guide overlay and focus the search bar.
func show_overlay() -> void:
	visible = true
	_search_bar.grab_focus()
	_apply_header_scaling()
	call_deferred("_update_sidebar_width")

## Hide the guide overlay.
func hide_overlay() -> void:
	visible = false

## Toggle the overlay visibility.
func toggle_overlay() -> void:
	if visible:
		hide_overlay()
	else:
		show_overlay()

## Load markdown topics from disk and populate the sidebar.
func _refresh_topics() -> void:
	_topics.clear()
	for child in _topic_container.get_children():
		child.queue_free()
	var markdown_files := _collect_markdown_files(guides_directory)
	for markdown_path in markdown_files:
		var title := _extract_title(markdown_path)
		var button := GuideTopicButton.new()
		button.setup(title, markdown_path)
		button.topic_selected.connect(_on_topic_selected)
		_topic_container.add_child(button)
		_topics.append({
			"title": title,
			"path": markdown_path,
			"button": button,
		})
	if _topics.is_empty():
		_markdown_view.show_message("No guide topics found.")
		return
	_open_markdown(_topics[0]["path"])

## Update sidebar width to be exactly 25% of the overlay width.
func _update_sidebar_width() -> void:
	if _sidebar == null:
		return
	await get_tree().process_frame
	# Get the overlay panel width (the parent container)
	var overlay_panel: PanelContainer = $OverlayPanel
	if overlay_panel == null:
		return
	var total_width: float = overlay_panel.size.x
	if total_width <= 10.0:
		return
	
	# Set sidebar to exactly 25% of total width (minus margins)
	var sidebar_width := int(total_width * 0.25)
	_sidebar.custom_minimum_size.x = sidebar_width
	print("GuideOverlay: Setting fixed sidebar width to %d pixels (25%% of %d)" % [sidebar_width, int(total_width)])

## Scale header text to match UI size.
func _apply_header_scaling() -> void:
	if _title_label == null:
		return
	var header_size := _title_label.get_theme_font_size("font_size", "Label_Header")
	if header_size <= 0:
		header_size = 30
	_title_label.add_theme_font_size_override("font_size", int(header_size * 1.4))

## Filter guide topics by the search query.
func _on_search_changed(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	for topic in _topics:
		var title: String = topic["title"]
		var button: GuideTopicButton = topic["button"]
		if normalized == "":
			button.visible = true
			continue
		button.visible = title.to_lower().find(normalized) >= 0

## Open the selected guide markdown.
func _on_topic_selected(markdown_path: String) -> void:
	print("GuideOverlay: Topic selected: %s" % markdown_path)
	_open_markdown(markdown_path)

## Resolve markdown links to other guide files.
func _on_markdown_link_clicked(target_path: String) -> void:
	print("GuideOverlay: Markdown link clicked: %s" % target_path)
	if _is_markdown_path(target_path):
		_open_markdown(target_path)

## Load and display a markdown file.
func _open_markdown(markdown_path: String) -> void:
	print("GuideOverlay: Opening markdown: %s" % markdown_path)
	if markdown_path == "":
		push_error("GuideOverlay: Empty markdown path")
		return
	if not FileAccess.file_exists(markdown_path):
		push_error("GuideOverlay: Markdown path not found: %s" % markdown_path)
		_markdown_view.show_message("Guide file not found: %s" % markdown_path)
		return
	print("GuideOverlay: File exists, loading...")
	_markdown_view.load_markdown(markdown_path)

## Collect all markdown files within the guides directory.
func _collect_markdown_files(base_dir: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(base_dir)
	if dir == null:
		push_error("GuideOverlay: Unable to open guides directory at %s." % base_dir)
		return results
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var path := base_dir.path_join(name)
		if dir.current_is_dir():
			results.append_array(_collect_markdown_files(path))
		elif _is_markdown_path(path):
			results.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	results.sort()
	return results

## Extract the first heading title from a markdown file.
func _extract_title(markdown_path: String) -> String:
	var file := FileAccess.open(markdown_path, FileAccess.READ)
	if file == null:
		push_error("GuideOverlay: Unable to read markdown at %s." % markdown_path)
		return markdown_path.get_file()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#"):
			var heading_level := 0
			for i in range(line.length()):
				if line[i] != "#":
					break
				heading_level += 1
			return line.substr(heading_level).strip_edges()
	return markdown_path.get_file()

## Check if a path points to a markdown file.
func _is_markdown_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension == "md" or extension == "markdown"

## Close the overlay when requested by the UI.
func _on_close_pressed() -> void:
	hide_overlay()
	close_requested.emit()
