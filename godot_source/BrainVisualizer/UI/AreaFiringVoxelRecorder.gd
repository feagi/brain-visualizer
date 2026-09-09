extends RefCounted
class_name AreaFiringVoxelRecorder
## Accumulates fired voxel coordinates for selected cortical areas while recording is active.

signal recording_state_changed(is_recording: bool)
signal accumulation_updated()

var _monitored_areas: Array[AbstractCorticalArea] = []
var _monitored_area_ids: Dictionary[StringName, StringName] = {}
var _is_recording: bool = false
var _accumulated_by_area: Dictionary[StringName, Dictionary] = {}
var _burst_updates: int = 0
var _websocket_listener_connected: bool = false


func set_monitored_areas(areas: Array[AbstractCorticalArea]) -> void:
	if _is_recording:
		return
	_monitored_areas = areas.duplicate()
	_sync_monitored_area_ids()
	_reset_accumulation_state()


func start_recording() -> bool:
	if _monitored_areas.is_empty():
		return false
	if _is_recording:
		return true
	_reset_accumulation_state()
	_is_recording = true
	_connect_websocket_listener()
	recording_state_changed.emit(true)
	return true


func stop_recording() -> Dictionary:
	if not _is_recording:
		return build_clipboard_payload()
	_is_recording = false
	_disconnect_websocket_listener()
	recording_state_changed.emit(false)
	return build_clipboard_payload()


func cancel_recording() -> void:
	if not _is_recording:
		_reset_accumulation_state()
		return
	_is_recording = false
	_disconnect_websocket_listener()
	_reset_accumulation_state()
	recording_state_changed.emit(false)


func is_recording() -> bool:
	return _is_recording


func get_monitored_area_count() -> int:
	return _monitored_areas.size()


func get_total_voxel_count() -> int:
	var total: int = 0
	for area_id in _accumulated_by_area.keys():
		var info: Dictionary = _accumulated_by_area[area_id]
		var voxels: Dictionary = info.get("voxels", {})
		total += voxels.size()
	return total


func get_burst_update_count() -> int:
	return _burst_updates


static func voxel_key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func merge_bulk_coordinates_into_area_entry(
	area_entry: Dictionary,
	x_array: PackedInt32Array,
	y_array: PackedInt32Array,
	z_array: PackedInt32Array,
) -> int:
	var added: int = 0
	var voxels: Dictionary = area_entry.get("voxels", {})
	var count: int = mini(x_array.size(), mini(y_array.size(), z_array.size()))
	for i in count:
		var key: String = voxel_key(x_array[i], y_array[i], z_array[i])
		if voxels.has(key):
			continue
		voxels[key] = [x_array[i], y_array[i], z_array[i]]
		added += 1
	area_entry["voxels"] = voxels
	return added


static func resolve_monitored_area_id(
	monitored_area_ids: Dictionary[StringName, StringName],
	cortical_id: StringName,
) -> StringName:
	var lookup_key: String = String(cortical_id).to_lower()
	if monitored_area_ids.has(lookup_key):
		return monitored_area_ids[lookup_key]
	return &""


func build_clipboard_payload() -> Dictionary:
	var by_cortical_id: Dictionary = {}
	var areas: Array[Dictionary] = []
	var area_keys: Array[StringName] = _accumulated_by_area.keys()
	area_keys.sort()
	var total_voxels: int = 0
	for area_id in area_keys:
		var info: Dictionary = _accumulated_by_area[area_id]
		var voxel_map: Dictionary = info.get("voxels", {})
		var encoded_voxels: Array = []
		var voxel_keys: Array = voxel_map.keys()
		voxel_keys.sort()
		for voxel_key_name in voxel_keys:
			var voxel: Variant = voxel_map[voxel_key_name]
			if voxel is Array:
				encoded_voxels.append(voxel)
		total_voxels += encoded_voxels.size()
		by_cortical_id[String(area_id)] = encoded_voxels
		areas.append({
			"cortical_id": String(area_id),
			"friendly_name": String(info.get("friendly_name", "")),
			"voxel_count": encoded_voxels.size(),
			"voxels": encoded_voxels,
		})
	return {
		"area_count": area_keys.size(),
		"total_voxel_count": total_voxels,
		"by_cortical_id": by_cortical_id,
		"areas": areas,
	}


