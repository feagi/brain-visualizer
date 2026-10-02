extends SceneTree
## Axis drag must not treat a camera-parallel ray as the camera's coordinate on that axis.
## That fallback wrote values like -74392 into the add-area X location.

const Gizmo = preload("res://addons/UI_BrainMonitor/Gizmos/UI_BrainMonitor_RuntimeTransformGizmo.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_ray_through_axis_returns_offset()
	failures += _test_parallel_ray_does_not_return_camera_offset()
	failures += _test_ray_far_from_axis_is_rejected()
	if failures == 0:
		print("Gizmo axis drag param tests: PASS")
		quit(0)
	else:
		push_error("Gizmo axis drag param tests: FAIL (%d)" % failures)
		quit(1)


func _test_ray_through_axis_returns_offset() -> int:
	# Camera on +Z, looking through world X = 4 on the X axis.
	var param: float = Gizmo.axis_drag_param(
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3(0, 0, 10),
		Vector3(4, 0, 0)
	)
	if is_nan(param) or absf(param - 4.0) > 0.05:
		push_error("Expected axis param 4, got %s" % param)
		return 1
	return 0


func _test_parallel_ray_does_not_return_camera_offset() -> int:
	# Looking along +X from a camera sitting far on -X. The old fallback returned ~-74392.
	var camera_x := -74392.0
	var param: float = Gizmo.axis_drag_param(
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3(camera_x, 20, 0),
		Vector3(camera_x + 100.0, 20, 0)
	)
	if not is_nan(param):
		push_error("Parallel ray must be rejected, got %s" % param)
		return 1
	return 0


func _test_ray_far_from_axis_is_rejected() -> int:
	var param: float = Gizmo.axis_drag_param(
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3(0, 80, 10),
		Vector3(0, 80, 0)
	)
	if not is_nan(param):
		push_error("Ray missing the axis must be rejected, got %s" % param)
		return 1
	return 0
