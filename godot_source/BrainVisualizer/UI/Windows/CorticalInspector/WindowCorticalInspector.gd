extends BaseDraggableWindow
class_name WindowCorticalInspector
## Live cortical-area tuner. Slider and toggle changes are sent to FEAGI with no Apply button.
## Min and max beside a slider only set that slider's range.

const WINDOW_NAME: StringName = "cortical_inspector"
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")
const SELECT_AREA_LABEL: String = "Select cortical area"

var _area_button: Button
var _hint_label: Label
var _core_notice: Label
var _status_label: Label
var _firing_header: Label
var _psp_header: Label
var _firing_box: VBoxContainer
var _psp_box: VBoxContainer
var _rows: Dictionary = {}
var _list_popup: FilterableListPopup

var _area: AbstractCorticalArea
var _send_states: Dictionary = {}
var _active_drags: Dictionary = {}
var _previous_selection_ids: Array[String] = []
var _focus_generation: int = 0
var _refresh_when_idle: bool = false
var _refresh_running: bool = false
var _ui_built: bool = false


func _assert_type_ordinals() -> void:
	if int(AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE) != CorticalInspectorModel.CORTICAL_TYPE_CORE:
		push_error("Cortical inspector core type ordinal no longer matches AbstractCorticalArea")
	if int(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY) != CorticalInspectorModel.CORTICAL_TYPE_MEMORY:
		push_error("Cortical inspector memory type ordinal no longer matches AbstractCorticalArea")
	if int(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM) != CorticalInspectorModel.CORTICAL_TYPE_CUSTOM:
		push_error("Cortical inspector custom type ordinal no longer matches AbstractCorticalArea")


## Open the window and follow 3D selection while it stays open.
func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_assert_type_ordinals()
	_build_ui()
	if BV != null and BV.UI != null and BV.UI.selection_system != null:
		BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.CORTICAL_INSPECTOR)
		var highlighted: Array[AbstractCorticalArea] = BV.UI.selection_system.get_highlighted_cortical_areas()
		_previous_selection_ids = _ids_of(highlighted)
		if not highlighted.is_empty():
			var focus_id := CorticalInspectorModel.pick_focus_id("", [], _previous_selection_ids)
			var focused := _area_by_id(focus_id)
			if focused != null:
				focus_area(focused)


func close_window() -> void:
	_release_selection_override()
	super()


func _exit_tree() -> void:
	_release_selection_override()


## Retarget from a 3D selection without rebuilding the window, so slider min/max stay put.
func focus_from_selection(areas: Array[AbstractCorticalArea]) -> void:
	var selected_ids: Array[String] = _ids_of(areas)
	var current_id := ""
	if _area != null:
		current_id = str(_area.cortical_ID)
	var focus_id := CorticalInspectorModel.pick_focus_id(current_id, _previous_selection_ids, selected_ids)
	_previous_selection_ids = selected_ids
	if focus_id == "":
		return
	var focused := _area_by_id(focus_id)
	if focused != null:
		focus_area(focused)


## Show [param area] and load its current firing and PSP values.
func focus_area(area: AbstractCorticalArea) -> void:
	if area == null:
		return
	if _area == area:
		_area_button.text = _area_button_label(area)
		return
	_focus_generation += 1
	_send_states.clear()
	_active_drags.clear()
	_refresh_when_idle = false
	_area = area
	_area_button.text = _area_button_label(area)
	_set_status("")
	_apply_area_presentation()
	_load_rows_from_area()
	_reload_from_feagi()


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	_window_internals.add_child(picker)
	var picker_label := Label.new()
	picker_label.text = "Cortical area"
	picker.add_child(picker_label)
	_area_button = Button.new()
	_area_button.text = SELECT_AREA_LABEL
	_area_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_button.clip_text = true
	picker.add_child(_area_button)
	_area_button.pressed.connect(_open_area_menu)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = "Moving a slider or toggle updates FEAGI on the next burst. Min and max only set the slider range."
	_window_internals.add_child(_hint_label)

	_core_notice = Label.new()
	_core_notice.visible = false
	_core_notice.text = "Core areas are read-only."
	_window_internals.add_child(_core_notice)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 360)
	_window_internals.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_firing_header = _make_section_header("Neuron firing")
	_firing_box = VBoxContainer.new()
	_firing_box.add_theme_constant_override("separation", 8)
	_psp_header = _make_section_header("Postsynaptic potential")
	_psp_box = VBoxContainer.new()
	_psp_box.add_theme_constant_override("separation", 8)
	content.add_child(_firing_header)
	content.add_child(_firing_box)
	content.add_child(_psp_header)
	content.add_child(_psp_box)
	_firing_header.visible = false
	_psp_header.visible = false

	for spec in CorticalInspectorModel.parameter_specs():
		var row := CorticalInspectorRow.new()
		var parent: VBoxContainer = _firing_box if str(spec["section"]) == str(CorticalInspectorModel.SECTION_FIRING) else _psp_box
		parent.add_child(row)
		row.setup(spec)
		row.live_value_changed.connect(_on_row_value)
		row.bool_changed.connect(_on_row_bool)
		row.drag_started.connect(_on_row_drag_started)
		row.drag_ended.connect(_on_row_drag_ended)
		_rows[str(spec["id"])] = row
		row.visible = false

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window_internals.add_child(_status_label)


