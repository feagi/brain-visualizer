extends BaseDraggableWindow
class_name WindowGlobalSearch
## Floating genome search. Ctrl/Cmd+S opens and closes it.
##
## The field stays focused. Arrow keys move the highlight. Enter or a click
## runs the same action as the matching top-bar list.

const WINDOW_NAME: StringName = "global_search"
const OPENING_PREFERRED: Vector2 = Vector2(460, 520)
const OPENING_MAX: Vector2 = Vector2(640, 760)
const MIN_WINDOW_SIZE: Vector2 = Vector2(360, 280)
const VIEWPORT_MARGIN: float = 48.0
## Sits in the upper part of the screen so the list has room under the field.
const VERTICAL_BIAS: float = 0.22

const _ROW_SELECTED := Color(0.45, 0.62, 0.86, 0.34)
const _ROW_HOVER := Color(1.0, 1.0, 1.0, 0.08)
const _CHIP_RADIUS: int = 10
const _ROW_RADIUS: int = 6

var _search_line: LineEdit
var _empty_label: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _visible_entries: Array[Dictionary] = []
var _selected_index: int = 0
var _hover_index: int = -1
var _chosen_size: Vector2 = Vector2.ZERO
var _opening_applied: bool = false
var _activated: bool = false


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Search"
	_build_controls()
	_apply_opening_size()
	_refresh_results()
	call_deferred("_focus_search_field")


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


## Keep the size chosen for this open. The base window would otherwise collapse it.
func _delay_shrink_window() -> void:
	if _chosen_size.x <= 0.0 or _chosen_size.y <= 0.0:
		_apply_opening_size()
		return
	_apply_window_size(_chosen_size)


func _input(event: InputEvent) -> void:
	if _handle_search_key(event):
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			if BV != null and BV.UI != null and BV.UI.stop_visible_inspector_on_escape(key):
				accept_event()
				return
			accept_event()
			close_window()
			return
	super._input(event)


func _build_controls() -> void:
	if _window_internals.get_node_or_null("SearchLine") != null:
		return
	_window_internals.add_theme_constant_override("separation", 8)
	_search_line = LineEdit.new()
	_search_line.name = "SearchLine"
	_search_line.placeholder_text = "Search by name"
	_search_line.clear_button_enabled = true
	_search_line.text_changed.connect(_refresh_results)
	_search_line.text_submitted.connect(_on_search_submitted)
	_window_internals.add_child(_search_line)
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window_internals.add_child(_empty_label)
	_scroll = ScrollContainer.new()
	_scroll.name = "Results"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_window_internals.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "ResultRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)


func focus_search() -> void:
	call_deferred("_focus_search_field")


func _focus_search_field() -> void:
	if _search_line != null and is_instance_valid(_search_line):
		_search_line.grab_focus()


func _apply_opening_size() -> void:
	if _opening_applied:
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


func _refresh_results(_query: String = "") -> void:
	if _search_line == null or _rows == null:
		return
	var cache: FEAGILocalCache = null
	if FeagiCore != null:
		cache = FeagiCore.feagi_local_cache
	var entries := GlobalSearchCatalog.entries_from_cache(cache)
	_visible_entries = GlobalSearchCatalog.filter_entries(entries, _search_line.text)
	_selected_index = 0
	_hover_index = -1
	_clear_rows()
	for index in _visible_entries.size():
		var entry: Dictionary = _visible_entries[index]
		var kind: StringName = entry[GlobalSearchCatalog.KEY_KIND]
		_rows.add_child(_make_row(index, String(entry[GlobalSearchCatalog.KEY_LABEL]), kind))
	var query_empty := _search_line.text.strip_edges().is_empty()
	_empty_label.visible = _visible_entries.is_empty()
	_scroll.visible = not _visible_entries.is_empty()
	if _visible_entries.is_empty():
		_empty_label.text = "Type a name" if query_empty else "No matches"
		return
	_paint_rows()
	call_deferred("_reveal_selection")


func _on_search_submitted(_text: String) -> void:
	_activate_index(_selected_index)


## Arrow keys and Enter belong to the field only while it has focus, so the 3D camera keeps them otherwise.
func _search_has_keyboard() -> bool:
	var viewport := get_viewport()
	if viewport == null or _search_line == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	if focus_owner == null:
		return false
	return focus_owner == _search_line or _search_line.is_ancestor_of(focus_owner)


