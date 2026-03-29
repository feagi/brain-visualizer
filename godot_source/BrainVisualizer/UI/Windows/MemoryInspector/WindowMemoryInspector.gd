extends BaseDraggableWindow
class_name WindowMemoryInspector

## Memory cortical area + single memory neuron JSON from FEAGI `/v1/cortical_area/memory` and `/v1/connectome/memory_neuron`.

const WINDOW_NAME: StringName = "memory_inspector"

const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(780, 760)
const MIN_WINDOW_WIDTH: int = 400
const MIN_WINDOW_HEIGHT: int = 280
const DEFAULT_PAGE_SIZE: int = 50

var _hint_label: Label
var _st_value: IntInput
var _ltm_value: IntInput
var _pattern_cache_value: IntInput
var _upstream_count_value: IntInput
var _inc_syn_value: IntInput
var _out_syn_value: IntInput
var _area_json: TextEdit
var _neuron_json: TextEdit
var _cortical_dropdown: CorticalDropDown
var _inspect_btn: Button
var _page_prev_btn: Button
var _page_next_btn: Button
var _page_value_label: Label
var _neuron_id_field: LineEdit
var _fetch_neuron_btn: Button

var _last_query_cortical_id: StringName = &""
var _displayed_page: int = 0
var _last_has_more: bool = false
var _page_size_used: int = DEFAULT_PAGE_SIZE

var _resize_handle: Panel
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
const _RESIZE_MARGIN: int = 16


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_hint_label = $WindowPanel/WindowMargin/WindowInternals/HintLabel
	var summary_root: Node = $WindowPanel/WindowMargin/WindowInternals/SummarySection
	_st_value = summary_root.get_node("ShortTermRow/Value") as IntInput
	_ltm_value = summary_root.get_node("LongTermRow/Value") as IntInput
	_pattern_cache_value = summary_root.get_node("PatternCacheRow/Value") as IntInput
	_upstream_count_value = summary_root.get_node("UpstreamCountRow/Value") as IntInput
	_inc_syn_value = summary_root.get_node("IncSynRow/Value") as IntInput
	_out_syn_value = summary_root.get_node("OutSynRow/Value") as IntInput
	_area_json = $WindowPanel/WindowMargin/WindowInternals/AreaJsonText
	_neuron_json = $WindowPanel/WindowMargin/WindowInternals/NeuronJsonText
	_cortical_dropdown = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/CorticalRow/CorticalAreaDropdown
	_inspect_btn = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/InspectButton
	_page_prev_btn = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PagePrevButton
	_page_next_btn = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PageNextButton
	_page_value_label = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PageValueLabel
	_neuron_id_field = $WindowPanel/WindowMargin/WindowInternals/NeuronQueryRow/NeuronIdField
	_fetch_neuron_btn = $WindowPanel/WindowMargin/WindowInternals/NeuronQueryRow/FetchNeuronButton
	_area_json.editable = false
	_neuron_json.editable = false
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	size = DEFAULT_WINDOW_SIZE
	_setup_resize_handle()
	call_deferred("_deferred_apply_initial_window_size")
	call_deferred("_refresh_cortical_list_and_selection")
	_inspect_btn.pressed.connect(_on_inspect_pressed)
	_page_prev_btn.pressed.connect(_on_page_prev_pressed)
	_page_next_btn.pressed.connect(_on_page_next_pressed)
	_fetch_neuron_btn.pressed.connect(_on_fetch_neuron_pressed)
	set_empty_state()
	# IntInput _ready() runs after setup and applies initial_int; re-apply empty placeholders (same as Voxel Inspector).
	call_deferred("_clear_summary_display")


func _refresh_cortical_list_and_selection() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if _cortical_dropdown == null:
		return
	if FeagiCore.feagi_local_cache == null or FeagiCore.feagi_local_cache.cortical_areas == null:
		return
	_cortical_dropdown.list_cortical_area_types([AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY])
	if _cortical_dropdown.get_item_count() > 0:
		if _cortical_dropdown.selected < 0:
			_cortical_dropdown.select(0)


func _deferred_apply_initial_window_size() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	size = DEFAULT_WINDOW_SIZE


func _setup_resize_handle() -> void:
	_resize_handle = Panel.new()
	_resize_handle.name = "ResizeHandle"
	_resize_handle.custom_minimum_size = Vector2(_RESIZE_MARGIN, _RESIZE_MARGIN)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	var grip_icon := Control.new()
	grip_icon.name = "ResizeGripIcon"
	grip_icon.custom_minimum_size = Vector2(_RESIZE_MARGIN, _RESIZE_MARGIN)
	grip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_icon.draw.connect(_draw_resize_grip.bind(grip_icon))
	_resize_handle.add_child(grip_icon)
	add_child(_resize_handle)
	_resize_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_resize_handle.offset_left = -_RESIZE_MARGIN
	_resize_handle.offset_top = -_RESIZE_MARGIN
	_resize_handle.z_index = 1000


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
		new_size.x = maxf(new_size.x, float(MIN_WINDOW_WIDTH))
		new_size.y = maxf(new_size.y, float(MIN_WINDOW_HEIGHT))
		size = new_size
		custom_minimum_size = new_size


