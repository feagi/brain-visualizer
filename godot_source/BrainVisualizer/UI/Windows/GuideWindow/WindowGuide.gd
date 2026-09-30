extends BaseDraggableWindow
class_name WindowGuide

const WINDOW_NAME: StringName = "guide_window"
const MIN_WINDOW_WIDTH: int = 600
const MIN_WINDOW_HEIGHT: int = 400
const DEFAULT_WINDOW_VIEWPORT_RATIO: float = 0.8

const _COLLAPSIBLE_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")
const _SECTION_TOGGLE_SIZE: int = 22

@export var guides_directory: String = "res://BrainVisualizer/Guides"

var _search_bar: LineEdit
var _topic_container: VBoxContainer
var _markdown_view: GuideMarkdownView
var _sidebar: VBoxContainer
var _font_size_decrease_btn: Button
var _font_size_increase_btn: Button
var _groups: Array[Dictionary] = []
var _active_button: GuideTopicButton
var _active_path: String = ""
var _font_size_scale: float = 1.0  # User-adjustable font scale multiplier

# Window resizing
var _resize_handle_corner: Panel
var _resize_handle_right: Panel
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_margin: int = 16
var _resize_mode: String = ""  # "corner" or "right"

## Initialize and setup the guide window.
func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_apply_default_window_size_to_viewport()
	call_deferred("_apply_default_window_size_to_viewport")
	
	# Toolbar references
	_search_bar = $WindowPanel/WindowMargin/WindowInternals/GuideToolbar/SearchBar
	_font_size_decrease_btn = $WindowPanel/WindowMargin/WindowInternals/GuideToolbar/FontSizeDecrease
	_font_size_increase_btn = $WindowPanel/WindowMargin/WindowInternals/GuideToolbar/FontSizeIncrease
	
	# Content references
	_topic_container = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideSidebar/TopicsScroll/TopicsList
	_markdown_view = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideBody/ContentScroll/ContentMargin/GuideMarkdownView
	_sidebar = $WindowPanel/WindowMargin/WindowInternals/GuideContent/GuideSidebar
	
	# Wire signals
	_search_bar.text_changed.connect(_on_search_changed)
	_markdown_view.markdown_link_clicked.connect(_on_markdown_link_clicked)
	_font_size_decrease_btn.pressed.connect(_on_decrease_font_size)
	_font_size_increase_btn.pressed.connect(_on_increase_font_size)
	
	# Style the font size buttons to show A at different sizes
	_apply_font_size_button_styles()
	
	_setup_resize_handle()
	
	_refresh_topics()
	call_deferred("_update_sidebar_width")
	resized.connect(_update_sidebar_width)

## Size the guide window to a fraction of the active BV viewport.
func _apply_default_window_size_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var visible_size: Vector2 = viewport.get_visible_rect().size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return
	var target_size: Vector2 = visible_size * DEFAULT_WINDOW_VIEWPORT_RATIO
	target_size.x = clamp(target_size.x, float(MIN_WINDOW_WIDTH), visible_size.x)
	target_size.y = clamp(target_size.y, float(MIN_WINDOW_HEIGHT), visible_size.y)
	custom_minimum_size = target_size
	size = target_size

## Style the font size buttons with different A sizes (small and large).
func _apply_font_size_button_styles() -> void:
	# Small A for decrease button
	_font_size_decrease_btn.add_theme_font_size_override("font_size", 14)
	
	# Large A for increase button
	_font_size_increase_btn.add_theme_font_size_override("font_size", 24)

