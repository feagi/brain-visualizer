extends SceneTree
## Unit and integration tests for orbiting the Brain Monitor camera around a pivot.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_camera_orbit.gd


const Orbit = preload("res://addons/UI_BrainMonitor/CameraOrbit.gd")
const PancakeCameraScript = preload("res://addons/UI_BrainMonitor/Cameras/UI_BrainMonitor_PancakeCamera.gd")

const PIVOT := Vector3(10, 5, -20)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_orbit_bindings()
	failures += _test_orbit_keeps_distance_and_framing()
	failures += _test_pitch_stops_short_of_the_poles()
	failures += _test_yaw_keeps_height_and_level_horizon()
	failures += _test_pivot_order()
	failures += _test_camera_orbit_press_never_reaches_the_scene()
	failures += _test_camera_orbit_ends_when_button_is_released_elsewhere()
	failures += _test_camera_orbit_turns_three_times_the_in_place_rate()
	if failures == 0:
		print("CameraOrbit tests: PASS")
		quit(0)
	else:
		push_error("CameraOrbit tests: FAIL (%d)" % failures)
		quit(1)


func _camera_looking_at_pivot(from: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, from).looking_at(PIVOT, Vector3.UP)


func _test_orbit_bindings() -> int:
	if not Orbit.is_orbit_press(MOUSE_BUTTON_MIDDLE, false):
		push_error("Middle drag must orbit")
		return 1
	if not Orbit.is_orbit_press(MOUSE_BUTTON_LEFT, true):
		push_error("Option/Alt + left drag must orbit")
		return 1
	if Orbit.is_orbit_press(MOUSE_BUTTON_LEFT, false):
		push_error("Plain left drag must stay pan")
		return 1
	if Orbit.is_orbit_press(MOUSE_BUTTON_RIGHT, true) or Orbit.is_orbit_press(MOUSE_BUTTON_RIGHT, false):
		push_error("Right drag must stay the in-place turn")
		return 1
	return 0


func _test_orbit_keeps_distance_and_framing() -> int:
	# Off-center pivot: the camera does not face it, and orbiting must not recenter it.
	var start := Transform3D(Basis(Vector3.UP, 0.3), PIVOT + Vector3(4, 6, 40))
	var start_distance: float = start.origin.distance_to(PIVOT)
	var start_local: Vector3 = start.affine_inverse() * PIVOT
	var moved: Transform3D = Orbit.orbit_transform(PIVOT, start, 0.7, -0.4)
	if not is_equal_approx(moved.origin.distance_to(PIVOT), start_distance):
		push_error("Orbit must keep the distance to the pivot")
		return 1
	if not (moved.affine_inverse() * PIVOT).is_equal_approx(start_local):
		push_error("Orbit must keep the pivot at the same place on screen")
		return 1
	if moved.origin.is_equal_approx(start.origin):
		push_error("Orbit must move the camera")
		return 1
	return 0


func _test_pitch_stops_short_of_the_poles() -> int:
	var start := _camera_looking_at_pivot(PIVOT + Vector3(0, 0, 30))
	var looking_down: Transform3D = Orbit.orbit_transform(PIVOT, start, 0.0, -10.0)
	if not is_equal_approx(Orbit.view_pitch(looking_down.basis), -Orbit.MAX_PITCH):
		push_error("Tilting far down must stop at the pitch limit")
		return 1
	if looking_down.origin.y <= PIVOT.y:
		push_error("Looking down at the pivot must place the camera above it")
		return 1
	var looking_up: Transform3D = Orbit.orbit_transform(PIVOT, start, 0.0, 10.0)
	if not is_equal_approx(Orbit.view_pitch(looking_up.basis), Orbit.MAX_PITCH):
		push_error("Tilting far up must stop at the pitch limit")
		return 1
	var pushed_again: Transform3D = Orbit.orbit_transform(PIVOT, looking_down, 0.0, -1.0)
	if not pushed_again.is_equal_approx(looking_down):
		push_error("At the pitch limit, more tilt the same way must not move the camera")
		return 1
	return 0


func _test_yaw_keeps_height_and_level_horizon() -> int:
	var start := _camera_looking_at_pivot(PIVOT + Vector3(0, 12, 30))
	var turned: Transform3D = Orbit.orbit_transform(PIVOT, start, 2.5, 0.0)
	if not is_equal_approx(turned.origin.y, start.origin.y):
		push_error("Yaw alone must keep the camera height")
		return 1
	if not is_zero_approx(turned.basis.x.y):
		push_error("Orbit must not roll the horizon")
		return 1
	return 0


