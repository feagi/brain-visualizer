extends BaseDraggableWindow
class_name WindowGenomeChangeHistory
## Session table of genome changes from this member and teammates.
##
## Opens wide enough for Time, Who, Target, and Action on one line. The right
## edge, bottom edge, and corner drag to resize. Who is bold and colored. The
## cortical name is colored and uses the normal weight.

const WINDOW_NAME: StringName = "genome_change_history"
## Smallest size the user can drag to. Four columns still fit.
const MIN_WINDOW_SIZE: Vector2 = Vector2(720, 400)
## Size used on a normal display.
const OPENING_PREFERRED: Vector2 = Vector2(920, 560)
## Cap so a very large display does not open the list across the whole screen.
const OPENING_MAX: Vector2 = Vector2(1200, 760)
const OPENING_WIDTH_RATIO: float = 0.55
const OPENING_HEIGHT_RATIO: float = 0.62
const OPENING_EDGE_MARGIN: float = 48.0
const _RESIZE_EDGE: float = 14.0
const _TIME_SAMPLE: String = "0000-00-00 00:00:00"
const _ACTION_WIDTH: float = 240.0
const _TARGET_WIDTH: float = 180.0
const _WHO_COLOR: Color = Color("8ab4f8")
const _TARGET_COLOR: Color = Color("f5bd6b")

var _rows: VBoxContainer
var _header_time: Label
var _header_who: Label
var _scroll: ScrollContainer
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_edge: String = ""
var _chosen_size: Vector2 = Vector2.ZERO
var _opening_applied: bool = false


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Change history"
	_apply_opening_size()
	call_deferred("_apply_opening_size")
	_setup_resize_handle()
	_window_internals.add_child(_header_row())
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.14)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_internals.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_window_internals.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	if events != null:
		events.change_history_changed.connect(_refresh)
		events.mark_change_history_seen()
	_refresh()


func _exit_tree() -> void:
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	if events != null and events.has_method("mark_history_window_closed"):
		events.mark_history_window_closed()


## Keep the size the user chose. The base window would otherwise collapse this control.
func _delay_shrink_window() -> void:
	if _chosen_size.x <= 0.0 or _chosen_size.y <= 0.0:
		_apply_opening_size()
		return
	_apply_window_size(_chosen_size)


func _input(event: InputEvent) -> void:
	if _resizing:
		if event is InputEventMouseMotion:
			_apply_resize_drag()
			accept_event()
			return
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_resizing = false
			_resize_edge = ""
			accept_event()
			return
	super._input(event)


