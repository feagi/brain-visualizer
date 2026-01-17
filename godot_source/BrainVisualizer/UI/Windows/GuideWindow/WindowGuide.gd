extends BaseDraggableWindow
class_name WindowGuide

const WINDOW_NAME: StringName = "guide_window"
const MIN_WINDOW_WIDTH: int = 600
const MIN_WINDOW_HEIGHT: int = 400

@export var guides_directory: String = "res://BrainVisualizer/Guides"

var _search_bar: LineEdit
var _topic_container: VBoxContainer
var _markdown_view: GuideMarkdownView
var _sidebar: VBoxContainer
var _topics: Array[Dictionary] = []

# Window resizing
var _resize_handle: Panel
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_margin: int = 16

## Initialize and setup the guide window.
func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	
	_search_bar = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideSidebar/SearchBar
	_topic_container = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideSidebar/TopicsScroll/TopicsList
	_markdown_view = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideBody/ContentScroll/ContentMargin/GuideMarkdownView
	_sidebar = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideSidebar
	
	_search_bar.text_changed.connect(_on_search_changed)
	_markdown_view.markdown_link_clicked.connect(_on_markdown_link_clicked)
	
	_setup_resize_handle()
	
	_refresh_topics()
	call_deferred("_update_sidebar_width")
	resized.connect(_update_sidebar_width)

## Create resize handle in bottom-right corner.
func _setup_resize_handle() -> void:
	_resize_handle = Panel.new()
	_resize_handle.name = "ResizeHandle"
	_resize_handle.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	
	# Add visual grip indicator
	var grip_icon := Control.new()
	grip_icon.name = "GripIcon"
	grip_icon.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	grip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_icon.draw.connect(_draw_resize_grip.bind(grip_icon))
	_resize_handle.add_child(grip_icon)
	
	add_child(_resize_handle)
	_resize_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_resize_handle.offset_left = -_resize_margin
	_resize_handle.offset_top = -_resize_margin
	_resize_handle.z_index = 1000

## Handle resize dragging.
func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resizing = true
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_size = size
			else:
				_resizing = false
	
	elif event is InputEventMouseMotion and _resizing:
		var delta := get_global_mouse_position() - _resize_start_mouse
		var new_size := _resize_start_size + delta
		
		# Enforce minimum size
		new_size.x = max(new_size.x, MIN_WINDOW_WIDTH)
		new_size.y = max(new_size.y, MIN_WINDOW_HEIGHT)
		
		size = new_size
		custom_minimum_size = new_size

## Draw resize grip indicator in bottom-right corner.
func _draw_resize_grip(control: Control) -> void:
	var grip_color := Color(0.6, 0.6, 0.6, 0.9)
	var square_size := 8
	
	# Draw square at the right side of the control
	var x_pos := _resize_margin - square_size
	var y_pos := (_resize_margin - square_size) / 2.0
	
	var rect := Rect2(Vector2(x_pos, y_pos), Vector2(square_size, square_size))
	control.draw_rect(rect, grip_color, true)

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

## Update sidebar width to be exactly 25% of the window width.
func _update_sidebar_width() -> void:
	if _sidebar == null:
		return
	await get_tree().process_frame
	var window_panel: PanelContainer = $WindowPanel
	if window_panel == null:
		return
	var total_width: float = window_panel.size.x
	if total_width <= 10.0:
		return
	var sidebar_width := int(total_width * 0.25)
	_sidebar.custom_minimum_size.x = sidebar_width

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
	print("WindowGuide: Topic selected: %s" % markdown_path)
	_open_markdown(markdown_path)

## Resolve markdown links to other guide files.
func _on_markdown_link_clicked(target_path: String) -> void:
	print("WindowGuide: Markdown link clicked: %s" % target_path)
	if _is_markdown_path(target_path):
		_open_markdown(target_path)

## Load and display a markdown file.
func _open_markdown(markdown_path: String) -> void:
	print("WindowGuide: Opening markdown: %s" % markdown_path)
	if markdown_path == "":
		push_error("WindowGuide: Empty markdown path")
		return
	if not FileAccess.file_exists(markdown_path):
		push_error("WindowGuide: Markdown path not found: %s" % markdown_path)
		_markdown_view.show_message("Guide file not found: %s" % markdown_path)
		return
	print("WindowGuide: File exists, loading...")
	_markdown_view.load_markdown(markdown_path)

## Collect all markdown files within the guides directory.
func _collect_markdown_files(base_dir: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(base_dir)
	if dir == null:
		push_error("WindowGuide: Unable to open guides directory at %s." % base_dir)
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
		push_error("WindowGuide: Unable to read markdown at %s." % markdown_path)
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
