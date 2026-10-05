extends SceneTree
## Gesture and locked orbit pivot for the floating single-area inspect view.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_isolated_area_inspect.gd

const Inspect = preload("res://addons/UI_BrainMonitor/IsolatedAreaInspect.gd")
const Orbit = preload("res://addons/UI_BrainMonitor/CameraOrbit.gd")
const WindowScript = preload("res://BrainVisualizer/UI/Windows/IsolatedCorticalArea/WindowIsolatedCorticalArea.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_open_gesture()
	failures += _test_locked_pivot_ignores_selection()
	failures += _test_click_placement_and_resize()
	failures += _test_inspect_tumble_passes_the_poles_and_rolls()
	failures += _test_window_script_compiles()
	if failures == 0:
		print("IsolatedAreaInspect tests: PASS")
		quit(0)
	else:
		push_error("IsolatedAreaInspect tests: FAIL (%d)" % failures)
		quit(1)


func _test_open_gesture() -> int:
	if not Inspect.is_open_gesture(true, true, true, false, true, false):
		push_error("Shift+Ctrl+click opens the isolated view")
		return 1
	if not Inspect.is_open_gesture(true, true, false, true, true, false):
		push_error("macOS Control+click arrives as the right button and still opens the isolated view")
		return 1
	if Inspect.is_open_gesture(true, true, true, false, true, true):
		push_error("Shift+Ctrl+drag stays box-select and does not open the isolated view")
		return 1
	if Inspect.is_open_gesture(false, true, true, false, true, false):
		push_error("Shift+click stays voxel toggle")
		return 1
	if Inspect.is_open_gesture(false, true, false, true, true, false):
		push_error("Shift+right-click without Ctrl stays a normal click")
		return 1
	if Inspect.is_open_gesture(true, false, true, false, true, false):
		push_error("Ctrl+click stays multi-select")
		return 1
	if Inspect.is_open_gesture(true, true, true, false, false, false):
		push_error("The gesture is the press, not the release")
		return 1
	return 0


func _test_locked_pivot_ignores_selection() -> int:
	var area_aabb := AABB(Vector3(4, 8, 12), Vector3(6, 2, 10))
	var choice: Dictionary = Inspect.pivot_for_area(area_aabb)
	if choice[&"found"] != true:
		push_error("A visible area supplies the orbit pivot")
		return 1
	var expected: Vector3 = area_aabb.get_center()
	if not (choice[&"pivot"] as Vector3).is_equal_approx(expected):
		push_error("The isolated orbit pivot is the area center")
		return 1
	var selection_aabb := AABB(Vector3(100, 0, 0), Vector3(20, 20, 20))
	var scene_choice: Dictionary = Orbit.choose_pivot(selection_aabb, {}, area_aabb)
	if (scene_choice[&"pivot"] as Vector3).is_equal_approx(expected):
		push_error("The region orbit order would have used the selection, so the isolated pivot must be a separate lock")
		return 1
	var empty: Dictionary = Inspect.pivot_for_area(AABB())
	if empty[&"found"] != false:
		push_error("An empty area has no orbit pivot")
		return 1
	return 0


func _test_click_placement_and_resize() -> int:
	var viewport := Rect2(Vector2.ZERO, Vector2(1000, 800))
	var window_size := Vector2(480, 360)
	var at_click: Vector2 = Inspect.top_left_for_click(Vector2(120, 200), window_size, viewport, 40.0)
	if not at_click.is_equal_approx(Vector2(120, 200)):
		push_error("The floating view opens with its top-left on the click")
		return 1
	var near_right: Vector2 = Inspect.top_left_for_click(Vector2(900, 200), window_size, viewport, 0.0)
	if not near_right.is_equal_approx(Vector2(520, 200)):
		push_error("A click near the right edge keeps the floating view on screen")
		return 1
	var under_bar: Vector2 = Inspect.top_left_for_click(Vector2(20, 4), window_size, viewport, 48.0)
	if under_bar.y < 48.0:
		push_error("The floating view stays below the top bar")
		return 1
	var grown: Vector2 = Inspect.resized_size(window_size, Vector2(80, 40), Vector2(280, 200))
	if not grown.is_equal_approx(Vector2(560, 400)):
		push_error("Dragging the corner grows the floating view")
		return 1
	var floored: Vector2 = Inspect.resized_size(window_size, Vector2(-400, -400), Vector2(280, 200))
	if not floored.is_equal_approx(Vector2(280, 200)):
		push_error("The floating view cannot be resized below its minimum")
		return 1
	return 0


func _test_inspect_tumble_passes_the_poles_and_rolls() -> int:
	var pivot := Vector3.ZERO
	var looking_down_z := Transform3D(Basis.IDENTITY, Vector3(0, 0, 10))
	var tumbled: Transform3D = Orbit.tumble_transform(pivot, looking_down_z, 0.0, deg_to_rad(120.0))
	if tumbled.origin.y >= 0.0:
		push_error("Inspect tumble must carry the camera past the pole")
		return 1
	if absf(tumbled.origin.length() - 10.0) > 0.05:
		push_error("Inspect tumble keeps the camera distance to the area")
		return 1
	var rolled: Transform3D = Orbit.roll_transform(pivot, looking_down_z, deg_to_rad(90.0))
	if not rolled.origin.is_equal_approx(looking_down_z.origin):
		push_error("Inspect roll spins in place on the view axis")
		return 1
	if rolled.basis.y.is_equal_approx(looking_down_z.basis.y):
		push_error("Inspect roll twists the horizon")
		return 1
	return 0


func _test_window_script_compiles() -> int:
	if WindowScript == null:
		push_error("WindowIsolatedCorticalArea.gd failed to compile")
		return 1
	if WindowScript.WINDOW_NAME != &"isolated_cortical_inspect":
		push_error("The isolated inspect window name is isolated_cortical_inspect")
		return 1
	return 0