func _make_section_header(title: String) -> Label:
	var header := Label.new()
	header.text = title
	return header


func _open_area_menu() -> void:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return
	var named: Array = []
	var areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	for area_id in areas.keys():
		var area: AbstractCorticalArea = areas[area_id]
		if area == null:
			continue
		var area_name := str(area.friendly_name)
		if area_name == "":
			area_name = str(area.cortical_ID)
		named.append({"id": str(area.cortical_ID), "name": area_name})
	var entries: Array[Dictionary] = CorticalInspectorModel.build_area_menu_entries(named)
	var items: Array[Dictionary] = []
	for entry in entries:
		items.append({"label": str(entry["label"]), "payload": str(entry["id"])})
	_ensure_list_popup()
	_list_popup.open_with_items(_area_button, items, _on_area_menu_id, "Filter area name")


func _ensure_list_popup() -> void:
	if _list_popup != null:
		return
	_list_popup = PREFAB_FILTERABLE_LIST_POPUP.instantiate() as FilterableListPopup
	add_child(_list_popup)


func _on_area_menu_id(area_id: Variant) -> void:
	var focused := _area_by_id(str(area_id))
	if focused != null:
		focus_area(focused)


func _apply_area_presentation() -> void:
	var is_memory := _area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	var has_firing := _area.has_neuron_firing_parameters
	var read_only := CorticalInspectorModel.is_read_only(_area.cortical_type)
	var mp_driven := false
	if _rows.has(str(CorticalInspectorModel.KEY_MP_DRIVEN_PSP)):
		mp_driven = (_rows[str(CorticalInspectorModel.KEY_MP_DRIVEN_PSP)] as CorticalInspectorRow).is_on()
	var firing_visible := false
	var psp_visible := false
	for spec in CorticalInspectorModel.parameter_specs():
		var row: CorticalInspectorRow = _rows[str(spec["id"])]
		var visible := CorticalInspectorModel.row_visible(spec, is_memory, has_firing)
		row.visible = visible
		if visible and str(spec["section"]) == str(CorticalInspectorModel.SECTION_FIRING):
			firing_visible = true
		if visible and str(spec["section"]) == str(CorticalInspectorModel.SECTION_PSP):
			psp_visible = true
		var locked := CorticalInspectorModel.value_entry_locked(str(spec["id"]), mp_driven, read_only)
		row.set_value_editable(not locked)
	_firing_header.visible = firing_visible
	_psp_header.visible = psp_visible
	_core_notice.visible = read_only


func _load_rows_from_area() -> void:
	if _area == null:
		return
	for spec in CorticalInspectorModel.parameter_specs():
		var row_id := str(spec["id"])
		if _active_drags.has(row_id) or _key_in_flight(StringName(str(spec["key"]))):
			continue
		var row: CorticalInspectorRow = _rows[row_id]
		var raw: Variant = _read_spec(spec)
		if str(spec["kind"]) == "bool":
			row.set_bool(bool(raw))
		else:
			row.set_live(float(raw), true)
	_apply_area_presentation()


