extends RefCounted
class_name VoxelClipboardPayload
## Parses voxel-selection JSON from the clipboard and provides union helpers for paste workflows.


static func parse_from_clipboard_text(clipboard_text: String) -> Dictionary:
	var payload: Dictionary = {}
	var trimmed: String = clipboard_text.strip_edges()
	if trimmed.is_empty():
		return payload
	var parsed: Variant = JSON.parse_string(trimmed)
	if parsed == null:
		return payload
	# Some tools may put a JSON string literal on clipboard; parse one extra layer.
	if parsed is String:
		var parsed_twice: Variant = JSON.parse_string(String(parsed))
		if parsed_twice != null:
			parsed = parsed_twice
	if parsed is not Dictionary:
		return payload
	return parse_payload_dict_to_voxel_map(parsed)


static func parse_payload_dict_to_voxel_map(parsed_dict: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	if parsed_dict.has("areas") and parsed_dict["areas"] is Array:
		for area_entry in parsed_dict["areas"]:
			if area_entry is not Dictionary:
				continue
			var area_dict: Dictionary = area_entry
			var raw_id: String = String(area_dict.get("cortical_id", "")).strip_edges()
			if raw_id.is_empty():
				continue
			var voxels: Array[Vector3i] = extract_voxels_from_variant(area_dict.get("voxels", []))
			payload[StringName(raw_id)] = voxels
	if payload.is_empty() and parsed_dict.has("by_cortical_id") and parsed_dict["by_cortical_id"] is Dictionary:
		var by_cortical_id: Dictionary = parsed_dict["by_cortical_id"]
		for raw_area_id in by_cortical_id.keys():
			var area_id: String = String(raw_area_id).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = extract_voxels_from_variant(by_cortical_id[raw_area_id])
			payload[StringName(area_id)] = voxels
	# Manual stimulation style: {"stimulation_payload": {"id": [[x,y,z], ...]}}
	if payload.is_empty() and parsed_dict.has("stimulation_payload") and parsed_dict["stimulation_payload"] is Dictionary:
		var stimulation_payload: Dictionary = parsed_dict["stimulation_payload"]
		for raw_area_id in stimulation_payload.keys():
			var area_id: String = String(raw_area_id).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = extract_voxels_from_variant(stimulation_payload[raw_area_id])
			payload[StringName(area_id)] = voxels
	# Direct shape: {"id": [[x,y,z], ...], ...}
	if payload.is_empty():
		for raw_key in parsed_dict.keys():
			var area_id: String = String(raw_key).strip_edges()
			if area_id.is_empty():
				continue
			var voxels: Array[Vector3i] = extract_voxels_from_variant(parsed_dict[raw_key])
			if not voxels.is_empty():
				payload[StringName(area_id)] = voxels
	return payload


static func union_all_voxels(payload: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var seen: Dictionary = {}
	for area_id in payload.keys():
		var voxels: Array[Vector3i] = payload[area_id]
		for voxel in voxels:
			var key: String = voxel_key(voxel.x, voxel.y, voxel.z)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(voxel)
	return out


static func voxel_key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func extract_voxels_from_variant(raw_voxels: Variant) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if raw_voxels is not Array:
		return out
	for entry in raw_voxels:
		if entry is Array:
			var arr: Array = entry
			if arr.size() >= 3:
				var x_value: Variant = variant_to_int_if_possible(arr[0])
				var y_value: Variant = variant_to_int_if_possible(arr[1])
				var z_value: Variant = variant_to_int_if_possible(arr[2])
				if x_value != null and y_value != null and z_value != null:
					out.append(Vector3i(int(x_value), int(y_value), int(z_value)))
	return out


static func variant_to_int_if_possible(value: Variant) -> Variant:
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
