extends Control
class_name GuideOverlay

signal close_requested

@export var guides_directory: String = "res://BrainVisualizer/Guides"

var _search_bar: LineEdit
var _topic_container: VBoxContainer
var _markdown_view: GuideMarkdownView
var _split_container: HSplitContainer
var _topics: Array[Dictionary] = []

## Initialize the overlay layout and load guide topics.
func _ready() -> void:
	_search_bar = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideSidebar/SearchBar
	_topic_container = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideSidebar/TopicsScroll/TopicsList
	_markdown_view = $OverlayPanel/PanelMargin/PanelContent/GuideContent/GuideBody/ContentScroll/ContentMargin/GuideMarkdownView
	_split_container = $OverlayPanel/PanelMargin/PanelContent/GuideContent
	$OverlayPanel/PanelMargin/PanelContent/Header/CloseButton.pressed.connect(_on_close_pressed)
	_search_bar.text_changed.connect(_on_search_changed)
	_markdown_view.markdown_link_clicked.connect(_on_markdown_link_clicked)
	visible = false
	resized.connect(_on_resized)
	_refresh_topics()

## Show the guide overlay and focus the search bar.
func show_overlay() -> void:
	visible = true
	_search_bar.grab_focus()

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

## Resize the split panel to keep the guide body at 60% width.
func _on_resized() -> void:
	var split_offset := int(size.x * 0.4)
	_split_container.split_offset = split_offset

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
	_open_markdown(markdown_path)

## Resolve markdown links to other guide files.
func _on_markdown_link_clicked(target_path: String) -> void:
	if _is_markdown_path(target_path):
		_open_markdown(target_path)

## Load and display a markdown file.
func _open_markdown(markdown_path: String) -> void:
	if markdown_path == "":
		return
	if not ResourceLoader.exists(markdown_path):
		push_error("GuideOverlay: Markdown path not found: %s" % markdown_path)
		return
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