## Create resize handles (bottom-right corner and right edge).
func _setup_resize_handle() -> void:
	# Bottom-right corner handle
	_resize_handle_corner = Panel.new()
	_resize_handle_corner.name = "ResizeHandleCorner"
	_resize_handle_corner.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	_resize_handle_corner.mouse_filter = Control.MOUSE_FILTER_PASS
	_resize_handle_corner.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle_corner.gui_input.connect(_on_resize_corner_gui_input)
	
	# Add visual grip indicator for corner
	var grip_icon_corner := Control.new()
	grip_icon_corner.name = "GripIconCorner"
	grip_icon_corner.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	grip_icon_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_icon_corner.draw.connect(_draw_resize_grip_corner.bind(grip_icon_corner))
	_resize_handle_corner.add_child(grip_icon_corner)
	
	add_child(_resize_handle_corner)
	_resize_handle_corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_resize_handle_corner.offset_left = -_resize_margin
	_resize_handle_corner.offset_top = -_resize_margin
	_resize_handle_corner.z_index = 1000
	
	# Right edge handle
	_resize_handle_right = Panel.new()
	_resize_handle_right.name = "ResizeHandleRight"
	_resize_handle_right.custom_minimum_size = Vector2(_resize_margin, 0)
	_resize_handle_right.mouse_filter = Control.MOUSE_FILTER_PASS
	_resize_handle_right.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_resize_handle_right.gui_input.connect(_on_resize_right_gui_input)
	
	add_child(_resize_handle_right)
	_resize_handle_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_resize_handle_right.offset_left = -_resize_margin
	_resize_handle_right.offset_right = 0
	_resize_handle_right.offset_top = 0
	_resize_handle_right.offset_bottom = -_resize_margin  # Stop before corner handle
	_resize_handle_right.z_index = 999

## Handle corner resize dragging (both width and height).
func _on_resize_corner_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resizing = true
				_resize_mode = "corner"
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_size = size
			else:
				_resizing = false
				_resize_mode = ""
	
	elif event is InputEventMouseMotion and _resizing and _resize_mode == "corner":
		var delta := get_global_mouse_position() - _resize_start_mouse
		var new_size := _resize_start_size + delta
		
		# Enforce minimum size
		new_size.x = max(new_size.x, MIN_WINDOW_WIDTH)
		new_size.y = max(new_size.y, MIN_WINDOW_HEIGHT)
		
		size = new_size
		custom_minimum_size = new_size

## Handle right edge resize dragging (width only).
func _on_resize_right_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resizing = true
				_resize_mode = "right"
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_size = size
			else:
				_resizing = false
				_resize_mode = ""
	
	elif event is InputEventMouseMotion and _resizing and _resize_mode == "right":
		var delta := get_global_mouse_position() - _resize_start_mouse
		var new_size := _resize_start_size
		new_size.x += delta.x  # Only change width
		
		# Enforce minimum width
		new_size.x = max(new_size.x, MIN_WINDOW_WIDTH)
		
		size = new_size
		custom_minimum_size = new_size

## Draw resize grip indicator in bottom-right corner.
func _draw_resize_grip_corner(control: Control) -> void:
	var grip_color := Color(0.6, 0.6, 0.6, 0.9)
	var square_size := 8
	
	# Draw square at the right side of the control
	var x_pos := _resize_margin - square_size
	var y_pos := (_resize_margin - square_size) / 2.0
	
	var rect := Rect2(Vector2(x_pos, y_pos), Vector2(square_size, square_size))
	control.draw_rect(rect, grip_color, true)

## Load markdown topics from disk and populate the sidebar.
## Each file is one collapsible topic. Each `##` section is a child button.
func _refresh_topics() -> void:
	_groups.clear()
	_active_button = null
	_active_path = ""
	for child in _topic_container.get_children():
		child.queue_free()
	var markdown_files := _collect_markdown_files(guides_directory)
	for markdown_path in markdown_files:
		var content := _read_file_content(markdown_path)
		var outline: Dictionary = GuideMarkdownView.extract_outline(content)
		var group := _add_topic_group(str(outline["title"]), markdown_path)
		var sections: Array[Dictionary] = []
		for section in outline["sections"]:
			var button := GuideTopicButton.new()
			var heading := str(section["heading"])
			group["holder"].add_child(button)
			button.setup(str(section["title"]), markdown_path, heading, true)
			button.topic_selected.connect(_on_section_selected)
			sections.append({
				"title": str(section["title"]),
				"heading": heading,
				"body": str(section["body"]).to_lower(),
				"button": button,
			})
		group["sections"] = sections
		_groups.append(group)
	if _groups.is_empty():
		_markdown_view.show_message("No guide topics found.")
		return
	var first_sections: Array = _groups[0]["sections"]
	if first_sections.is_empty():
		_open_markdown(_groups[0]["path"])
		return
	var first_section: Dictionary = first_sections[0]
	_activate_section(_groups[0]["path"], str(first_section["heading"]))


