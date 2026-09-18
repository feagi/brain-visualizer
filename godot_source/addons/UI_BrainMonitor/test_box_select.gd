extends SceneTree
## Unit and integration tests for Brain Monitor Shift+drag box selection.


const BoxSelectScript = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_BoxSelect.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_normalized_rect_order_independent()
	failures += _test_drag_threshold()
	failures += _test_session_press_without_drag_stays_pressing()
	failures += _test_session_drag_transitions_and_finish()
	failures += _test_session_reset_is_idle()
	failures += _test_zero_area_selection_selects_nothing()
	failures += _test_point_bounds_inside_selection()
	failures += _test_projected_aabb_overlap_and_miss()
	failures += _test_behind_camera_corners_are_excluded()
	failures += _test_collect_overlapping_objects_integration()
	if failures == 0:
		print("BoxSelect tests: PASS")
		quit(0)
	else:
		push_error("BoxSelect tests: FAIL (%d)" % failures)
		quit(1)


func _test_normalized_rect_order_independent() -> int:
	var a: Rect2 = BoxSelectScript.normalized_rect(Vector2(10, 20), Vector2(40, 80))
	var b: Rect2 = BoxSelectScript.normalized_rect(Vector2(40, 80), Vector2(10, 20))
	if a != b:
		push_error("normalized_rect must be independent of corner order")
		return 1
	if a.position != Vector2(10, 20) or a.size != Vector2(30, 60):
		push_error("normalized_rect produced unexpected geometry %s" % a)
		return 1
	return 0


func _test_drag_threshold() -> int:
	if BoxSelectScript.is_drag_distance(Vector2.ZERO, Vector2(1.9, 0), BoxSelectScript.MIN_DRAG_DISTANCE):
		push_error("movement under MIN_DRAG_DISTANCE must not count as a drag")
		return 1
	if not BoxSelectScript.is_drag_distance(Vector2.ZERO, Vector2(2.0, 0), BoxSelectScript.MIN_DRAG_DISTANCE):
		push_error("movement at MIN_DRAG_DISTANCE must count as a drag")
		return 1
	return 0


func _test_session_press_without_drag_stays_pressing() -> int:
	var session = BoxSelectScript.new()
	session.begin_press(Vector2(5, 5))
	session.update_pointer(Vector2(6, 5))
	if session.phase != BoxSelectScript.PHASE.PRESSING:
		push_error("sub-threshold movement must remain PRESSING so Shift+click can toggle voxels")
		return 1
	if session.finish() != BoxSelectScript.PHASE.PRESSING:
		push_error("finish after a click must report PRESSING")
		return 1
	return 0


func _test_session_drag_transitions_and_finish() -> int:
	var session = BoxSelectScript.new()
	session.begin_press(Vector2(0, 0))
	session.update_pointer(Vector2(20, 10))
	if not session.is_dragging():
		push_error("pointer movement past the drag threshold must enter DRAGGING")
		return 1
	var rect: Rect2 = session.get_screen_rect()
	if rect.size != Vector2(20, 10):
		push_error("drag rect size should be 20x10, got %s" % rect)
		return 1
	if session.finish() != BoxSelectScript.PHASE.DRAGGING:
		push_error("finish after a drag must report DRAGGING")
		return 1
	if session.is_active():
		push_error("finish must return the session to IDLE")
		return 1
	return 0


func _test_session_reset_is_idle() -> int:
	var session = BoxSelectScript.new()
	session.begin_press(Vector2(1, 1))
	session.update_pointer(Vector2(12, 12))
	session.reset()
	if session.is_active() or session.is_dragging():
		push_error("reset must clear an in-progress box select")
		return 1
	return 0


func _test_zero_area_selection_selects_nothing() -> int:
	var area_bounds: Rect2 = Rect2(Vector2(0, 0), Vector2(10, 10))
	var line: Rect2 = Rect2(Vector2(1, 1), Vector2(8, 0))
	if BoxSelectScript.screen_bounds_overlap_selection(area_bounds, line):
		push_error("a zero-height selection must not select areas")
		return 1
	return 0


func _test_point_bounds_inside_selection() -> int:
	var selection: Rect2 = Rect2(Vector2(0, 0), Vector2(10, 10))
	var point: Rect2 = Rect2(Vector2(3, 4), Vector2.ZERO)
	if not BoxSelectScript.screen_bounds_overlap_selection(point, selection):
		push_error("a degenerate area point inside the box must be selected")
		return 1
	var outside: Rect2 = Rect2(Vector2(20, 20), Vector2.ZERO)
	if BoxSelectScript.screen_bounds_overlap_selection(outside, selection):
		push_error("a degenerate area point outside the box must not be selected")
		return 1
	return 0


func _test_projected_aabb_overlap_and_miss() -> int:
	var aabb: AABB = AABB(Vector3.ZERO, Vector3.ONE)
	var points: Array[Vector2] = BoxSelectScript.project_aabb_corners(
		aabb,
		func(_p: Vector3) -> bool: return false,
		func(p: Vector3) -> Vector2: return Vector2(p.x, p.y),
	)
	var bounds: Rect2 = BoxSelectScript.screen_bounds_from_points(points)
	if not BoxSelectScript.screen_bounds_overlap_selection(bounds, Rect2(Vector2(0.25, 0.25), Vector2(0.2, 0.2))):
		push_error("selection inside a projected AABB must hit")
		return 1
	if BoxSelectScript.screen_bounds_overlap_selection(bounds, Rect2(Vector2(5, 5), Vector2(1, 1))):
		push_error("selection far from a projected AABB must miss")
		return 1
	return 0


func _test_behind_camera_corners_are_excluded() -> int:
	var aabb: AABB = AABB(Vector3.ZERO, Vector3.ONE)
	var points: Array[Vector2] = BoxSelectScript.project_aabb_corners(
		aabb,
		func(p: Vector3) -> bool: return p.x < 0.5,
		func(p: Vector3) -> Vector2: return Vector2(p.x, p.y),
	)
	if points.is_empty():
		push_error("visible AABB corners must still project when some are behind the camera")
		return 1
	for point in points:
		if point.x < 0.5:
			push_error("corners reported behind the camera must not be projected")
			return 1
	return 0


func _test_collect_overlapping_objects_integration() -> int:
	var area_a: StringName = &"area_a"
	var area_b: StringName = &"area_b"
	var area_c: StringName = &"area_c"
	var entries: Array = [
		{&"object": area_a, &"bounds": Rect2(Vector2(0, 0), Vector2(10, 10))},
		{&"object": area_b, &"bounds": Rect2(Vector2(20, 0), Vector2(10, 10))},
		{&"object": area_c, &"bounds": Rect2(Vector2(8, 8), Vector2(10, 10))},
	]
	var selected: Array = BoxSelectScript.collect_overlapping_objects(
		entries,
		Rect2(Vector2(5, 5), Vector2(10, 10)),
	)
	if selected.size() != 2 or area_a not in selected or area_c not in selected:
		push_error("box must select exactly the overlapping areas, got %s" % selected)
		return 1
	if area_b in selected:
		push_error("box must not select an area outside the rectangle")
		return 1
	return 0