func get_status_text() -> String:
	var area_count: int = get_monitored_area_count()
	if area_count == 0:
		return "No cortical areas selected."
	if _is_recording:
		return "Recording... %d unique voxels from %d area(s), %d burst update(s)." % [
			get_total_voxel_count(),
			area_count,
			_burst_updates,
		]
	var captured: int = get_total_voxel_count()
	if captured == 0:
		return "%d area(s) ready. Press Start Recording to capture fired voxels." % area_count
	return "Stopped. Captured %d unique voxel(s) from %d area(s)." % [captured, area_count]


func get_area_summary_text() -> String:
	if _monitored_areas.is_empty():
		return ""
	var names: PackedStringArray = []
	for area in _monitored_areas:
		if area == null:
			continue
		var label: String = String(area.friendly_name)
		if label.is_empty():
			label = String(area.cortical_ID)
		names.append(label)
	if names.is_empty():
		return ""
	return "Monitoring: " + ", ".join(names)


func _sync_monitored_area_ids() -> void:
	_monitored_area_ids.clear()
	for area in _monitored_areas:
		if area == null:
			continue
		var lookup_key: String = String(area.cortical_ID).to_lower()
		_monitored_area_ids[lookup_key] = area.cortical_ID


func _reset_accumulation_state() -> void:
	_accumulated_by_area.clear()
	_burst_updates = 0
	for area in _monitored_areas:
		if area == null:
			continue
		_accumulated_by_area[area.cortical_ID] = {
			"friendly_name": String(area.friendly_name),
			"voxels": {},
		}


func _get_websocket_api() -> FEAGIWebSocketAPI:
	if FeagiCore == null or FeagiCore.network == null:
		return null
	return FeagiCore.network.websocket_API


func _connect_websocket_listener() -> void:
	var websocket_api: FEAGIWebSocketAPI = _get_websocket_api()
	if websocket_api == null:
		return
	if not websocket_api.FEAGI_sent_direct_neural_points_bulk.is_connected(_on_websocket_bulk_firing):
		websocket_api.FEAGI_sent_direct_neural_points_bulk.connect(_on_websocket_bulk_firing)
	_websocket_listener_connected = true
	var cortical_ids: Array[StringName] = []
	for area in _monitored_areas:
		if area != null:
			cortical_ids.append(area.cortical_ID)
	websocket_api.bv_set_type11_bulk_dispatch_cortical_ids(cortical_ids)


func _disconnect_websocket_listener() -> void:
	var websocket_api: FEAGIWebSocketAPI = _get_websocket_api()
	if websocket_api != null:
		if websocket_api.FEAGI_sent_direct_neural_points_bulk.is_connected(_on_websocket_bulk_firing):
			websocket_api.FEAGI_sent_direct_neural_points_bulk.disconnect(_on_websocket_bulk_firing)
		websocket_api.bv_clear_type11_bulk_dispatch_cortical_ids()
	_websocket_listener_connected = false


func _on_websocket_bulk_firing(
	cortical_id: StringName,
	x_array: PackedInt32Array,
	y_array: PackedInt32Array,
	z_array: PackedInt32Array,
	_p_array: PackedFloat32Array,
) -> void:
	if not _is_recording:
		return
	var area_id: StringName = resolve_monitored_area_id(_monitored_area_ids, cortical_id)
	if area_id == &"":
		return
	if not _accumulated_by_area.has(area_id):
		for area in _monitored_areas:
			if area != null and area.cortical_ID == area_id:
				_accumulated_by_area[area_id] = {
					"friendly_name": String(area.friendly_name),
					"voxels": {},
				}
				break
	var added: int = merge_bulk_coordinates_into_area_entry(
		_accumulated_by_area[area_id],
		x_array,
		y_array,
		z_array,
	)
	if x_array.size() > 0:
		_burst_updates += 1
	if added > 0 or x_array.size() > 0:
		accumulation_updated.emit()