func _reload_from_feagi() -> void:
	if _area == null or FeagiCore == null or FeagiCore.requests == null:
		return
	if not FeagiCore.can_interact_with_feagi():
		return
	var generation := _focus_generation
	var area_id: StringName = _area.cortical_ID
	var result: FeagiRequestOutput = await FeagiCore.requests.get_cortical_area(area_id)
	if generation != _focus_generation or _area == null:
		return
	if result == null or not result.success:
		_set_status("Could not refresh this area from FEAGI.")
		return
	_load_rows_from_area()


func _on_row_value(row_id: StringName, value: float, from_drag: bool) -> void:
	var spec := CorticalInspectorModel.spec_by_id(str(row_id))
	if spec.is_empty():
		return
	var key := StringName(str(spec["key"]))
	if key == CorticalInspectorModel.KEY_THRESHOLD_INCREMENT:
		_queue_key(key, _increment_components(), from_drag)
		return
	_queue_key(key, value, from_drag)


func _on_row_bool(row_id: StringName, pressed: bool) -> void:
	var spec := CorticalInspectorModel.spec_by_id(str(row_id))
	if spec.is_empty():
		return
	_queue_key(StringName(str(spec["key"])), pressed, false)
	if str(spec["key"]) == str(CorticalInspectorModel.KEY_MP_DRIVEN_PSP):
		_apply_area_presentation()


func _on_row_drag_started(row_id: StringName) -> void:
	_active_drags[str(row_id)] = true


func _on_row_drag_ended(row_id: StringName) -> void:
	_active_drags.erase(str(row_id))
	_refresh_when_idle = true
	_maybe_refresh()


## @cursor:critical-path - one live parameter write, coalesced while the slider is moving
func _queue_key(key: StringName, ui_value: Variant, from_drag: bool) -> void:
	if not _edits_allowed():
		return
	if not from_drag:
		_refresh_when_idle = true
	var state := _send_state(key)
	if CorticalInspectorModel.offer_value(state, ui_value):
		_dispatch(key, ui_value)
	elif not from_drag:
		_maybe_refresh()


func _dispatch(key: StringName, ui_value: Variant) -> void:
	var generation := _focus_generation
	if _area == null or FeagiCore == null or FeagiCore.requests == null:
		CorticalInspectorModel.abandon(_send_state(key))
		return
	var area_id: StringName = _area.cortical_ID
	var wire: Variant = CorticalInspectorModel.ui_to_wire(str(key), ui_value)
	var body := {}
	body[str(key)] = wire
	var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(area_id, body, false)
	if generation != _focus_generation:
		return
	var state := _send_state(key)
	if result == null or not result.success:
		var failure := CorticalInspectorModel.finish_failure(state)
		_set_status(_failure_text(result))
		if bool(failure["has_restore"]):
			_show_key(key, failure["value"])
		else:
			_show_key_from_cache(key)
		_apply_area_presentation()
		_maybe_refresh()
		return
	_apply_wire_to_cache(key, wire)
	_set_status("")
	var nxt := CorticalInspectorModel.finish_success(state, ui_value)
	if bool(nxt["has_next"]) and CorticalInspectorModel.offer_value(state, nxt["value"]):
		await _dispatch(key, nxt["value"])
		return
	_maybe_refresh()


func _maybe_refresh() -> void:
	if not _refresh_when_idle or _refresh_running:
		return
	if not _active_drags.is_empty() or _any_in_flight():
		return
	_refresh_running = true
	_refresh_when_idle = false
	await _reload_from_feagi()
	_refresh_running = false
	if _refresh_when_idle:
		_maybe_refresh()


func _apply_wire_to_cache(key: StringName, wire: Variant) -> void:
	if _area == null:
		return
	var packet := {str(key): wire}
	if _area.get("neuron_firing_parameters") != null:
		_area.neuron_firing_parameters.FEAGI_apply_detail_dictionary(packet)
	if _area.post_synaptic_potential_paramamters != null:
		_area.post_synaptic_potential_paramamters.FEAGI_apply_detail_dictionary(packet)


