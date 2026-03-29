extends BaseDraggableWindow
class_name WindowVoxelInspector

## Draggable panel for voxel-level neuron/synapse JSON from the FEAGI API.

const WINDOW_NAME: StringName = "voxel_inspector"

## Default size: 1.5x prior width (520), 2x prior height (380).
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(780, 760)
const MIN_WINDOW_WIDTH: int = 400
const MIN_WINDOW_HEIGHT: int = 280

var _hint_label: Label
var _summary_neuron_count_value: IntInput
var _summary_membrane_name: Label
var _summary_membrane_value: FloatInput
var _summary_incoming_name: Label
var _summary_incoming_value: IntInput
var _summary_outgoing_name: Label
var _summary_outgoing_value: IntInput
var _json_text: TextEdit
var _cortical_dropdown: CorticalDropDown
var _coords: Vector3iSpinboxField
var _inspect_btn: Button
var _page_prev_btn: Button
var _page_next_btn: Button
var _page_value_label: Label
var _voxel_synapse_toggle: ToggleButton

## Last decoded `voxel_neurons` response (for 3D synapse overlay when the toggle is on).
var _last_successful_voxel_payload: Dictionary = {}

## Last successful Inspect query (used for Previous/Next without changing dropdown).
var _last_query_cortical_id: StringName = &""
var _last_query_coord: Vector3i = Vector3i.ZERO
## Echo of `synapse_page` from the last successful JSON response.
var _displayed_synapse_page: int = 0
## From the last successful response: any neuron had more synapse rows (used to re-enable Next after a failed page fetch).
var _last_synapse_has_more: bool = false

var _resize_handle: Panel
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
const _RESIZE_MARGIN: int = 16


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_hint_label = $WindowPanel/WindowMargin/WindowInternals/HintLabel
	var summary_root: Node = $WindowPanel/WindowMargin/WindowInternals/SummarySection
	_summary_neuron_count_value = summary_root.get_node("NeuronCountRow/Value") as IntInput
	_summary_membrane_name = summary_root.get_node("MembraneRow/Name") as Label
	_summary_membrane_value = summary_root.get_node("MembraneRow/Value") as FloatInput
	_summary_incoming_name = summary_root.get_node("IncomingRow/Name") as Label
	_summary_incoming_value = summary_root.get_node("IncomingRow/Value") as IntInput
	_summary_outgoing_name = summary_root.get_node("OutgoingRow/Name") as Label
	_summary_outgoing_value = summary_root.get_node("OutgoingRow/Value") as IntInput
	_json_text = $WindowPanel/WindowMargin/WindowInternals/JsonText
	_cortical_dropdown = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/CorticalRow/CorticalAreaDropdown
	_coords = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/VoxelCoords
	_inspect_btn = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/InspectButton
	_page_prev_btn = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PagePrevButton
	_page_next_btn = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PageNextButton
	_page_value_label = $WindowPanel/WindowMargin/WindowInternals/PaginationRow/PageValueLabel
	_voxel_synapse_toggle = $WindowPanel/WindowMargin/WindowInternals/InspectorControls/VoxelSynapseRow/VoxelSynapseToggle
	_json_text.editable = false
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	size = DEFAULT_WINDOW_SIZE
	_setup_resize_handle()
	call_deferred("_deferred_apply_initial_window_size")
	call_deferred("_refresh_cortical_list_and_selection")
	_inspect_btn.pressed.connect(_on_inspect_pressed)
	_page_prev_btn.pressed.connect(_on_page_prev_pressed)
	_page_next_btn.pressed.connect(_on_page_next_pressed)
	if _voxel_synapse_toggle != null:
		_voxel_synapse_toggle.toggled.connect(_on_voxel_synapse_toggle_toggled)
	set_empty_state()
	# IntInput/FloatInput _ready() runs after setup and applies initial_int/initial_float; re-apply empty placeholders.
	call_deferred("_clear_summary_display")


func _refresh_cortical_list_and_selection() -> void:
	if _cortical_dropdown == null:
		return
	if FeagiCore.feagi_local_cache != null and FeagiCore.feagi_local_cache.cortical_areas != null:
		_cortical_dropdown.list_all_cached_areas()
	if _cortical_dropdown.get_item_count() > 0:
		if _cortical_dropdown.selected < 0:
			_cortical_dropdown.select(0)