## Build one cortical-style expander for a guide file.
func _add_topic_group(title: String, markdown_path: String) -> Dictionary:
	var collapsible: VerticalCollapsibleHiding = _COLLAPSIBLE_PREFAB.instantiate()
	collapsible.section_text = StringName(title)
	collapsible.start_open = false
	collapsible.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collapsible.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var title_label: Label = collapsible.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
	title_label.text = title
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var toggle: TextureButton = collapsible.get_node("VerticalCollapsible/HBoxContainer/Collapsible_Toggle")
	toggle.custom_minimum_size = Vector2(_SECTION_TOGGLE_SIZE, _SECTION_TOGGLE_SIZE)
	_topic_container.add_child(collapsible)
	var header_size := title_label.get_theme_font_size("font_size", "Label_Header")
	if header_size > 0:
		title_label.add_theme_font_size_override("font_size", header_size)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 2)
	collapsible.get_control().add_child(holder)
	return {
		"title": title,
		"path": markdown_path,
		"section": collapsible,
		"holder": holder,
		"sections": [],
	}

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

## Filter sections by title or body. A matching topic title shows all of its sections.
func _on_search_changed(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	var visible_count := 0
	for group in _groups:
		var group_title := str(group["title"]).to_lower()
		var group_match := normalized != "" and group_title.find(normalized) >= 0
		var any_section := false
		var sections: Array = group["sections"]
		for section in sections:
			var button: GuideTopicButton = section["button"]
			var show := normalized == "" or group_match
			if not show:
				show = str(section["title"]).to_lower().find(normalized) >= 0
			if not show:
				show = str(section["body"]).find(normalized) >= 0
			button.visible = show
			if show:
				any_section = true
				visible_count += 1
		var section_node: VerticalCollapsibleHiding = group["section"]
		section_node.visible = any_section
		if normalized != "":
			section_node.is_open = any_section
		else:
			section_node.is_open = str(group["path"]) == _active_path
	if normalized != "":
		_search_bar.placeholder_text = "Search guides... (%d results)" % visible_count
	else:
		_search_bar.placeholder_text = "Search guides..."

## Open the selected guide section.
func _on_section_selected(markdown_path: String, heading: String) -> void:
	_activate_section(markdown_path, heading)

## Resolve markdown links to other guide files.
func _on_markdown_link_clicked(target_path: String) -> void:
	if _is_markdown_path(target_path):
		_activate_section(target_path, "")

## Open a guide file by filename (e.g. ``pattern_connectivity.md``).
## `heading` scrolls the page to that markdown heading after it loads.
func open_guide_file(guide_filename: String, heading: String = "") -> void:
	var file_name := guide_filename.get_file()
	if file_name.get_extension() == "":
		file_name = file_name + ".md"
	var markdown_path := guides_directory.path_join(file_name)
	# Help jumps here after setup has already expanded the first topic.
	# Leave only the requested topic open.
	for group in _groups:
		if str(group["path"]) == markdown_path:
			continue
		var section_node: VerticalCollapsibleHiding = group["section"]
		section_node.is_open = false
	_activate_section(markdown_path, heading)

## Expand the topic and show `heading`. An empty heading shows the top of the page.
func _activate_section(markdown_path: String, heading: String) -> void:
	_active_path = markdown_path
	for group in _groups:
		if str(group["path"]) != markdown_path:
			continue
		var section_node: VerticalCollapsibleHiding = group["section"]
		section_node.visible = true
		section_node.is_open = true
		var sidebar_heading := GuideMarkdownView.enclosing_section_heading(group["sections"], heading)
		var matched := false
		for section in group["sections"]:
			if sidebar_heading == "" or str(section["heading"]) != sidebar_heading:
				continue
			_set_active_button(section["button"])
			_reveal_sidebar_button(section["button"])
			matched = true
			break
		if not matched:
			_set_active_button(null)
		_open_markdown(markdown_path, heading)
		return
	_set_active_button(null)
	_open_markdown(markdown_path, heading)


## Keep the highlighted chapter inside the sidebar scroll area.
func _reveal_sidebar_button(button: Control) -> void:
	var scroll := _topic_container.get_parent()
	if scroll is ScrollContainer:
		(scroll as ScrollContainer).ensure_control_visible.call_deferred(button)


func _set_active_button(button: GuideTopicButton) -> void:
	if _active_button != null and is_instance_valid(_active_button):
		_active_button.set_selected(false)
	_active_button = button
	if button != null:
		button.set_selected(true)

## Load and display a markdown file.
func _open_markdown(markdown_path: String, heading: String = "") -> void:
	if markdown_path == "":
		push_error("WindowGuide: Empty markdown path")
		return
	if not FileAccess.file_exists(markdown_path):
		push_error("WindowGuide: Markdown path not found: %s" % markdown_path)
		_markdown_view.show_message("Guide file not found: %s" % markdown_path)
		return
	_markdown_view.load_markdown(markdown_path, heading)

## Load guide order from the _guide_order.txt file
func _load_guide_order(base_dir: String) -> Array[String]:
	var order_file_path := base_dir.path_join("_guide_order.txt")
	var ordered_filenames: Array[String] = []
	
	if not FileAccess.file_exists(order_file_path):
		push_warning("WindowGuide: Order file not found at %s. Using alphabetical order." % order_file_path)
		return ordered_filenames
	
	var file := FileAccess.open(order_file_path, FileAccess.READ)
	if file == null:
		push_error("WindowGuide: Unable to read order file at %s." % order_file_path)
		return ordered_filenames
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		# Skip empty lines and comments
		if line == "" or line.begins_with("#"):
			continue
		ordered_filenames.append(line)
	
	return ordered_filenames

## Collect all markdown files within the guides directory.
## Uses ResourceLoader.list_directory() so guides are found in the exported app (.pck);
## DirAccess.open(res://...) does not list files correctly in exported builds.
func _collect_markdown_files(base_dir: String) -> Array[String]:
	# Load the desired order from _guide_order.txt
	var ordered_filenames := _load_guide_order(base_dir)

	var results: Array[String] = []
	# ResourceLoader.list_directory() works in exported games (pck); DirAccess does not.
	var names: PackedStringArray = ResourceLoader.list_directory(base_dir)
	if names.is_empty():
		# Fallback for editor or older engine: try DirAccess (editor only)
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
	else:
		for name in names:
			if name == "." or name == "..":
				continue
			var path := base_dir.path_join(name)
			# list_directory returns both files and dirs; skip dirs (no extension or not .md)
			if _is_markdown_path(path):
				results.append(path)

	# Sort by custom order, then alphabetically for any not in the list
	results.sort_custom(func(a: String, b: String) -> bool:
		var a_name := a.get_file()
		var b_name := b.get_file()
		var a_index := ordered_filenames.find(a_name)
		var b_index := ordered_filenames.find(b_name)

		# If both are in the ordered list, sort by their position
		if a_index >= 0 and b_index >= 0:
			return a_index < b_index
		# If only a is in the ordered list, it comes first
		if a_index >= 0:
			return true
		# If only b is in the ordered list, it comes first
		if b_index >= 0:
			return false
		# If neither are in the ordered list, sort alphabetically
		return a_name < b_name
	)

	return results

## Read the full content of a markdown file.
func _read_file_content(markdown_path: String) -> String:
	var file := FileAccess.open(markdown_path, FileAccess.READ)
	if file == null:
		push_error("WindowGuide: Unable to read markdown content at %s." % markdown_path)
		return ""
	var content := file.get_as_text()
	file.close()
	return content

## Check if a path points to a markdown file.
func _is_markdown_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension == "md" or extension == "markdown"

## Increase the font size scale for markdown content.
func _on_increase_font_size() -> void:
	_font_size_scale += 0.1
	_font_size_scale = min(_font_size_scale, 2.0)  # Max 2x scale
	_markdown_view.set_font_scale(_font_size_scale)

## Decrease the font size scale for markdown content.
func _on_decrease_font_size() -> void:
	_font_size_scale -= 0.1
	_font_size_scale = max(_font_size_scale, 0.5)  # Min 0.5x scale
	_markdown_view.set_font_scale(_font_size_scale)