func _apply_opening_size() -> void:
	if _resizing or _opening_applied:
		return
	var viewport_size := _viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target := opening_window_size(viewport_size)
	_apply_window_size(target)
	_opening_applied = true
	var pos := Vector2(position)
	pos.x = clampf(pos.x, 0.0, maxf(viewport_size.x - target.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(viewport_size.y - target.y, 0.0))
	position = Vector2i(roundi(pos.x), roundi(pos.y))


func _apply_window_size(new_size: Vector2) -> void:
	_chosen_size = new_size
	custom_minimum_size = Vector2(
		minf(MIN_WINDOW_SIZE.x, new_size.x),
		minf(MIN_WINDOW_SIZE.y, new_size.y),
	)
	size = new_size


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size


## Preferred history size for a viewport. Stays inside the screen.
static func opening_window_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return OPENING_PREFERRED
	var max_width := minf(viewport_size.x, maxf(viewport_size.x - OPENING_EDGE_MARGIN, 1.0))
	var max_height := minf(viewport_size.y, maxf(viewport_size.y - OPENING_EDGE_MARGIN, 1.0))
	var width := minf(maxf(OPENING_PREFERRED.x, viewport_size.x * OPENING_WIDTH_RATIO), OPENING_MAX.x)
	var height := minf(maxf(OPENING_PREFERRED.y, viewport_size.y * OPENING_HEIGHT_RATIO), OPENING_MAX.y)
	return Vector2(minf(width, max_width), minf(height, max_height))


## Size after a drag. `edge` is "right", "bottom", or "corner".
static func resized_window_size(start: Vector2, delta: Vector2, edge: String, viewport_size: Vector2) -> Vector2:
	var new_size := start
	if edge == "right" or edge == "corner":
		new_size.x += delta.x
	if edge == "bottom" or edge == "corner":
		new_size.y += delta.y
	var max_width := viewport_size.x if viewport_size.x > 0.0 else new_size.x
	var max_height := viewport_size.y if viewport_size.y > 0.0 else new_size.y
	new_size.x = clampf(new_size.x, minf(MIN_WINDOW_SIZE.x, max_width), max_width)
	new_size.y = clampf(new_size.y, minf(MIN_WINDOW_SIZE.y, max_height), max_height)
	return new_size


func _setup_resize_handle() -> void:
	var overlay := Control.new()
	overlay.name = "ResizeOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 20
	_window_panel.add_child(overlay)
	_add_resize_edge(overlay, "ResizeHandleRight", "right", Control.CURSOR_HSIZE, Control.PRESET_RIGHT_WIDE, Vector2(-_RESIZE_EDGE, 0), Vector2(0, -_RESIZE_EDGE))
	_add_resize_edge(overlay, "ResizeHandleBottom", "bottom", Control.CURSOR_VSIZE, Control.PRESET_BOTTOM_WIDE, Vector2(0, -_RESIZE_EDGE), Vector2(-_RESIZE_EDGE, 0))
	var corner := _add_resize_edge(overlay, "ResizeHandleCorner", "corner", Control.CURSOR_FDIAGSIZE, Control.PRESET_BOTTOM_RIGHT, Vector2(-_RESIZE_EDGE, -_RESIZE_EDGE), Vector2.ZERO)
	var grip := Control.new()
	grip.name = "GripIconCorner"
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.set_anchors_preset(Control.PRESET_FULL_RECT)
	grip.draw.connect(_draw_resize_grip_corner.bind(grip))
	corner.add_child(grip)


func _add_resize_edge(overlay: Control, edge_name: String, edge: String, cursor: Control.CursorShape, preset: Control.LayoutPreset, offset_min: Vector2, offset_max: Vector2) -> Control:
	var handle := Control.new()
	handle.name = edge_name
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = cursor
	overlay.add_child(handle)
	handle.set_anchors_preset(preset)
	handle.offset_left = offset_min.x
	handle.offset_top = offset_min.y
	handle.offset_right = offset_max.x
	handle.offset_bottom = offset_max.y
	handle.gui_input.connect(_on_resize_edge_gui_input.bind(edge))
	return handle


func _on_resize_edge_gui_input(event: InputEvent, edge: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_resizing = true
		_resize_edge = edge
		_resize_start_mouse = get_global_mouse_position()
		_resize_start_size = size
		accept_event()
		return
	_resizing = false
	_resize_edge = ""
	accept_event()


func _apply_resize_drag() -> void:
	var delta := get_global_mouse_position() - _resize_start_mouse
	_apply_window_size(resized_window_size(_resize_start_size, delta, _resize_edge, _viewport_size()))


func _draw_resize_grip_corner(control: Control) -> void:
	var grip_color := Color(0.75, 0.78, 0.82, 0.9)
	var inset := 3.0
	control.draw_line(Vector2(inset, _RESIZE_EDGE - inset), Vector2(_RESIZE_EDGE - inset, inset), grip_color, 1.5)
	control.draw_line(Vector2(inset + 4.0, _RESIZE_EDGE - inset), Vector2(_RESIZE_EDGE - inset, inset + 4.0), grip_color, 1.5)


func _refresh() -> void:
	if _rows == null:
		return
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	for child in _rows.get_children():
		child.queue_free()
	var history: Array = []
	if events != null:
		history = events.change_history
	if history.is_empty():
		var empty := Label.new()
		empty.text = "No genome changes yet."
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(empty)
		return
	var time_width := _time_column_width()
	var who_width := _who_column_width(history)
	if _header_time != null:
		_header_time.custom_minimum_size.x = time_width
	if _header_who != null:
		_header_who.custom_minimum_size.x = who_width
	for index in range(history.size() - 1, -1, -1):
		var event: Dictionary = history[index]
		var shown := event.duplicate()
		shown["target_id"] = _target_text(event)
		_rows.add_child(_data_row(TeamBranchText.history_columns(shown), time_width, who_width))


func _header_row() -> HBoxContainer:
	var row := _column_row()
	var header_color := Color(0.62, 0.66, 0.72)
	_header_time = _plain_cell("Time", _time_column_width(), false, false, header_color)
	row.add_child(_header_time)
	_header_who = _plain_cell("Who", _measure_text("Who", true), false, false, header_color)
	row.add_child(_header_who)
	row.add_child(_plain_cell("Target", _TARGET_WIDTH, true, false, header_color))
	row.add_child(_plain_cell("Action", _ACTION_WIDTH, true, false, header_color))
	return row


func _data_row(columns: Dictionary, time_width: float, who_width: float) -> HBoxContainer:
	var row := _column_row()
	row.add_child(_plain_cell(str(columns.get("time", "")), time_width, false, false, Color(0.82, 0.84, 0.88)))
	row.add_child(_plain_cell(str(columns.get("who", "")), who_width, false, true, _WHO_COLOR))
	row.add_child(_plain_cell(str(columns.get("target", "")), _TARGET_WIDTH, true, false, _TARGET_COLOR))
	row.add_child(_plain_cell(str(columns.get("action", "")), _ACTION_WIDTH, true, false, Color(0.9, 0.91, 0.93)))
	return row


func _column_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	return row


func _plain_cell(text: String, min_width: float, expand: bool, bold: bool, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if expand else TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(min_width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", color)
	if bold:
		var base := get_theme_font("font", "Label")
		if base != null:
			var heavy := FontVariation.new()
			heavy.base_font = base
			heavy.variation_embolden = 1.0
			label.add_theme_font_override("font", heavy)
	return label


func _time_column_width() -> float:
	return _measure_text(_TIME_SAMPLE, false)


## Who is one line. The column is as wide as the longest name so the text is not clipped.
func _who_column_width(history: Array) -> float:
	var widest := _measure_text("Who", true)
	for event in history:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		widest = maxf(widest, _measure_text(str(TeamBranchText.history_columns(event).get("who", "")), true))
	return widest


func _measure_text(text: String, bold: bool) -> float:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	if font == null or text.strip_edges() == "":
		return 48.0
	var measured := font
	if bold:
		var heavy := FontVariation.new()
		heavy.base_font = font
		heavy.variation_embolden = 1.0
		measured = heavy
	return measured.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0


## Prefer a stored name. Otherwise use the live area or region name for each id.
func _target_text(event: Dictionary) -> String:
	var label := str(event.get("target_id", "")).strip_edges()
	var ids: Array = event.get("target_ids", [])
	if ids.is_empty() and TeamBranchText.looks_like_cortical_id(label):
		ids = [label]
	var resolved := _names_for_ids(ids)
	var operation := str(event.get("operation", ""))
	var is_link := operation == "update_cortical_mapping" or operation == "rekey_memory_twin_source"
	if is_link and resolved.size() >= 2:
		return "%s → %s" % [resolved[0], resolved[1]]
	if label != "" and not TeamBranchText.looks_like_cortical_id(label) and label != "a cortical area" and label != "a connection":
		return label
	if resolved.size() > 0:
		return ", ".join(resolved)
	if label != "":
		return label
	return "the genome"


func _names_for_ids(ids: Array) -> PackedStringArray:
	var names := PackedStringArray()
	var found_real := false
	for raw_id in ids:
		var cached := _cached_name(str(raw_id))
		if cached == "":
			names.append("a cortical area")
			continue
		names.append(cached)
		found_real = true
	if not found_real:
		return PackedStringArray()
	return names


func _cached_name(element_id: String) -> String:
	var core := get_node_or_null("/root/FeagiCore")
	if core == null:
		return ""
	var cache = core.get("feagi_local_cache")
	if cache == null:
		return ""
	var areas = cache.get("cortical_areas")
	if areas != null:
		var area_table = areas.get("available_cortical_areas")
		if typeof(area_table) == TYPE_DICTIONARY and element_id in area_table:
			var area_name := str(area_table[element_id].get("friendly_name")).strip_edges()
			if area_name != "" and area_name != "<null>":
				return area_name
	var regions = cache.get("brain_regions")
	if regions != null:
		var region_table = regions.get("available_brain_regions")
		if typeof(region_table) == TYPE_DICTIONARY and element_id in region_table:
			var region_name := str(region_table[element_id].get("friendly_name")).strip_edges()
			if region_name != "" and region_name != "<null>":
				return region_name
	return ""