func _deferred_apply_initial_window_size() -> void:
	# BaseDraggableWindow may shrink the window on theme apply; restore intended default.
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
		set_error_line("Select a cortical area.")
		return
	var coord: Vector3i = _coords.current_vector
	_last_query_cortical_id = area.cortical_ID
	_last_query_coord = coord
	BV.UI.request_voxel_inspector_fetch(area.cortical_ID, coord, 0)


func _on_page_prev_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	if String(_last_query_cortical_id).is_empty():
		return
	if _displayed_synapse_page <= 0:
		return
	BV.UI.request_voxel_inspector_fetch(_last_query_cortical_id, _last_query_coord, _displayed_synapse_page - 1)


func _on_page_next_pressed() -> void:
	if BV == null or BV.UI == null:
		return
	if String(_last_query_cortical_id).is_empty():
		return
	BV.UI.request_voxel_inspector_fetch(_last_query_cortical_id, _last_query_coord, _displayed_synapse_page + 1)


func _on_voxel_synapse_toggle_toggled(enabled: bool) -> void:
	if BV == null or BV.UI == null:
		return
	if enabled:
		BV.UI.request_voxel_synapse_visualization_rebuild()
	else:
		BV.UI.clear_voxel_synapse_visualization_all_brain_monitors()


## When the Inspect response arrives, UIManager stores the payload here for the 3D overlay.
func set_last_successful_voxel_payload(d: Dictionary) -> void:
	_last_successful_voxel_payload = d.duplicate(true)


func get_last_successful_voxel_payload() -> Dictionary:
	return _last_successful_voxel_payload.duplicate(true)


## Whether the user enabled 3D voxel synapse arcs (default off).
func is_voxel_synapse_visualization_enabled() -> bool:
	return _voxel_synapse_toggle != null and _voxel_synapse_toggle.button_pressed


## Updates Previous/Next and page label from a successful `voxel_neurons` payload (synapse_page + per-neuron has_more flags).
func update_synapse_pagination_from_response(d: Dictionary) -> void:
	_displayed_synapse_page = int(d.get("synapse_page", 0))
	if _page_value_label != null:
		_page_value_label.text = str(_displayed_synapse_page)
	var any_more := false
	var neurons_raw: Variant = d.get("neurons", [])
	if neurons_raw is Array:
		for n in neurons_raw:
			if n is Dictionary:
				var nd: Dictionary = n
				if nd.get("outgoing_synapses_has_more", false) or nd.get("incoming_synapses_has_more", false):
					any_more = true
					break
	if _page_prev_btn != null:
		_page_prev_btn.disabled = _displayed_synapse_page <= 0
	if _page_next_btn != null:
		_page_next_btn.disabled = not any_more
	_last_synapse_has_more = any_more


## Re-enable Previous/Next after a failed request (still using last successful pagination hints).
func restore_pagination_after_failed_fetch() -> void:
	if String(_last_query_cortical_id).is_empty():
		return
	if _page_prev_btn != null:
		_page_prev_btn.disabled = _displayed_synapse_page <= 0
	if _page_next_btn != null:
		_page_next_btn.disabled = not _last_synapse_has_more


## Clears the response area (e.g. before a new run).
func set_empty_state() -> void:
	_hint_label.visible = true
	_json_text.clear()
	_clear_summary_display()
	_last_successful_voxel_payload.clear()
	if _voxel_synapse_toggle != null:
		_voxel_synapse_toggle.set_toggle_no_signal(false)
	if BV != null and BV.UI != null:
		BV.UI.clear_voxel_synapse_visualization_all_brain_monitors()
	_last_query_cortical_id = &""
	_last_query_coord = Vector3i.ZERO
	_displayed_synapse_page = 0
	_last_synapse_has_more = false
	if _page_value_label != null:
		_page_value_label.text = "0"
	if _page_prev_btn != null:
		_page_prev_btn.disabled = true
	if _page_next_btn != null:
		_page_next_btn.disabled = true


## Shown while the voxel_neurons request is in flight.
func set_loading() -> void:
	_hint_label.visible = true
	_json_text.text = "Loading…"
	_clear_summary_display()
	if _page_prev_btn != null:
		_page_prev_btn.disabled = true
	if _page_next_btn != null:
		_page_next_btn.disabled = true


## Formatted JSON (or truncated JSON string) from a successful response.
func set_json_content(text: String) -> void:
	_hint_label.visible = true
	_json_text.text = text


