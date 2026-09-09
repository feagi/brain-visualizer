extends SceneTree
## Unit tests for AreaFiringVoxelRecorder coordinate accumulation and payload export.

const AreaFiringVoxelRecorderScript = preload("res://BrainVisualizer/UI/AreaFiringVoxelRecorder.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_voxel_key()
	failures += _test_merge_bulk_deduplicates()
	failures += _test_build_clipboard_payload()
	failures += _test_status_text_idle()
	failures += _test_resolve_monitored_area_id()
	if failures == 0:
		print("AreaFiringVoxelRecorder tests: PASS")
		quit(0)
	else:
		push_error("AreaFiringVoxelRecorder tests: FAIL (%d)" % failures)
		quit(1)


func _test_voxel_key() -> int:
	var recorder: RefCounted = AreaFiringVoxelRecorderScript.new()
	if recorder.voxel_key(1, 2, 3) != "1,2,3":
		push_error("voxel_key formatting failed")
		return 1
	return 0


func _test_merge_bulk_deduplicates() -> int:
	var recorder: RefCounted = AreaFiringVoxelRecorderScript.new()
	var area_entry: Dictionary = {"voxels": {}}
	var x_array := PackedInt32Array([1, 1, 4])
	var y_array := PackedInt32Array([2, 2, 5])
	var z_array := PackedInt32Array([3, 3, 6])
	var added_first: int = recorder.merge_bulk_coordinates_into_area_entry(area_entry, x_array, y_array, z_array)
	if added_first != 2:
		push_error("merge_bulk_coordinates_into_area_entry expected 2 unique voxels, got %d" % added_first)
		return 1
	var voxels: Dictionary = area_entry.get("voxels", {})
	if voxels.size() != 2:
		push_error("merge_bulk_coordinates_into_area_entry expected voxel map size 2, got %d" % voxels.size())
		return 1
	var added_second: int = recorder.merge_bulk_coordinates_into_area_entry(area_entry, x_array, y_array, z_array)
	if added_second != 0:
		push_error("merge_bulk_coordinates_into_area_entry expected 0 new voxels on duplicate merge")
		return 1
	return 0


func _test_build_clipboard_payload() -> int:
	var recorder: RefCounted = AreaFiringVoxelRecorderScript.new()
	recorder._accumulated_by_area = {
		&"area_a": {
			"friendly_name": "Area A",
			"voxels": {
				"1,2,3": [1, 2, 3],
				"4,5,6": [4, 5, 6],
			},
		},
	}
	var payload: Dictionary = recorder.build_clipboard_payload()
	if int(payload.get("area_count", 0)) != 1:
		push_error("build_clipboard_payload area_count mismatch")
		return 1
	if int(payload.get("total_voxel_count", 0)) != 2:
		push_error("build_clipboard_payload total_voxel_count mismatch")
		return 1
	var areas: Array = payload.get("areas", [])
	if areas.is_empty():
		push_error("build_clipboard_payload missing areas array")
		return 1
	var first_area: Dictionary = areas[0]
	if int(first_area.get("voxel_count", 0)) != 2:
		push_error("build_clipboard_payload per-area voxel_count mismatch")
		return 1
	return 0


func _test_status_text_idle() -> int:
	var recorder: RefCounted = AreaFiringVoxelRecorderScript.new()
	recorder._monitored_areas = [null, null]
	if not recorder.get_status_text().contains("2 area"):
		push_error("get_status_text idle summary mismatch")
		return 1
	return 0


func _test_resolve_monitored_area_id() -> int:
	var monitored: Dictionary[StringName, StringName] = {
		"abc123": &"ABC123",
	}
	var resolved: StringName = AreaFiringVoxelRecorderScript.resolve_monitored_area_id(monitored, &"abc123")
	if resolved != &"ABC123":
		push_error("resolve_monitored_area_id failed for matching id")
		return 1
	var missing: StringName = AreaFiringVoxelRecorderScript.resolve_monitored_area_id(monitored, &"missing")
	if missing != &"":
		push_error("resolve_monitored_area_id should return empty for unknown id")
		return 1
	return 0