func _handle_search_key(event: InputEvent) -> bool:
	if not _search_has_keyboard():
		return false
	if not (event is InputEventKey) or not event.pressed:
		return false
	var key := event as InputEventKey
	if key.keycode == KEY_UP:
		_move_selection(-1)
		return true
	if key.keycode == KEY_DOWN:
		_move_selection(1)
		return true
	if key.echo:
		return false
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_activate_index(_selected_index)
		return true
	return false


func _move_selection(delta: int) -> void:
	if _visible_entries.is_empty() or _rows == null:
		return
	_selected_index = clampi(_selected_index + delta, 0, _visible_entries.size() - 1)
	_paint_rows()
	_reveal_selection()


func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()


## Kind chip, then the matched name. The chip color comes from the catalog.
func _make_row(index: int, label: String, kind: StringName) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "ResultRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(index))
	row.mouse_entered.connect(_on_row_hover.bind(index, true))
	row.mouse_exited.connect(_on_row_hover.bind(index, false))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	line.add_child(_make_chip(kind))
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	row.add_child(line)
	return row


func _make_chip(kind: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plate := StyleBoxFlat.new()
	plate.bg_color = GlobalSearchCatalog.kind_chip_color(kind)
	plate.set_corner_radius_all(_CHIP_RADIUS)
	plate.content_margin_left = 8.0
	plate.content_margin_right = 8.0
	plate.content_margin_top = 1.0
	plate.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", plate)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = GlobalSearchCatalog.kind_title(kind)
	title.add_theme_color_override("font_color", GlobalSearchCatalog.kind_chip_ink())
	chip.add_child(title)
	return chip


func _on_row_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_activate_index(index)


func _on_row_hover(index: int, inside: bool) -> void:
	if inside:
		_hover_index = index
	elif _hover_index == index:
		_hover_index = -1
	_paint_rows()


func _paint_rows() -> void:
	if _rows == null:
		return
	for index in _rows.get_child_count():
		var row := _rows.get_child(index) as PanelContainer
		if row == null:
			continue
		row.add_theme_stylebox_override("panel", _row_plate(index))


func _row_plate(index: int) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.set_corner_radius_all(_ROW_RADIUS)
	plate.content_margin_left = 4.0
	plate.content_margin_right = 6.0
	plate.content_margin_top = 3.0
	plate.content_margin_bottom = 3.0
	if index == _selected_index:
		plate.bg_color = _ROW_SELECTED
	elif index == _hover_index:
		plate.bg_color = _ROW_HOVER
	else:
		plate.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return plate


func _reveal_selection() -> void:
	if _scroll == null or _rows == null:
		return
	if _selected_index < 0 or _selected_index >= _rows.get_child_count():
		return
	var row := _rows.get_child(_selected_index) as Control
	if row != null:
		_scroll.ensure_control_visible(row)


func _activate_index(index: int) -> void:
	if _activated or index < 0 or index >= _visible_entries.size():
		return
	_activated = true
	var chosen: Dictionary = _visible_entries[index]
	var action: StringName = chosen.get(GlobalSearchCatalog.KEY_ACTION, &"")
	var payload: Variant = chosen.get(GlobalSearchCatalog.KEY_PAYLOAD, null)
	close_window()
	_run_action(action, payload)


func _run_action(action: StringName, payload: Variant) -> void:
	match action:
		GlobalSearchCatalog.ACTION_FOCUS_AREA:
			var area := payload as AbstractCorticalArea
			if area != null and BV != null and BV.UI != null:
				BV.UI.focus_searched_cortical_area(area)
		GlobalSearchCatalog.ACTION_FOCUS_REGION:
			var region := payload as BrainRegion
			if region != null and BV != null and BV.UI != null and BV.UI.top_bar != null:
				BV.UI.top_bar.focus_menu_region(region)
		GlobalSearchCatalog.ACTION_OPEN_RULE:
			var morphology := payload as BaseMorphology
			if morphology != null and BV != null and BV.WM != null:
				BV.WM.spawn_manager_morphology(morphology)
		GlobalSearchCatalog.ACTION_OPEN_CLASSIFIER:
			var classifier := payload as GenomeClassifier
			if classifier != null and BV != null and BV.WM != null:
				BV.WM.spawn_edit_classifier(classifier)