func _show_key(key: StringName, ui_value: Variant) -> void:
	if key == CorticalInspectorModel.KEY_THRESHOLD_INCREMENT and ui_value is Array:
		var parts: Array = ui_value
		for axis in parts.size():
			var row_id := "neuron_fire_threshold_increment_%s" % ["x", "y", "z"][axis]
			if _rows.has(row_id):
				(_rows[row_id] as CorticalInspectorRow).set_live(float(parts[axis]), false)
		return
	if not _rows.has(str(key)):
		return
	var row: CorticalInspectorRow = _rows[str(key)]
	var spec := CorticalInspectorModel.spec_by_id(str(key))
	if str(spec.get("kind", "")) == "bool":
		row.set_bool(bool(ui_value))
	else:
		row.set_live(float(ui_value), false)


func _show_key_from_cache(key: StringName) -> void:
	if key == CorticalInspectorModel.KEY_THRESHOLD_INCREMENT:
		var vec: Vector3 = _area.neuron_firing_parameters.neuron_fire_threshold_increment
		_show_key(key, [vec.x, vec.y, vec.z])
		return
	for spec in CorticalInspectorModel.parameter_specs():
		if str(spec["key"]) != str(key):
			continue
		_show_key(key, _read_spec(spec) if str(spec["kind"]) == "bool" else float(_read_spec(spec)))
		return


func _read_spec(spec: Dictionary) -> Variant:
	if str(spec["cache"]) == str(CorticalInspectorModel.CACHE_FIRING):
		var firing: CorticalPropertyNeuronFiringParameters = _area.get("neuron_firing_parameters")
		if firing == null:
			return false if str(spec["kind"]) == "bool" else 0.0
		if str(spec["kind"]) == "vector":
			var vec: Vector3 = firing.neuron_fire_threshold_increment
			return [vec.x, vec.y, vec.z][int(spec["axis"])]
		return firing.get(str(spec["property"]))
	var psp: CorticalPropertyPostSynapticPotentialParameters = _area.post_synaptic_potential_paramamters
	if psp == null:
		return false if str(spec["kind"]) == "bool" else 0.0
	return psp.get(str(spec["property"]))


func _increment_components() -> Array:
	return [
		(_rows["neuron_fire_threshold_increment_x"] as CorticalInspectorRow).live_value(),
		(_rows["neuron_fire_threshold_increment_y"] as CorticalInspectorRow).live_value(),
		(_rows["neuron_fire_threshold_increment_z"] as CorticalInspectorRow).live_value(),
	]


func _edits_allowed() -> bool:
	if _area == null:
		return false
	return not CorticalInspectorModel.is_read_only(_area.cortical_type)


func _send_state(key: StringName) -> Dictionary:
	if not _send_states.has(key):
		_send_states[key] = CorticalInspectorModel.new_send_state()
	return _send_states[key]


func _key_in_flight(key: StringName) -> bool:
	if not _send_states.has(key):
		return false
	return bool(_send_states[key]["in_flight"])


func _any_in_flight() -> bool:
	for key in _send_states.keys():
		if bool(_send_states[key]["in_flight"]):
			return true
	return false


func _area_by_id(area_id: String) -> AbstractCorticalArea:
	if area_id == "" or FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return null
	var areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	if not areas.has(StringName(area_id)):
		return null
	return areas[StringName(area_id)] as AbstractCorticalArea


func _ids_of(areas: Array[AbstractCorticalArea]) -> Array[String]:
	var ids: Array[String] = []
	for area in areas:
		if area != null:
			ids.append(str(area.cortical_ID))
	return ids


func _area_button_label(area: AbstractCorticalArea) -> String:
	var area_name := str(area.friendly_name)
	if area_name == "":
		return str(area.cortical_ID)
	return area_name


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _failure_text(result: FeagiRequestOutput) -> String:
	if result == null:
		return "FEAGI update failed."
	if result.failed_requirement:
		return "FEAGI update failed (%s)." % str(result.failed_requirement_key)
	if result.has_timed_out:
		return "FEAGI update timed out."
	if result.has_errored:
		var details: Array = result.decode_response_as_generic_error_code()
		return "FEAGI update failed: %s %s" % [str(details[0]), str(details[1])]
	return "FEAGI update failed."


func _release_selection_override() -> void:
	if BV != null and BV.UI != null and BV.UI.selection_system != null:
		BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.CORTICAL_INSPECTOR)