func _test_pivot_order() -> int:
	var selection := AABB(Vector3(0, 0, 0), Vector3(2, 2, 2))
	var hit := {&"position": Vector3(7, 7, 7)}
	var scene := AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	var picked: Dictionary = Orbit.choose_pivot(selection, hit, scene)
	if not picked[&"found"] or picked[&"pivot"] != Vector3(1, 1, 1):
		push_error("A selection must win: its center is the pivot")
		return 1
	picked = Orbit.choose_pivot(AABB(), hit, scene)
	if not picked[&"found"] or picked[&"pivot"] != Vector3(7, 7, 7):
		push_error("With nothing selected, the point under the screen center is the pivot")
		return 1
	picked = Orbit.choose_pivot(AABB(), {}, scene)
	if not picked[&"found"] or picked[&"pivot"] != Vector3.ZERO:
		push_error("With nothing under the center, the visible brain's center is the pivot")
		return 1
	picked = Orbit.choose_pivot(AABB(), {}, AABB())
	if picked[&"found"]:
		push_error("An empty scene must not invent a pivot")
		return 1
	return 0


func _make_camera(scene_events: Array) -> UI_BrainMonitor_PancakeCamera:
	var cam: UI_BrainMonitor_PancakeCamera = PancakeCameraScript.new()
	root.add_child(cam)
	cam.current = true
	cam.global_transform = _camera_looking_at_pivot(PIVOT + Vector3(0, 0, 30))
	cam.orbit_pivot_provider = func() -> Dictionary: return {&"found": true, &"pivot": PIVOT}
	cam.BM_input_events.connect(func(events: Array[UI_BrainMonitor_InputEvent_Abstract]) -> void: scene_events.append_array(events))
	return cam


func _mouse_button(button: MouseButton, pressed: bool, alt: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.alt_pressed = alt
	return ev


func _mouse_motion(relative: Vector2, mask: MouseButtonMask) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	ev.button_mask = mask
	return ev


func _test_camera_orbit_press_never_reaches_the_scene() -> int:
	var scene_events: Array = []
	var cam := _make_camera(scene_events)
	var start_distance: float = cam.global_position.distance_to(PIVOT)
	var failures: int = 0
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_LEFT, true, true))
	cam._unhandled_input(_mouse_motion(Vector2(300, -120), MOUSE_BUTTON_MASK_LEFT))
	if not cam.is_orbiting():
		push_error("Option/Alt + left press must start an orbit")
		failures += 1
	if not is_equal_approx(cam.global_position.distance_to(PIVOT), start_distance):
		push_error("Dragging the camera must orbit at a fixed distance from the pivot")
		failures += 1
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_LEFT, false, true))
	if cam.is_orbiting():
		push_error("Releasing the orbit button must end the orbit")
		failures += 1
	if not scene_events.is_empty():
		push_error("An orbit press, drag, and release must not reach selection or the quick menu")
		failures += 1
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_MIDDLE, true, false))
	if not cam.is_orbiting():
		push_error("Middle press must start an orbit")
		failures += 1
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_MIDDLE, false, false))
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_LEFT, true, false))
	if cam.is_orbiting() or scene_events.size() != 1:
		push_error("A plain left press must still reach the scene as a click")
		failures += 1
	cam.queue_free()
	return failures


func _test_camera_orbit_turns_three_times_the_in_place_rate() -> int:
	var scene_events: Array = []
	var cam := _make_camera(scene_events)
	var drag_pixels: float = 200.0
	var start_offset: Vector3 = cam.global_position - PIVOT
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_MIDDLE, true, false))
	cam._unhandled_input(_mouse_motion(Vector2(drag_pixels, 0), MOUSE_BUTTON_MASK_MIDDLE))
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_MIDDLE, false, false))
	var end_offset: Vector3 = cam.global_position - PIVOT
	var turned: float = absf(Vector2(start_offset.x, start_offset.z).angle_to(Vector2(end_offset.x, end_offset.z)))
	var expected: float = drag_pixels * UI_BrainMonitor_PancakeCamera.TANK_CAMERA_ROTATION_SPEED * 3.0
	cam.queue_free()
	if not is_equal_approx(turned, expected):
		push_error("A horizontal orbit drag must turn three times the in-place turn rate (got %f, want %f)" % [turned, expected])
		return 1
	return 0


func _test_camera_orbit_ends_when_button_is_released_elsewhere() -> int:
	var scene_events: Array = []
	var cam := _make_camera(scene_events)
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_MIDDLE, true, false))
	var before: Vector3 = cam.global_position
	cam._unhandled_input(_mouse_motion(Vector2(200, 0), 0))
	var failures: int = 0
	if cam.is_orbiting():
		push_error("Motion with the orbit button up must end the orbit")
		failures += 1
	if not cam.global_position.is_equal_approx(before):
		push_error("Motion after the orbit ended must not orbit the camera")
		failures += 1
	cam.queue_free()
	return failures
