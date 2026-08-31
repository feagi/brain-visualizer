extends BaseDraggableWindow
class_name WindowQuickConnectNeuron

const WINDOW_NAME: StringName = "quick_connect_neuron"

const INVALID_COORD: Vector3i = Vector3i(-1,-1,-1)

enum MODE {
	CORTICAL_AREA_TO_NEURONS,
	NEURONS_TO_CORTICAL_AREA,
	NEURON_TO_NEURONS
}

enum POSSIBLE_STATES {
	NOT_READY,
	SOURCE,
	DESTINATION,
	READY
}


var current_state: POSSIBLE_STATES:
	get: return _current_state

var _source_panel: PanelContainer
var _source_label: RichTextLabel
var _source_edit_button: TextureButton
var _source_paste_button: TextureButton
var _destination_panel: PanelContainer
var _destination_label: RichTextLabel
var _destination_edit_button: TextureButton
var _destination_paste_button: TextureButton
var _mapping_panel: PanelContainer
var _mapping_label: RichTextLabel
var _mapping_edit_button: TextureButton

var _establish_button: Button


var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.NOT_READY
var _finished_selecting: bool = false

var _source: AbstractCorticalArea = null
var _source_neuron_local_coords: Array[Vector3i] = []
var _destination: AbstractCorticalArea = null
var _destination_neuron_local_coords: Array[Vector3i] = []
var _source_batch_neurons_by_area: Dictionary[StringName, Array] = {}
var _destination_batch_neurons_by_area: Dictionary[StringName, Array] = {}

var _mode: MODE
var _establishing: bool = false
var _last_clipboard_snapshot: String = ""

func _ready() -> void:
	super()
	_source_panel = _window_internals.get_node("source")
	_source_label = _window_internals.get_node("source/step1/Label")
	_source_edit_button = _window_internals.get_node("source/step1/TextureButton")
	_source_paste_button = _window_internals.get_node("source/step1/PasteTextureButton")
	_destination_panel = _window_internals.get_node("destination")
	_destination_label = _window_internals.get_node("destination/step2/Label")
	_destination_edit_button = _window_internals.get_node("destination/step2/TextureButton")
	_destination_paste_button = _window_internals.get_node("destination/step2/PasteTextureButton")
	_mapping_panel = _window_internals.get_node("confirm")
	_mapping_label = _window_internals.get_node("confirm/step3/Label")
	_mapping_edit_button = _window_internals.get_node("confirm/step3/TextureButton")
	_establish_button = _window_internals.get_node("Establish")
	
	_source_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_destination_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_last_clipboard_snapshot = DisplayServer.clipboard_get()


func _process(_delta: float) -> void:
	var clipboard_text: String = DisplayServer.clipboard_get()
	if clipboard_text == _last_clipboard_snapshot:
		return
	_last_clipboard_snapshot = clipboard_text
	_refresh_clipboard_paste_buttons()

	
	
func setup(mode: MODE, optional_initial_cortical_area: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	_mode = mode
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON)
	_start_edit_source_config(optional_initial_cortical_area)
	_refresh_clipboard_paste_buttons()


func _start_edit_source_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	if _destination_panel.theme_type_variation == "PanelContainer_QC_waiting":
		_end_edit_destination_config()
	_source_panel.theme_type_variation = "PanelContainer_QC_waiting"
	_source = null
	_source_neuron_local_coords = []
	_source_batch_neurons_by_area.clear()
	_mapping_edit_button.disabled = true
	_mapping_label.text = "Waiting..."
	_establish_button.disabled = true
	_destination_edit_button.disabled = true
	
	if optional_limit_to_cortical_area != null:
		_source = optional_limit_to_cortical_area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(optional_limit_to_cortical_area)
		if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
			_update_label_of_source_or_destination(true)
			_end_edit_source_config()
			_start_edit_destination_config()
			_refresh_clipboard_paste_buttons()
			return
	BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.connect(_retrieved_source_neuron_list_change)
	_update_label_of_source_or_destination(true)
	_refresh_clipboard_paste_buttons()


func _retrieved_source_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if not _source_batch_neurons_by_area.is_empty():
		_source_batch_neurons_by_area.clear()
	if _source == null:
		_source = area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(area)
	if _source != area:
		push_error("FEAGI Quick Neuron Connect: Source area does not match expected!")
		return
	_destination_edit_button.disabled = false
	if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
		_update_label_of_source_or_destination(true)
		_end_edit_source_config()
		_refresh_clipboard_paste_buttons()
		return # we dont care about neurons
	
	if added:
		if local_coord in _source_neuron_local_coords:
			pass
		else:
			_source_neuron_local_coords.append(local_coord)
			if _mode == MODE.NEURON_TO_NEURONS:
				_update_label_of_source_or_destination(true)
				_end_edit_source_config() # only need 1 neuron
				_refresh_clipboard_paste_buttons()
				return
	else:
		var search: int = _source_neuron_local_coords.find(local_coord)
		if search != -1:
			_source_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(true)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	_refresh_clipboard_paste_buttons()

