extends SceneTree
## Unit tests for VoxelClipboardPayload parsing and union helpers.

const VoxelClipboardPayloadScript = preload("res://BrainVisualizer/UI/VoxelClipboardPayload.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_parse_areas_array_payload()
	failures += _test_parse_by_cortical_id_payload()
	failures += _test_union_all_voxels_deduplicates()
	failures += _test_parse_double_encoded_json_string()
	if failures == 0:
		print("VoxelClipboardPayload tests: PASS")
		quit(0)
	else:
		push_error("VoxelClipboardPayload tests: FAIL (%d)" % failures)
		quit(1)


func _test_parse_areas_array_payload() -> int:
	var json_text: String = JSON.stringify({
		"area_count": 1,
		"total_voxel_count": 2,
		"areas": [{
			"cortical_id": "area_a",
			"friendly_name": "Area A",
			"voxel_count": 2,
			"voxels": [[1, 2, 3], [4, 5, 6]],
		}],
	})
	var payload: Dictionary = VoxelClipboardPayloadScript.parse_from_clipboard_text(json_text)
	if not payload.has(&"area_a"):
		push_error("parse_from_clipboard_text missing area_a from areas array payload")
		return 1
	var voxels: Array[Vector3i] = payload[&"area_a"]
	if voxels.size() != 2:
		push_error("parse_from_clipboard_text expected 2 voxels, got %d" % voxels.size())
		return 1
	if voxels[0] != Vector3i(1, 2, 3):
		push_error("parse_from_clipboard_text first voxel mismatch")
		return 1
	return 0


func _test_parse_by_cortical_id_payload() -> int:
	var json_text: String = JSON.stringify({
		"by_cortical_id": {
			"area_b": [[7, 8, 9]],
		},
	})
	var payload: Dictionary = VoxelClipboardPayloadScript.parse_from_clipboard_text(json_text)
	if not payload.has(&"area_b"):
		push_error("parse_from_clipboard_text missing area_b from by_cortical_id payload")
		return 1
	var voxels: Array[Vector3i] = payload[&"area_b"]
	if voxels.size() != 1 or voxels[0] != Vector3i(7, 8, 9):
		push_error("parse_from_clipboard_text by_cortical_id voxel mismatch")
		return 1
	return 0


func _test_union_all_voxels_deduplicates() -> int:
	var payload: Dictionary = {
		&"area_a": [Vector3i(1, 2, 3), Vector3i(4, 5, 6)] as Array[Vector3i],
		&"area_b": [Vector3i(1, 2, 3), Vector3i(7, 8, 9)] as Array[Vector3i],
	}
	var union_voxels: Array[Vector3i] = VoxelClipboardPayloadScript.union_all_voxels(payload)
	if union_voxels.size() != 3:
		push_error("union_all_voxels expected 3 unique voxels, got %d" % union_voxels.size())
		return 1
	return 0


func _test_parse_double_encoded_json_string() -> int:
	var inner: Dictionary = {
		"by_cortical_id": {
			"area_c": [[0, 1, 2]],
		},
	}
	var json_text: String = JSON.stringify(JSON.stringify(inner))
	var payload: Dictionary = VoxelClipboardPayloadScript.parse_from_clipboard_text(json_text)
	if not payload.has(&"area_c"):
		push_error("parse_from_clipboard_text failed for double-encoded JSON string")
		return 1
	return 0