func _draw_resize_grip(control: Control) -> void:
	var grip_color := Color(0.6, 0.6, 0.6, 0.9)
	var square_size := 8
	var x_pos := _RESIZE_MARGIN - square_size
	var y_pos := (_RESIZE_MARGIN - square_size) / 2.0
	var rect := Rect2(Vector2(x_pos, y_pos), Vector2(square_size, square_size))
	control.draw_rect(rect, grip_color, true)


func _on_inspect_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	var area: AbstractCorticalArea = _cortical_dropdown.get_selected_cortical_area()
	if area == null:
		set_error_line("Select a memory cortical area.")
		return
	_last_query_cortical_id = area.cortical_ID
	if _neuron_json != null:
		_neuron_json.clear()
	BV.UI.request_memory_inspector_fetch(area.cortical_ID, 0, DEFAULT_PAGE_SIZE)


func _on_page_prev_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	if String(_last_query_cortical_id).is_empty():
		return
	if _displayed_page <= 0:
		return
	BV.UI.request_memory_inspector_fetch(_last_query_cortical_id, _displayed_page - 1, _page_size_used)


func _on_page_next_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	if String(_last_query_cortical_id).is_empty():
		return
	if not _last_has_more:
		return
	BV.UI.request_memory_inspector_fetch(_last_query_cortical_id, _displayed_page + 1, _page_size_used)


func _on_fetch_neuron_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	var raw: String = _neuron_id_field.text.strip_edges()
	if raw.is_empty():
		set_neuron_error_line("Enter a memory neuron id.")
		return
	if not raw.is_valid_int():
		set_neuron_error_line("Neuron id must be an integer.")
		return
	var nid: int = int(raw)
	BV.UI.request_memory_neuron_detail_fetch(nid)


func set_empty_state() -> void:
	_hint_label.visible = true
	_area_json.clear()
	_neuron_json.clear()
	_last_query_cortical_id = &""
	_displayed_page = 0
	_last_has_more = false
	_page_size_used = DEFAULT_PAGE_SIZE
	if _page_value_label != null:
		_page_value_label.text = "0"
	if _page_prev_btn != null:
		_page_prev_btn.disabled = true
	if _page_next_btn != null:
		_page_next_btn.disabled = true
	_clear_summary_display()


func set_loading() -> void:
	_hint_label.visible = true
	_area_json.text = "Loading…"
	_clear_summary_display()
	if _page_prev_btn != null:
		_page_prev_btn.disabled = true
	if _page_next_btn != null:
		_page_next_btn.disabled = true


func set_area_json_content(text: String) -> void:
	_hint_label.visible = true
	_area_json.text = text


func set_error_line(text: String) -> void:
	_hint_label.visible = true
	_area_json.text = text
	_clear_summary_display()


func set_neuron_loading() -> void:
	_neuron_json.text = "Loading…"


func set_neuron_json_content(text: String) -> void:
	_neuron_json.text = text


func set_neuron_error_line(text: String) -> void:
	_neuron_json.text = text


func update_area_pagination_from_response(d: Dictionary) -> void:
	_displayed_page = int(d.get("page", 0))
	_page_size_used = int(d.get("page_size", DEFAULT_PAGE_SIZE))
	if _page_size_used < 1:
		_page_size_used = DEFAULT_PAGE_SIZE
	if _page_value_label != null:
		_page_value_label.text = str(_displayed_page)
	_last_has_more = bool(d.get("has_more", false))
	if _page_prev_btn != null:
		_page_prev_btn.disabled = _displayed_page <= 0
	if _page_next_btn != null:
		_page_next_btn.disabled = not _last_has_more


func restore_pagination_after_failed_fetch() -> void:
	if String(_last_query_cortical_id).is_empty():
		return
	if _page_prev_btn != null:
		_page_prev_btn.disabled = _displayed_page <= 0
	if _page_next_btn != null:
		_page_next_btn.disabled = not _last_has_more


func update_summary_from_response(d: Dictionary) -> void:
	if _st_value == null:
		return
	_set_int_summary(_st_value, int(d.get("short_term_neuron_count", 0)))
	_set_int_summary(_ltm_value, int(d.get("long_term_neuron_count", 0)))
	_set_int_summary(_pattern_cache_value, int(d.get("upstream_pattern_cache_size", 0)))
	_set_int_summary(_upstream_count_value, int(d.get("upstream_cortical_area_count", 0)))
	_set_int_summary(_inc_syn_value, int(d.get("incoming_synapse_count", 0)))
	_set_int_summary(_out_syn_value, int(d.get("outgoing_synapse_count", 0)))


func _set_int_summary(ctrl: IntInput, v: int) -> void:
	if ctrl != null:
		ctrl.set_value_from_text(str(v))


func _clear_summary_display() -> void:
	if _st_value != null:
		_set_placeholder(_st_value)
	if _ltm_value != null:
		_set_placeholder(_ltm_value)
	if _pattern_cache_value != null:
		_set_placeholder(_pattern_cache_value)
	if _upstream_count_value != null:
		_set_placeholder(_upstream_count_value)
	if _inc_syn_value != null:
		_set_placeholder(_inc_syn_value)
	if _out_syn_value != null:
		_set_placeholder(_out_syn_value)


func _set_placeholder(ctrl: LineEdit) -> void:
	ctrl.text = "—"
	if ctrl is AbstractLineInput:
		(ctrl as AbstractLineInput).previous_text = "—"
