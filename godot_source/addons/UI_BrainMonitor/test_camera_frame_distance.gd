extends SceneTree
## Camera focus stands off from the face toward the camera, not from the volume midpoint.
## Run: godot --headless -s res://addons/UI_BrainMonitor/test_camera_frame_distance.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_long_depth_keeps_camera_outside_the_facing_surface()
	failures += _test_gap_is_added_past_the_surface()
	if failures == 0:
		print("Camera frame distance tests: PASS")
		quit(0)
	else:
		push_error("Camera frame distance tests: FAIL (%d)" % failures)
		quit(1)


func _test_long_depth_keeps_camera_outside_the_facing_surface() -> int:
	var scene_script: Script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd")
	var half_depth := 80.0
	var beyond_face := 12.0
	var from_center: float = scene_script.frame_distance_from_center(beyond_face, half_depth)
	if from_center <= half_depth:
		push_error("A long volume must place the camera past its facing surface")
		return 1
	if not is_equal_approx(from_center - half_depth, beyond_face):
		push_error("The stand-off must be measured from the facing surface, not the midpoint")
		return 1
	return 0


func _test_gap_is_added_past_the_surface() -> int:
	var scene_script: Script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd")
	var from_center: float = scene_script.frame_distance_from_center(30.0, 4.0)
	if not is_equal_approx(from_center, 34.0):
		push_error("Camera distance from the center must be half-depth plus the surface gap")
		return 1
	return 0