func _end_edit_source_config() -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.temp_root_bm.remove_neuron_cortical_are_selection_restrictions()
	_source_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.is_connected(_retrieved_source_neuron_list_change):
		BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.disconnect(_retrieved_source_neuron_list_change)
	_refresh_clipboard_paste_buttons()


func _start_edit_destination_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	if _source_panel.theme_type_variation == "PanelContainer_QC_waiting":
		_end_edit_source_config()
	_destination_panel.theme_type_variation = "PanelContainer_QC_waiting"
	_destination = null
	_destination_neuron_local_coords = []
	_destination_batch_neurons_by_area.clear()
	_mapping_edit_button.disabled = true
	_mapping_label.text = "Waiting..."
	_establish_button.disabled = true
	_source_edit_button.disabled = true
	
	if optional_limit_to_cortical_area != null:
		_destination = optional_limit_to_cortical_area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(optional_limit_to_cortical_area)
		if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
			_update_label_of_source_or_destination(false)
			_end_edit_destination_config()
			_refresh_clipboard_paste_buttons()
			return
	BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.connect(_retrieved_destination_neuron_list_change)
	_update_label_of_source_or_destination(false)
	_refresh_clipboard_paste_buttons()


func _retrieved_destination_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if not _destination_batch_neurons_by_area.is_empty():
		_destination_batch_neurons_by_area.clear()
	if _destination == null:
		_destination = area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(area)
	if _destination != area:
		push_error("FEAGI Quick Neuron Connect: Destination area does not match expected!")
		return
	_source_edit_button.disabled = false
	if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
		_update_label_of_source_or_destination(false)
		_end_edit_destination_config()
		_refresh_clipboard_paste_buttons()
		return # we dont care about neurons
	
	if added:
		if local_coord in _destination_neuron_local_coords:
			pass
		else:
			_destination_neuron_local_coords.append(local_coord)
	else:
		var search: int = _destination_neuron_local_coords.find(local_coord)
		if search != -1:
			_destination_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(false)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	_refresh_clipboard_paste_buttons()

func _end_edit_destination_config() -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.temp_root_bm.remove_neuron_cortical_are_selection_restrictions()
	_destination_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.is_connected(_retrieved_destination_neuron_list_change):
		BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.disconnect(_retrieved_destination_neuron_list_change)
	_refresh_clipboard_paste_buttons()




func _mapping_establish_check_pressed() -> void:
	if !_has_enough_information_for_mapping():
		return
	_end_edit_source_config()
	_end_edit_destination_config()
	_define_pattern_morphology_label()
	_establish_button.disabled = false
	_refresh_clipboard_paste_buttons()


func _paste_source_from_clipboard() -> void:
	_apply_clipboard_voxel_selection(true)


func _paste_destination_from_clipboard() -> void:
	_apply_clipboard_voxel_selection(false)


func _update_label_of_source_or_destination(is_source: bool) -> void:
	var text: String
	if is_source:
		if !_source:
			text = "Select a source cortical area"
		elif _mode == MODE.CORTICAL_AREA_TO_NEURONS:
			text = "Cortical area: %s\nMapping to all neurons!" % _source.friendly_name
		elif not _source_batch_neurons_by_area.is_empty():
			var area_count: int = _source_batch_neurons_by_area.size()
			var voxel_count: int = 0
			for vox in _source_batch_neurons_by_area.values():
				voxel_count += (vox as Array).size()
			text = "Source areas from clipboard: %d\nTotal source voxels: %d\nPrimary area: %s\nAreas:\n%s" % [
				area_count,
				voxel_count,
				_source.friendly_name,
				_build_batch_area_summary(_source_batch_neurons_by_area),
			]
		elif len(_source_neuron_local_coords) == 0:
			text = "Cortical area: %s\nPlease select neurons!"  % _source.friendly_name
		else:
			text = "Cortical area: %s\nNeurons:\n"  % _source.friendly_name
			for vector in _source_neuron_local_coords:
				text += "[%d,%d,%d]\n" % [vector.x, vector.y, vector.z]
		_source_label.text = text
		return
	else:
		if !_destination:
			text = "Select a destination cortical area"
		elif _mode == MODE.NEURONS_TO_CORTICAL_AREA:
			text = "Cortical area: %s\nMapping to all neurons!"  % _destination.friendly_name
		elif not _destination_batch_neurons_by_area.is_empty():
			var area_count_dest: int = _destination_batch_neurons_by_area.size()
			var voxel_count_dest: int = 0
			for vox in _destination_batch_neurons_by_area.values():
				voxel_count_dest += (vox as Array).size()
			text = "Destination areas from clipboard: %d\nTotal destination voxels: %d\nPrimary area: %s\nAreas:\n%s" % [
				area_count_dest,
				voxel_count_dest,
				_destination.friendly_name,
				_build_batch_area_summary(_destination_batch_neurons_by_area),
			]
		elif len(_destination_neuron_local_coords) == 0:
			text = "Cortical area: %s\nPlease select neurons!"  % _destination.friendly_name
		else:
			text = "Cortical area: %s\nNeurons:\n" % _destination.friendly_name
			for vector in _destination_neuron_local_coords:
				text += "[%d,%d,%d]\n" % [vector.x, vector.y, vector.z]
		_destination_label.text = text
		return


