extends BaseDraggableWindow
class_name WindowKeybinds
## Table of keyboard shortcuts. K opens and closes it. Escape closes it.


const WINDOW_NAME: StringName = "keybinds"
const OPENING_PREFERRED: Vector2 = Vector2(860, 640)
const OPENING_MAX: Vector2 = Vector2(1100, 820)
const MIN_WINDOW_SIZE: Vector2 = Vector2(640, 360)
const VIEWPORT_MARGIN: float = 48.0
const VERTICAL_BIAS: float = 0.18

const _SHORTCUT_WIDTH: float = 230.0
const _CONTEXT_WIDTH: float = 240.0
const _HEADER_COLOR := Color(0.62, 0.66, 0.72)
const _SHORTCUT_COLOR := Color(0.93, 0.94, 0.96)
const _ACTION_COLOR := Color(0.9, 0.91, 0.93)
const _CONTEXT_COLOR := Color(0.75, 0.78, 0.82)
const _SECTION_COLOR := Color(0.55, 0.72, 0.9)
const _RESIZE_EDGE: float = 14.0

var _chosen_size: Vector2 = Vector2.ZERO
var _opening_applied: bool = false
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_edge: String = ""


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Keyboard shortcuts"
	_build_table()
	_apply_opening_size()
	_setup_resize_handle()


## Preferred size for a viewport. Stays inside the screen.
static func opening_window_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return OPENING_PREFERRED
	var width := minf(OPENING_PREFERRED.x, maxf(viewport_size.x - VIEWPORT_MARGIN, 1.0))
	var height := minf(OPENING_PREFERRED.y, maxf(viewport_size.y - VIEWPORT_MARGIN, 1.0))
	width = minf(width, OPENING_MAX.x)
	height = minf(height, OPENING_MAX.y)
	return Vector2(width, height)


## Top-left that places the window in the upper center of [param viewport_size].
static func centered_top_left(viewport_size: Vector2, window_size: Vector2) -> Vector2:
	return Vector2(
		maxf(0.0, (viewport_size.x - window_size.x) * 0.5),
		maxf(0.0, (viewport_size.y - window_size.y) * VERTICAL_BIAS)
	)


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


## Keep the size chosen for this open. The base window would otherwise collapse it.
func _delay_shrink_window() -> void:
	if _chosen_size.x <= 0.0 or _chosen_size.y <= 0.0:
		_apply_opening_size()
		return
	_apply_window_size(_chosen_size)


func _build_table() -> void:
	if _window_internals.get_node_or_null("ShortcutHeader") != null:
		return
	_window_internals.add_theme_constant_override("separation", 6)
	var header := _column_row()
	header.name = "ShortcutHeader"
	header.add_child(_cell("Shortcut", _SHORTCUT_WIDTH, false, true, _HEADER_COLOR))
	header.add_child(_cell("Action", 0.0, true, true, _HEADER_COLOR))
	header.add_child(_cell("Where", _CONTEXT_WIDTH, false, true, _HEADER_COLOR))
	_window_internals.add_child(header)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.16)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_internals.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.name = "ShortcutScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_window_internals.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "ShortcutRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	var current_section := ""
	for entry in KeybindCatalog.entries():
		var section := String(entry[KeybindCatalog.KEY_SECTION])
		if section != current_section:
			current_section = section
			rows.add_child(_section_label(section))
		var row := _column_row()
		row.add_child(_cell(String(entry[KeybindCatalog.KEY_KEYS]), _SHORTCUT_WIDTH, false, true, _SHORTCUT_COLOR))
		row.add_child(_cell(String(entry[KeybindCatalog.KEY_ACTION]), 0.0, true, false, _ACTION_COLOR))
		row.add_child(_cell(String(entry[KeybindCatalog.KEY_CONTEXT]), _CONTEXT_WIDTH, false, false, _CONTEXT_COLOR))
		rows.add_child(row)


func _section_label(section: String) -> Label:
	var label := Label.new()
	label.set_meta(&"section_title", true)
	label.text = section
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", _SECTION_COLOR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_apply_section_title_size(label)
	var base := get_theme_font("font", "Label")
	if base != null:
		var heavy := FontVariation.new()
		heavy.base_font = base
		heavy.variation_embolden = 0.8
		label.add_theme_font_override("font", heavy)
	return label


## Section titles stay larger than the shortcut rows at every UI scale.
func _apply_section_title_size(label: Label) -> void:
	var body_size := get_theme_font_size("font_size", "Label")
	if body_size <= 0:
		body_size = 16
	var title_size := int(round(float(body_size) * 1.5))
	label.add_theme_font_size_override("font_size", title_size)
	label.custom_minimum_size = Vector2(0, title_size + 16)


func _theme_updated(new_theme: Theme) -> void:
	super._theme_updated(new_theme)
	var rows := find_child("ShortcutRows", true, false) as VBoxContainer
	if rows == null:
		return
	for child in rows.get_children():
		if child is Label and (child as Label).has_meta(&"section_title"):
			_apply_section_title_size(child as Label)


func _column_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	return row


func _cell(text: String, min_width: float, expand: bool, bold: bool, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size = Vector2(min_width, 0)
	label.add_theme_color_override("font_color", color)
	if bold:
		var base := get_theme_font("font", "Label")
		if base != null:
			var heavy := FontVariation.new()
			heavy.base_font = base
			heavy.variation_embolden = 0.8
			label.add_theme_font_override("font", heavy)
	return label


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


func _setup_resize_handle() -> void:
	if _window_panel.get_node_or_null("ResizeOverlay") != null:
		return
	var overlay := Control.new()
	overlay.name = "ResizeOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 20
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
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


func _apply_opening_size() -> void:
	if _resizing or _opening_applied:
		return
	var viewport_size := _viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target := opening_window_size(viewport_size)
	_apply_window_size(target)
	var top_left := centered_top_left(viewport_size, target)
	position = Vector2i(roundi(top_left.x), roundi(top_left.y))
	_opening_applied = true


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
