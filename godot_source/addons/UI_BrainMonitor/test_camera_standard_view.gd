extends SceneTree
## Unit and integration tests for Brain Monitor T/B/F/L/R camera angles.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_camera_standard_view.gd


const Views = preload("res://addons/UI_BrainMonitor/CameraStandardView.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_plain_keys_map_to_views()
	failures += _test_modified_repeat_and_release_are_ignored()
	failures += _test_orientations_match_brain_axes()
	failures += _test_camera_sits_on_the_named_side_of_the_brain()
	if failures == 0:
		print("CameraStandardView tests: PASS")
		quit(0)
	else:
		push_error("CameraStandardView tests: FAIL (%d)" % failures)
		quit(1)


func _test_plain_keys_map_to_views() -> int:
	if Views.view_from_key(KEY_T, KEY_NONE, true, false, false, false, false) != Views.VIEW.TOP:
		push_error("T must snap to the top view")
		return 1
	if Views.view_from_key(KEY_B, KEY_NONE, true, false, false, false, false) != Views.VIEW.BOTTOM:
		push_error("B must snap to the bottom view")
		return 1
	if Views.view_from_key(KEY_F, KEY_NONE, true, false, false, false, false) != Views.VIEW.FRONT:
		push_error("F must snap to the front view")
		return 1
	if Views.view_from_key(KEY_NONE, KEY_L, true, false, false, false, false) != Views.VIEW.LEFT:
		push_error("L must snap to the left view when only the physical key is set")
		return 1
	if Views.view_from_key(KEY_R, KEY_NONE, true, false, false, false, false) != Views.VIEW.RIGHT:
		push_error("R must snap to the right view")
		return 1
	if Views.view_from_key(KEY_HOME, KEY_HOME, true, false, false, false, false) != -1:
		push_error("Home must stay the framing reset, not a side view")
		return 1
	return 0


func _test_modified_repeat_and_release_are_ignored() -> int:
	if Views.view_from_key(KEY_T, KEY_T, true, false, true, false, false) != -1:
		push_error("Ctrl or Cmd + T must not change the camera")
		return 1
	if Views.view_from_key(KEY_F, KEY_F, true, false, false, true, false) != -1:
		push_error("Alt + F must not change the camera")
		return 1
	if Views.view_from_key(KEY_L, KEY_L, true, false, false, false, true) != -1:
		push_error("Shift + L must not change the camera")
		return 1
	if Views.view_from_key(KEY_B, KEY_B, true, true, false, false, false) != -1:
		push_error("Key repeat must not snap the camera again")
		return 1
	if Views.view_from_key(KEY_T, KEY_T, false, false, false, false, false) != -1:
		push_error("Key release must not snap the camera")
		return 1
	return 0


func _test_orientations_match_brain_axes() -> int:
	var top: Dictionary = Views.orientation(Views.VIEW.TOP)
	var bottom: Dictionary = Views.orientation(Views.VIEW.BOTTOM)
	var front: Dictionary = Views.orientation(Views.VIEW.FRONT)
	var left: Dictionary = Views.orientation(Views.VIEW.LEFT)
	var right: Dictionary = Views.orientation(Views.VIEW.RIGHT)
	if top[&"view_dir"] != Vector3(0, 1, 0) or top[&"up"] != Vector3(0, 0, -1):
		push_error("Top must look along +Y with FEAGI +Z at the top of the screen")
		return 1
	if bottom[&"view_dir"] != Vector3(0, -1, 0) or bottom[&"up"] != Vector3(0, 0, -1):
		push_error("Bottom must look along -Y with FEAGI +Z still at the top of the screen")
		return 1
	if front[&"view_dir"] != Vector3(0, 0, 1) or front[&"up"] != Vector3.UP:
		push_error("Front must place the camera on +Z with world Y up")
		return 1
	if left[&"view_dir"] != Vector3(-1, 0, 0) or left[&"up"] != Vector3.UP:
		push_error("Left must place the camera on -X with world Y up")
		return 1
	if right[&"view_dir"] != Vector3(1, 0, 0) or right[&"up"] != Vector3.UP:
		push_error("Right must place the camera on +X with world Y up")
		return 1
	if not Views.orientation(-1).is_empty():
		push_error("An unknown view id must not invent an orientation")
		return 1
	return 0


func _test_camera_sits_on_the_named_side_of_the_brain() -> int:
	var center := Vector3(10, 20, 30)
	var distance := 50.0
	var top := Views.camera_position(center, distance, Views.VIEW.TOP)
	var bottom := Views.camera_position(center, distance, Views.VIEW.BOTTOM)
	var front := Views.camera_position(center, distance, Views.VIEW.FRONT)
	var left := Views.camera_position(center, distance, Views.VIEW.LEFT)
	var right := Views.camera_position(center, distance, Views.VIEW.RIGHT)
	if top != center + Vector3(0, distance, 0):
		push_error("Top camera must sit above the brain on +Y")
		return 1
	if bottom != center + Vector3(0, -distance, 0):
		push_error("Bottom camera must sit below the brain on -Y")
		return 1
	if front != center + Vector3(0, 0, distance):
		push_error("Front camera must sit on +Z")
		return 1
	if left != center + Vector3(-distance, 0, 0):
		push_error("Left camera must sit on -X")
		return 1
	if right != center + Vector3(distance, 0, 0):
		push_error("Right camera must sit on +X")
		return 1
	return 0