func _has_enough_information_for_mapping() -> bool:
	if !_source or !_destination:
		return false
	var source_voxel_count: int = _source_neuron_local_coords.size()
	if not _source_batch_neurons_by_area.is_empty():
		source_voxel_count = 0
		for vox in _source_batch_neurons_by_area.values():
			source_voxel_count += (vox as Array).size()
	var destination_voxel_count: int = _destination_neuron_local_coords.size()
	if not _destination_batch_neurons_by_area.is_empty():
		destination_voxel_count = 0
		for vox in _destination_batch_neurons_by_area.values():
			destination_voxel_count += (vox as Array).size()
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return destination_voxel_count != 0
		MODE.NEURONS_TO_CORTICAL_AREA:
			return source_voxel_count != 0
			
		MODE.NEURON_TO_NEURONS:
			return source_voxel_count == 1 and destination_voxel_count > 0
		_:
		# HOW
			return false


func _variant_to_int_if_possible(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float:
		var f: float = value
		var rounded: int = int(round(f))
		if abs(f - float(rounded)) < 0.0001:
			return rounded
		return null
	if value is String:
		var s: String = String(value).strip_edges()
		if s.is_empty():
			return null
		if s.is_valid_int():
			return s.to_int()
		if s.is_valid_float():
			var sf: float = s.to_float()
			var sr: int = int(round(sf))
			if abs(sf - float(sr)) < 0.0001:
				return sr
	return null


func _extract_voxels_from_variant(raw_voxels: Variant) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if raw_voxels is not Array:
		return out
	for entry in raw_voxels:
		if entry is Array:
			var arr: Array = entry
			if arr.size() >= 3:
				var x_value: Variant = _variant_to_int_if_possible(arr[0])
				var y_value: Variant = _variant_to_int_if_possible(arr[1])
				var z_value: Variant = _variant_to_int_if_possible(arr[2])
				if x_value != null and y_value != null and z_value != null:
					var x_int: int = int(x_value)
					var y_int: int = int(y_value)
					var z_int: int = int(z_value)
					out.append(Vector3i(x_int, y_int, z_int))
	return out


func _parse_payload_dict_to_voxel_map(parsed_dict: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	if parsed_dict.has("areas") and parsed_dict["areas"] is Array:
		for area_entry in parsed_dict["areas"]:
			if area_entry is not Dictionary:
				continue
			var area_dict: Dictionary = area_entry
			var raw_id: String = String(area_dict.get("cortical_id", "")).strip_edges()
			if raw_id.is_empty():
				continue
			var voxels: Array[Vector3i] = _extract_voxels_from_variant(area_dict.get("voxels", []))
			payload[StringName(raw_id)] = voxels
	if payload.is_empty() and parsed_dict.has("by_cortical_id") and parsed_dict["by_cortical_id"] is Dictionary:
		var by_cortical_id: Dictionary = parsed_dict["by_cortical_id"]
		for raw_area_id in by_cortical_id.keys():
			var area_id: String = String(raw_area_id).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = _extract_voxels_from_variant(by_cortical_id[raw_area_id])
			payload[StringName(area_id)] = voxels
	# Manual stimulation style: {"stimulation_payload": {"id": [[x,y,z], ...]}}
	if payload.is_empty() and parsed_dict.has("stimulation_payload") and parsed_dict["stimulation_payload"] is Dictionary:
		var stimulation_payload: Dictionary = parsed_dict["stimulation_payload"]
		for raw_area_id in stimulation_payload.keys():
			var area_id: String = String(raw_area_id).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = _extract_voxels_from_variant(stimulation_payload[raw_area_id])
			payload[StringName(area_id)] = voxels
	# Direct shape: {"id": [[x,y,z], ...], ...}
	if payload.is_empty():
		for raw_key in parsed_dict.keys():
			var area_id: String = String(raw_key).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = _extract_voxels_from_variant(parsed_dict[raw_key])
			if not voxels.is_empty():
				payload[StringName(area_id)] = voxels
	return payload


func _parse_clipboard_voxel_payload() -> Dictionary:
	var payload: Dictionary = {}
	var clipboard_text: String = DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.is_empty():
		return payload
	var parsed: Variant = JSON.parse_string(clipboard_text)
	if parsed == null:
		return payload
	# Some tools may put a JSON string literal on clipboard; parse one extra layer.
	if parsed is String:
		var parsed_twice: Variant = JSON.parse_string(String(parsed))
		if parsed_twice != null:
			parsed = parsed_twice
	if parsed is not Dictionary:
		return payload
	var parsed_dict: Dictionary = parsed
	payload = _parse_payload_dict_to_voxel_map(parsed_dict)
	return payload


func _find_cortical_area_by_id(area_id: StringName) -> AbstractCorticalArea:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null or FeagiCore.feagi_local_cache.cortical_areas == null:
		return null
	var available_areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	if available_areas.has(area_id):
		return available_areas[area_id] as AbstractCorticalArea
	var area_id_string: String = String(area_id)
	for key in available_areas.keys():
		if String(key) == area_id_string:
			return available_areas[key] as AbstractCorticalArea
	return null


func _choose_clipboard_area_for_target(clipboard_payload: Dictionary, is_source: bool) -> StringName:
	var preferred_area: AbstractCorticalArea = _source if is_source else _destination
	if preferred_area != null and clipboard_payload.has(preferred_area.cortical_ID):
		return preferred_area.cortical_ID
	var other_side_area: AbstractCorticalArea = _destination if is_source else _source
	if other_side_area != null:
		for area_id in clipboard_payload.keys():
			if String(area_id) != String(other_side_area.cortical_ID):
				return area_id
	var ids: Array[StringName] = clipboard_payload.keys()
	ids.sort()
	if ids.is_empty():
		return &""
	return ids[0]


func _resolve_clipboard_area_entries(clipboard_payload: Dictionary) -> Dictionary[StringName, Dictionary]:
	var resolved: Dictionary[StringName, Dictionary] = {}
	for area_id in clipboard_payload.keys():
		var area_name: StringName = StringName(String(area_id))
		var area: AbstractCorticalArea = _find_cortical_area_by_id(area_name)
		if area == null:
			continue
		var voxels: Array[Vector3i] = clipboard_payload[area_id]
		resolved[area_name] = {"area": area, "voxels": voxels}
	return resolved


func _first_area_id_from_entries(entries: Dictionary[StringName, Dictionary], preferred_id: StringName = &"") -> StringName:
	if preferred_id != &"" and entries.has(preferred_id):
		return preferred_id
	var keys: Array[StringName] = entries.keys()
	keys.sort()
	if keys.is_empty():
		return &""
	return keys[0]


func _build_batch_area_summary(batch_map: Dictionary[StringName, Array]) -> String:
	if batch_map.is_empty():
		return ""
	var area_ids: Array[StringName] = batch_map.keys()
	area_ids.sort()
	var lines: PackedStringArray = []
	for area_id in area_ids:
		var voxel_count: int = (batch_map[area_id] as Array).size()
		var area_obj: AbstractCorticalArea = _find_cortical_area_by_id(area_id)
		var area_name: String = String(area_id)
		if area_obj != null:
			area_name = "%s [%s]" % [String(area_obj.friendly_name), String(area_id)]
		lines.append("- %s: %d voxel(s)" % [area_name, voxel_count])
	return "\n".join(lines)


func _apply_clipboard_voxel_selection(is_source: bool) -> void:
	var clipboard_payload: Dictionary = _parse_clipboard_voxel_payload()
	if clipboard_payload.is_empty():
		if BV != null and BV.NOTIF != null:
			BV.NOTIF.add_notification("Clipboard does not contain voxel selection data.")
		_refresh_clipboard_paste_buttons()
		return
	var resolved_entries: Dictionary[StringName, Dictionary] = _resolve_clipboard_area_entries(clipboard_payload)
	if resolved_entries.is_empty():
		if BV != null and BV.NOTIF != null:
			BV.NOTIF.add_notification("Clipboard cortical areas are not available in current genome.")
		_refresh_clipboard_paste_buttons()
		return
	var preferred_area_id: StringName = _choose_clipboard_area_for_target(clipboard_payload, is_source)
	var selected_area_id: StringName = _first_area_id_from_entries(resolved_entries, preferred_area_id)
	if selected_area_id == &"":
		_refresh_clipboard_paste_buttons()
		return
	var selected_entry: Dictionary = resolved_entries[selected_area_id]
	var selected_area: AbstractCorticalArea = selected_entry.get("area", null) as AbstractCorticalArea
	var selected_voxels: Array[Vector3i] = selected_entry.get("voxels", [])
	if is_source:
		_source = selected_area
		match _mode:
			MODE.CORTICAL_AREA_TO_NEURONS:
				_source_neuron_local_coords.clear()
				_source_batch_neurons_by_area.clear()
				_update_label_of_source_or_destination(true)
				_end_edit_source_config()
				_start_edit_destination_config()
			MODE.NEURONS_TO_CORTICAL_AREA:
				_source_batch_neurons_by_area.clear()
				for area_id in resolved_entries.keys():
					var entry: Dictionary = resolved_entries[area_id]
					var area_voxels: Array[Vector3i] = entry.get("voxels", [])
					if area_voxels.is_empty():
						continue
					_source_batch_neurons_by_area[area_id] = area_voxels.duplicate()
				if _source_batch_neurons_by_area.is_empty():
					if BV != null and BV.NOTIF != null:
						BV.NOTIF.add_notification("Clipboard has no source voxels for this mode.")
					_refresh_clipboard_paste_buttons()
					return
				var first_source_id: StringName = _first_area_id_from_entries(resolved_entries, selected_area_id)
				var first_source_entry: Dictionary = resolved_entries[first_source_id]
				_source = first_source_entry.get("area", _source) as AbstractCorticalArea
				_source_neuron_local_coords = (_source_batch_neurons_by_area[first_source_id] as Array).duplicate()
				_update_label_of_source_or_destination(true)
				_end_edit_source_config()
			MODE.NEURON_TO_NEURONS:
				_source_batch_neurons_by_area.clear()
				_source_neuron_local_coords = selected_voxels.duplicate()
				if _source_neuron_local_coords.size() > 1:
					_source_neuron_local_coords = [_source_neuron_local_coords[0]]
					if BV != null and BV.NOTIF != null:
						BV.NOTIF.add_notification("Source accepts one voxel in this mode; using the first pasted voxel.")
				if _source_neuron_local_coords.is_empty():
					if BV != null and BV.NOTIF != null:
						BV.NOTIF.add_notification("Clipboard has no source voxels for this mode.")
					_refresh_clipboard_paste_buttons()
					return
				_update_label_of_source_or_destination(true)
				_end_edit_source_config()
	else:
		_destination = selected_area
		match _mode:
			MODE.CORTICAL_AREA_TO_NEURONS:
				_destination_batch_neurons_by_area.clear()
				for area_id in resolved_entries.keys():
					var entry: Dictionary = resolved_entries[area_id]
					var area_voxels: Array[Vector3i] = entry.get("voxels", [])
					if area_voxels.is_empty():
						continue
					_destination_batch_neurons_by_area[area_id] = area_voxels.duplicate()
				if _destination_batch_neurons_by_area.is_empty():
					if BV != null and BV.NOTIF != null:
						BV.NOTIF.add_notification("Clipboard has no destination voxels for this mode.")
					_refresh_clipboard_paste_buttons()
					return
				var first_dest_id: StringName = _first_area_id_from_entries(resolved_entries, selected_area_id)
				var first_dest_entry: Dictionary = resolved_entries[first_dest_id]
				_destination = first_dest_entry.get("area", _destination) as AbstractCorticalArea
				_destination_neuron_local_coords = (_destination_batch_neurons_by_area[first_dest_id] as Array).duplicate()
				_update_label_of_source_or_destination(false)
				_end_edit_destination_config()
			MODE.NEURONS_TO_CORTICAL_AREA:
				_destination_batch_neurons_by_area.clear()
				_destination_neuron_local_coords.clear()
				_update_label_of_source_or_destination(false)
				_end_edit_destination_config()
			MODE.NEURON_TO_NEURONS:
				_destination_batch_neurons_by_area.clear()
				for area_id in resolved_entries.keys():
					var entry: Dictionary = resolved_entries[area_id]
					var area_voxels: Array[Vector3i] = entry.get("voxels", [])
					if area_voxels.is_empty():
						continue
					_destination_batch_neurons_by_area[area_id] = area_voxels.duplicate()
				if _destination_batch_neurons_by_area.is_empty():
					if BV != null and BV.NOTIF != null:
						BV.NOTIF.add_notification("Clipboard has no destination voxels for this mode.")
					_refresh_clipboard_paste_buttons()
					return
				var first_dest_n2n_id: StringName = _first_area_id_from_entries(resolved_entries, selected_area_id)
				var first_dest_n2n_entry: Dictionary = resolved_entries[first_dest_n2n_id]
				_destination = first_dest_n2n_entry.get("area", _destination) as AbstractCorticalArea
				_destination_neuron_local_coords = (_destination_batch_neurons_by_area[first_dest_n2n_id] as Array).duplicate()
				_update_label_of_source_or_destination(false)
				_end_edit_destination_config()
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if _mapping_edit_button.disabled:
		_mapping_label.text = "Waiting..."
	else:
		_define_pattern_morphology_label()
		_establish_button.disabled = false
	if BV != null and BV.NOTIF != null:
		if is_source and not _source_batch_neurons_by_area.is_empty():
			BV.NOTIF.add_notification("Pasted source voxels from %d areas." % _source_batch_neurons_by_area.size())
		elif (not is_source) and not _destination_batch_neurons_by_area.is_empty():
			BV.NOTIF.add_notification("Pasted destination voxels from %d areas." % _destination_batch_neurons_by_area.size())
	_refresh_clipboard_paste_buttons()


func _refresh_clipboard_paste_buttons() -> void:
	var clipboard_payload: Dictionary = _parse_clipboard_voxel_payload()
	var has_clipboard_voxels: bool = not clipboard_payload.is_empty()
	if _source_paste_button != null:
		var source_waiting: bool = _source_panel != null and _source_panel.theme_type_variation == "PanelContainer_QC_waiting"
		_source_paste_button.disabled = not has_clipboard_voxels or not source_waiting
		_source_paste_button.tooltip_text = "Paste voxel selection from clipboard" if has_clipboard_voxels else "Clipboard has no voxel selection payload"
	if _destination_paste_button != null:
		var destination_waiting: bool = _destination_panel != null and _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"
		_destination_paste_button.disabled = not has_clipboard_voxels or not destination_waiting
		_destination_paste_button.tooltip_text = "Paste voxel selection from clipboard" if has_clipboard_voxels else "Clipboard has no voxel selection payload"

func _define_pattern_morphology_label() -> void:
	var text: String = "Source: %s, Destination: %s\n" % [_source.friendly_name, _destination.friendly_name]
	if _source is MemoryCorticalArea:
		text += "Connectivity Rule Type: Projector\n"
		text += "Using Default Projector Settings"
	elif _destination is MemoryCorticalArea:
		text += "Connectivity Rule Type: Memory\n"
		text += "Using Default Memory Settings"
	else:
		text += "Connectivity Rule Type: Pattern\n"
		if not _source_batch_neurons_by_area.is_empty() or not _destination_batch_neurons_by_area.is_empty():
			var src_area_count: int = _source_batch_neurons_by_area.size() if not _source_batch_neurons_by_area.is_empty() else 1
			var dst_area_count: int = _destination_batch_neurons_by_area.size() if not _destination_batch_neurons_by_area.is_empty() else 1
			text += "Batch mode: %d source area(s) -> %d destination area(s)\n" % [src_area_count, dst_area_count]
		match _mode:
			MODE.CORTICAL_AREA_TO_NEURONS:
				if not _destination_batch_neurons_by_area.is_empty():
					for area_id in _destination_batch_neurons_by_area.keys():
						var vox: Array = _destination_batch_neurons_by_area[area_id]
						text += "%s: %d destination voxel(s)\n" % [String(area_id), vox.size()]
				else:
					for vec in _destination_neuron_local_coords:
						text += "[*, *, *] -> [%d, %d, %d]\n" % [vec.x, vec.y, vec.z]
			MODE.NEURONS_TO_CORTICAL_AREA:
				if not _source_batch_neurons_by_area.is_empty():
					for area_id in _source_batch_neurons_by_area.keys():
						var vox: Array = _source_batch_neurons_by_area[area_id]
						text += "%s: %d source voxel(s)\n" % [String(area_id), vox.size()]
				else:
					for vec in _source_neuron_local_coords:
						text += "[%d, %d, %d] -> [*, *, *]\n" % [vec.x, vec.y, vec.z]
			MODE.NEURON_TO_NEURONS:
				if not _destination_batch_neurons_by_area.is_empty():
					for area_id in _destination_batch_neurons_by_area.keys():
						var vox: Array = _destination_batch_neurons_by_area[area_id]
						text += "%s: %d destination voxel(s)\n" % [String(area_id), vox.size()]
				else:
					for vec in _destination_neuron_local_coords:
						text += "[%d, %d, %d] -> [%d, %d, %d]\n" % [_source_neuron_local_coords[0].x, _source_neuron_local_coords[0].y, _source_neuron_local_coords[0].z, vec.x, vec.y, vec.z]
			_:
			# HOW
				return
	_mapping_label.text = text


func _build_unique_morphology_name(base_name: StringName) -> StringName:
	var output_name: StringName = base_name.left(16)
	while output_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
		output_name += "2"
	return output_name


func _append_pattern_mapping_for_job(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea, source_voxels: Array[Vector3i], destination_voxels: Array[Vector3i]) -> FeagiRequestOutput:
	var morphology_name: StringName = _build_unique_morphology_name(source_area.cortical_ID + "_" + destination_area.cortical_ID)
	var pairs: Array[PatternVector3Pairs] = []
	match(_mode):
		MODE.CORTICAL_AREA_TO_NEURONS:
			for vec in destination_voxels:
				var incoming_any: PatternVector3 = PatternVector3.new(PatternVal.new("*"), PatternVal.new("*"), PatternVal.new("*"))
				var outgoing_any: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
				pairs.append(PatternVector3Pairs.new(incoming_any, outgoing_any))
		MODE.NEURONS_TO_CORTICAL_AREA:
			for vec in source_voxels:
				var incoming_sel: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
				var outgoing_all: PatternVector3 = PatternVector3.new(PatternVal.new("*"), PatternVal.new("*"), PatternVal.new("*"))
				pairs.append(PatternVector3Pairs.new(incoming_sel, outgoing_all))
		MODE.NEURON_TO_NEURONS:
			if source_voxels.is_empty():
				return FeagiRequestOutput.requirement_fail(&"INVALID_SOURCE_VOXELS")
			var src_vec: Vector3i = source_voxels[0]
			for vec in destination_voxels:
				var incoming_src: PatternVector3 = PatternVector3.new(PatternVal.new(src_vec.x), PatternVal.new(src_vec.y), PatternVal.new(src_vec.z))
				var outgoing_dst: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
				pairs.append(PatternVector3Pairs.new(incoming_src, outgoing_dst))
		_:
			return FeagiRequestOutput.requirement_fail(&"UNKNOWN_MODE")
	if pairs.is_empty():
		return FeagiRequestOutput.requirement_fail(&"NO_PATTERN_PAIRS")
	var create_out: FeagiRequestOutput = await FeagiCore.requests.add_pattern_morphology(morphology_name, pairs)
	if not create_out.success:
		return create_out
	var new_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name]
	return await FeagiCore.requests.append_default_mapping_between_corticals(
		source_area,
		destination_area,
		new_morphology,
	)


func _establish() -> void:
	if _establishing: # prevent multiple click spam
		return
	if !_has_enough_information_for_mapping():
		close_window()
		return
	_confirm_establish_mapping()

func _confirm_establish_mapping() -> void:
	if _establishing:
		return
	_establishing = true
	if _source is MemoryCorticalArea:
		var associative_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["associative_memory"]
		var out_mem: FeagiRequestOutput = await FeagiCore.requests.append_default_mapping_between_corticals(
			_source,
			_destination,
			associative_morphology,
		)
		_establishing = false
		if out_mem.failed_requirement and out_mem.failed_requirement_key in [
			&"USER_CANCELLED_DESIGNATION",
			&"USER_CANCELLED_ALL_TO_ALL",
		]:
			return
		if out_mem.success:
			close_window()
		return
	elif _destination is MemoryCorticalArea:
		var memory_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["episodic_memory"]
		var out_ep: FeagiRequestOutput = await FeagiCore.requests.append_default_mapping_between_corticals(
			_source,
			_destination,
			memory_morphology,
		)
		_establishing = false
		if out_ep.failed_requirement and out_ep.failed_requirement_key in [
			&"USER_CANCELLED_DESIGNATION",
			&"USER_CANCELLED_ALL_TO_ALL",
		]:
			return
		if out_ep.success:
			close_window()
		return
	else:
		var source_sets: Array[Dictionary] = []
		var destination_sets: Array[Dictionary] = []
		if _source_batch_neurons_by_area.is_empty():
			source_sets.append({"area": _source, "voxels": _source_neuron_local_coords.duplicate()})
		else:
			for area_id in _source_batch_neurons_by_area.keys():
				var area_obj: AbstractCorticalArea = _find_cortical_area_by_id(area_id)
				if area_obj == null:
					continue
				source_sets.append({"area": area_obj, "voxels": (_source_batch_neurons_by_area[area_id] as Array).duplicate()})
		if _destination_batch_neurons_by_area.is_empty():
			destination_sets.append({"area": _destination, "voxels": _destination_neuron_local_coords.duplicate()})
		else:
			for area_id in _destination_batch_neurons_by_area.keys():
				var area_obj: AbstractCorticalArea = _find_cortical_area_by_id(area_id)
				if area_obj == null:
					continue
				destination_sets.append({"area": area_obj, "voxels": (_destination_batch_neurons_by_area[area_id] as Array).duplicate()})
		var jobs: Array[Dictionary] = []
		match _mode:
			MODE.CORTICAL_AREA_TO_NEURONS:
				for dest_set in destination_sets:
					var dest_area: AbstractCorticalArea = dest_set.get("area", null) as AbstractCorticalArea
					var dest_voxels: Array[Vector3i] = dest_set.get("voxels", [])
					if dest_area == null or dest_voxels.is_empty():
						continue
					jobs.append({"source": _source, "destination": dest_area, "source_voxels": [], "destination_voxels": dest_voxels})
			MODE.NEURONS_TO_CORTICAL_AREA:
				for src_set in source_sets:
					var src_area: AbstractCorticalArea = src_set.get("area", null) as AbstractCorticalArea
					var src_voxels: Array[Vector3i] = src_set.get("voxels", [])
					if src_area == null or src_voxels.is_empty():
						continue
					jobs.append({"source": src_area, "destination": _destination, "source_voxels": src_voxels, "destination_voxels": []})
			MODE.NEURON_TO_NEURONS:
				if _source_neuron_local_coords.is_empty():
					_establishing = false
					return
				var one_source_voxel: Array[Vector3i] = [_source_neuron_local_coords[0]]
				for dest_set in destination_sets:
					var dest_area: AbstractCorticalArea = dest_set.get("area", null) as AbstractCorticalArea
					var dest_voxels: Array[Vector3i] = dest_set.get("voxels", [])
					if dest_area == null or dest_voxels.is_empty():
						continue
					jobs.append({"source": _source, "destination": dest_area, "source_voxels": one_source_voxel, "destination_voxels": dest_voxels})
		if jobs.is_empty():
			_establishing = false
			return
		var success_count: int = 0
		for job in jobs:
			var source_area_job: AbstractCorticalArea = job.get("source", null) as AbstractCorticalArea
			var destination_area_job: AbstractCorticalArea = job.get("destination", null) as AbstractCorticalArea
			var source_voxels_job: Array[Vector3i] = []
			var destination_voxels_job: Array[Vector3i] = []
			var source_voxels_raw: Variant = job.get("source_voxels", [])
			if source_voxels_raw is Array:
				for voxel in source_voxels_raw:
					if voxel is Vector3i:
						source_voxels_job.append(voxel)
			var destination_voxels_raw: Variant = job.get("destination_voxels", [])
			if destination_voxels_raw is Array:
				for voxel in destination_voxels_raw:
					if voxel is Vector3i:
						destination_voxels_job.append(voxel)
			var out_pat: FeagiRequestOutput = await _append_pattern_mapping_for_job(
				source_area_job,
				destination_area_job,
				source_voxels_job,
				destination_voxels_job,
			)
			if out_pat.failed_requirement and out_pat.failed_requirement_key in [
				&"USER_CANCELLED_DESIGNATION",
				&"USER_CANCELLED_ALL_TO_ALL",
			]:
				_establishing = false
				return
			if out_pat.success:
				success_count += 1
		_establishing = false
		if success_count == jobs.size():
			close_window()
			return
		if BV != null and BV.NOTIF != null:
			BV.NOTIF.add_notification("Created %d/%d quick-connect mappings." % [success_count, jobs.size()])

## True only while "area -> specific neuron block" is actively waiting for destination voxel picking.
func is_waiting_for_single_destination_voxel_selection() -> bool:
	if _mode != MODE.CORTICAL_AREA_TO_NEURONS:
		return false
	if _destination_panel == null:
		return false
	return _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"

## Returns true when this window is waiting for any voxel selection step and main-click should pick voxels.
func expects_voxel_selection_on_primary_click() -> bool:
	if _source_panel == null or _destination_panel == null:
		return false

	var source_waiting: bool = _source_panel.theme_type_variation == "PanelContainer_QC_waiting"
	var destination_waiting: bool = _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return destination_waiting
		MODE.NEURONS_TO_CORTICAL_AREA:
			return source_waiting
		MODE.NEURON_TO_NEURONS:
			return source_waiting or destination_waiting
		_:
			return false

## Returns true when the active step expects selecting only a cortical area (not specific voxels).
func expects_entire_area_selection_on_primary_click() -> bool:
	if _source_panel == null or _destination_panel == null:
		return false

	var source_waiting: bool = _source_panel.theme_type_variation == "PanelContainer_QC_waiting"
	var destination_waiting: bool = _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return source_waiting
		MODE.NEURONS_TO_CORTICAL_AREA:
			return destination_waiting
		MODE.NEURON_TO_NEURONS:
			return false
		_:
			return false


func close_window():
	super()
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON)
	# Backward-safe cleanup in case a stale QUICK_CONNECT override was previously added.
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
