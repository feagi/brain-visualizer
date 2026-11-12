extends SceneTree
## Unit tests for VectorClipboardPayload (headless, static helpers only).

const Payload = preload("res://BrainVisualizer/UI/Windows/VisualVectorEdit/VectorClipboardPayload.gd")
const Grid = preload("res://BrainVisualizer/UI/Windows/VisualVectorEdit/VectorEditGrid.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_round_trip()
	failures += _test_paste_mapping_and_merge()
	failures += _test_rejects()
	failures += _test_not_a_voxel_payload()
	if failures == 0:
		print("VectorClipboardPayload tests: PASS")
		quit(0)
	else:
		push_error("VectorClipboardPayload tests: FAIL (%d)" % failures)
		quit(1)


func _fail(msg: String) -> int:
	push_error(msg)
	return 1


func _vecs(items: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for i in items:
		out.append(i)
	return out


func _test_round_trip() -> int:
	var v: Array[Vector3i] = _vecs([Vector3i(1, 2, 3), Vector3i(-4, 0, -2), Vector3i(1, 2, 3)])
	var all_d: Dictionary = Payload.decode(Payload.encode("all", v))
	if all_d.get("scope", "") != "all" or all_d.get("vectors", []) != _vecs([Vector3i(1, 2, 3), Vector3i(-4, 0, -2)]):
		return _fail("all round trip wrong: %s" % str(all_d))
	var sl_d: Dictionary = Payload.decode(Payload.encode("slice", v))
	if sl_d.get("scope", "") != "slice" or sl_d.get("vectors", []) != _vecs([Vector3i(1, 2, 0), Vector3i(-4, 0, 0)]):
		return _fail("slice round trip wrong (z must be 0): %s" % str(sl_d))
	var wrapped: Dictionary = Payload.decode(JSON.stringify(Payload.encode("all", v)))
	if wrapped.is_empty():
		return _fail("JSON string-literal wrapper not tolerated")
	return 0


func _test_paste_mapping_and_merge() -> int:
	var sel: Dictionary = {"0,0,0": true, "9,9,5": true}
	var slice_out: Dictionary = Grid.merge_vectors(sel, "slice", _vecs([Vector3i(1, 1, 0), Vector3i(2, 2, 0)]), 3)
	if not slice_out.has("1,1,3") or not slice_out.has("2,2,3") or slice_out.has("1,1,0"):
		return _fail("slice paste must land on current z: %s" % str(slice_out.keys()))
	var all_out: Dictionary = Grid.merge_vectors(sel, "all", _vecs([Vector3i(1, 1, -2), Vector3i(2, 2, 7)]), 3)
	if not all_out.has("1,1,-2") or not all_out.has("2,2,7"):
		return _fail("all paste must keep z: %s" % str(all_out.keys()))
	for out in [slice_out, all_out]:
		for k in sel.keys():
			if not out.has(k):
				return _fail("merge removed key %s" % k)
	return 0


func _test_rejects() -> int:
	var bad: Array[String] = [
		"",
		"not json",
		"[1,2,3]",
		'{"feagi_vectors": 5}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1,2]]}}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1,2,3,4]]}}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1.5,2,3]]}}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1,2,"a"]]}}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1,2,null]]}}',
		'{"feagi_vectors": {"scope": "slice", "vectors": [[1,2,3], "x"]}}',
		'{"feagi_vectors": {"scope": "plane", "vectors": [[1,2,3]]}}',
		'{"feagi_vectors": {"vectors": [[1,2,3]]}}',
		'{"feagi_vectors": {"scope": "all"}}',
	]
	for t in bad:
		if not Payload.decode(t).is_empty():
			return _fail("should reject: %s" % t)
	var many: Array[Vector3i] = []
	for i in Payload.MAX_VECTORS + 1:
		many.append(Vector3i(i, 0, 0))
	if not Payload.decode(Payload.encode("all", many)).is_empty():
		return _fail("more than 10000 vectors must reject")
	many.pop_back()
	if Payload.decode(Payload.encode("all", many)).is_empty():
		return _fail("exactly 10000 vectors must be accepted")
	return 0


func _test_not_a_voxel_payload() -> int:
	var text: String = Payload.encode("all", _vecs([Vector3i(1, 2, 3)]))
	if not VoxelClipboardPayload.parse_from_clipboard_text(text).is_empty():
		return _fail("voxel parser must not read a vector payload")
	return 0