## Error or non-JSON status line when the request fails or FEAGI is unavailable.
func set_error_line(text: String) -> void:
	_hint_label.visible = true
	_json_text.text = text
	_clear_summary_display()


func _clear_summary_display() -> void:
	if _summary_neuron_count_value != null:
		_set_summary_lineedit_placeholder(_summary_neuron_count_value)
	if _summary_membrane_value != null:
		_set_summary_lineedit_placeholder(_summary_membrane_value)
	if _summary_incoming_value != null:
		_set_summary_lineedit_placeholder(_summary_incoming_value)
	if _summary_outgoing_value != null:
		_set_summary_lineedit_placeholder(_summary_outgoing_value)
	_reset_summary_metric_names()


## Read-only placeholder (em dash) without going through Int/Float validation (same LineEdit pattern as Cortical Area Details).
func _set_summary_lineedit_placeholder(ctrl: LineEdit) -> void:
	ctrl.text = "—"
	if ctrl is AbstractLineInput:
		(ctrl as AbstractLineInput).previous_text = "—"


func _reset_summary_metric_names() -> void:
	if _summary_membrane_name != null:
		_summary_membrane_name.text = "Membrane Potential"
	if _summary_incoming_name != null:
		_summary_incoming_name.text = "Incoming Synapse Count"
	if _summary_outgoing_name != null:
		_summary_outgoing_name.text = "Outgoing Synapse Count"


func _set_average_metric_names() -> void:
	if _summary_membrane_name != null:
		_summary_membrane_name.text = "Average Membrane Potential"
	if _summary_incoming_name != null:
		_summary_incoming_name.text = "Average Incoming Synapse Count"
	if _summary_outgoing_name != null:
		_summary_outgoing_name.text = "Average Outgoing Synapse Count"


func _variant_to_float(v: Variant) -> float:
	if v == null:
		return 0.0
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		return v as float
	if t == TYPE_INT:
		return float(v as int)
	return 0.0


func _format_membrane_for_display(v: float) -> String:
	return String.num(v, 4)


## Fills the Summary block from a successful `/v1/cortical_area/voxel_neurons` payload.
func update_summary_from_response(d: Dictionary) -> void:
	if _summary_neuron_count_value == null:
		return
	var neurons_raw: Variant = d.get("neurons", [])
	var neurons: Array = []
	if neurons_raw is Array:
		neurons = neurons_raw
	var n: int = neurons.size()
	var reported: int = int(d.get("neuron_count", n))
	_summary_neuron_count_value.set_value_from_text(str(reported))
	if n == 0:
		_reset_summary_metric_names()
		_set_summary_lineedit_placeholder(_summary_membrane_value)
		_set_summary_lineedit_placeholder(_summary_incoming_value)
		_set_summary_lineedit_placeholder(_summary_outgoing_value)
		return
	if n == 1:
		_reset_summary_metric_names()
		var nd: Dictionary = {}
		if neurons[0] is Dictionary:
			nd = neurons[0]
		var mp: float = _variant_to_float(nd.get("membrane_potential", 0.0))
		var inc_n: float = _variant_to_float(nd.get("incoming_synapse_count", 0))
		var out_n: float = _variant_to_float(nd.get("outgoing_synapse_count", 0))
		_summary_membrane_value.set_value_from_text(_format_membrane_for_display(mp))
		_summary_incoming_value.set_value_from_text(str(int(round(inc_n))))
		_summary_outgoing_value.set_value_from_text(str(int(round(out_n))))
		return
	_set_average_metric_names()
	var sum_mp: float = 0.0
	var sum_in: float = 0.0
	var sum_out: float = 0.0
	for item in neurons:
		if item is Dictionary:
			var nd2: Dictionary = item
			sum_mp += _variant_to_float(nd2.get("membrane_potential", 0.0))
			sum_in += _variant_to_float(nd2.get("incoming_synapse_count", 0))
			sum_out += _variant_to_float(nd2.get("outgoing_synapse_count", 0))
	var nf: float = float(n)
	_summary_membrane_value.set_value_from_text(_format_membrane_for_display(sum_mp / nf))
	var avg_in: int = int(round(sum_in / nf))
	var avg_out: int = int(round(sum_out / nf))
	_summary_incoming_value.set_value_from_text(str(avg_in))
	_summary_outgoing_value.set_value_from_text(str(avg_out))
