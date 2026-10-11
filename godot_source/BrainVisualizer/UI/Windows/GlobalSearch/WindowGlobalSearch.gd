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

var _search_line: LineEdit
var _empty_label: Label
var _list: ItemList
var _visible_entries: Array[Dictionary] = []
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
	_list = ItemList.new()
	_list.name = "Results"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_clicked.connect(_on_item_clicked)
	_list.item_activated.connect(_activate_index)
	_window_internals.add_child(_list)


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
	if _search_line == null or _list == null:
		return
	var cache: FEAGILocalCache = null
	if FeagiCore != null:
		cache = FeagiCore.feagi_local_cache
	var entries := GlobalSearchCatalog.entries_from_cache(cache)
	_visible_entries = GlobalSearchCatalog.filter_entries(entries, _search_line.text)
	_list.clear()
	for entry in _visible_entries:
		_list.add_item(GlobalSearchCatalog.result_text(String(entry[GlobalSearchCatalog.KEY_LABEL]), entry[GlobalSearchCatalog.KEY_KIND]))
	var query_empty := _search_line.text.strip_edges().is_empty()
	_empty_label.visible = _visible_entries.is_empty()
	_list.visible = not _visible_entries.is_empty()
	if _visible_entries.is_empty():
		_empty_label.text = "Type a name" if query_empty else "No matches"
		return
	_list.select(0)
	_list.ensure_current_is_visible()


func _on_search_submitted(_text: String) -> void:
	var selected := _list.get_selected_items()
	var index := 0 if selected.is_empty() else selected[0]
	_activate_index(index)


func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	_activate_index(index)


## Arrow keys and Enter belong to the field only while it has focus, so the 3D camera keeps them otherwise.
func _search_has_keyboard() -> bool:
	var viewport := get_viewport()
	if viewport == null or _search_line == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	if focus_owner == null:
		return false
	return focus_owner == _search_line or focus_owner == _list or _search_line.is_ancestor_of(focus_owner) or (_list != null and _list.is_ancestor_of(focus_owner))


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
		var selected := _list.get_selected_items()
		var index := 0 if selected.is_empty() else selected[0]
		_activate_index(index)
		return true
	return false


func _move_selection(delta: int) -> void:
	if _visible_entries.is_empty() or _list == null:
		return
	var selected := _list.get_selected_items()
	var index := 0 if selected.is_empty() else selected[0]
	index = clampi(index + delta, 0, _visible_entries.size() - 1)
	_list.select(index)
	_list.ensure_current_is_visible()


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
			if area != null and BV != null and BV.UI != null and BV.UI.top_bar != null:
				BV.UI.top_bar.focus_menu_cortical_area(area)
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
