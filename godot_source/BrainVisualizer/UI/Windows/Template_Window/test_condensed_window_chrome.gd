extends SceneTree
## Condensed window chrome: outside clicks dismiss, border drags stay on screen.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/Template_Window/test_condensed_window_chrome.gd


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	var window_script: Variant = load("res://BrainVisualizer/UI/Windows/Template_Window/BaseDraggableWindow.gd")
	if window_script == null:
		push_error("BaseDraggableWindow.gd failed to compile")
		quit(1)
		return
	failures += _test_outside_click_dismisses(window_script)
	failures += _test_button_area_click_stays_open(window_script)
	failures += _test_attached_popup_click_stays_open(window_script)
	failures += _test_drag_keeps_grab_edge_on_screen(window_script)
	failures += _test_quick_menu_opts_into_condensed_chrome()
	if failures == 0:
		print("Condensed window chrome tests: PASS")
		quit(0)
	else:
		push_error("Condensed window chrome tests: FAIL (%d)" % failures)
		quit(1)


func _test_outside_click_dismisses(window_script: Variant) -> int:
	var window_rect := Rect2(100, 80, 160, 64)
	var keep_open: Array[Rect2] = []
	var should_dismiss: Variant = window_script.call("condensed_click_should_dismiss", window_rect, Vector2(10, 10), keep_open)
	if should_dismiss == true:
		return 0
	push_error("A scene click outside the condensed window must dismiss it")
	return 1


func _test_button_area_click_stays_open(window_script: Variant) -> int:
	var window_rect := Rect2(100, 80, 160, 64)
	var keep_open: Array[Rect2] = []
	var should_dismiss: Variant = window_script.call("condensed_click_should_dismiss", window_rect, Vector2(120, 100), keep_open)
	if should_dismiss == false:
		return 0
	push_error("A click on the condensed window, including its buttons and border, must not dismiss it")
	return 1


func _test_attached_popup_click_stays_open(window_script: Variant) -> int:
	var window_rect := Rect2(100, 80, 160, 64)
	var popup_rect := Rect2(100, 140, 180, 72)
	var keep_open: Array[Rect2] = [popup_rect]
	var should_dismiss: bool = window_script.call("condensed_click_should_dismiss", window_rect, Vector2(140, 160), keep_open)
	if not should_dismiss:
		return 0
	push_error("A click on a menu owned by the condensed window must not dismiss it")
	return 1


func _test_drag_keeps_grab_edge_on_screen(window_script: Variant) -> int:
	var screen := Vector2(800, 600)
	var window_size := Vector2(160, 64)
	var buffer := 16.0
	var dragged_off_left: Vector2 = window_script.call(
		"clamp_condensed_window_position", Vector2(-400, 40), window_size, screen, buffer
	)
	var dragged_off_right: Vector2 = window_script.call(
		"clamp_condensed_window_position", Vector2(2000, 40), window_size, screen, buffer
	)
	if dragged_off_left.x != buffer - window_size.x:
		push_error("Dragging past the left edge must leave a grab edge on screen. Got %s" % dragged_off_left)
		return 1
	if dragged_off_right.x != screen.x - buffer:
		push_error("Dragging past the right edge must leave a grab edge on screen. Got %s" % dragged_off_right)
		return 1
	return 0


func _test_quick_menu_opts_into_condensed_chrome() -> int:
	var menu_script: Script = load("res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd")
	if menu_script == null:
		push_error("WindowQuickMenu.gd failed to compile")
		return 1
	if not menu_script.source_code.contains("apply_condensed_chrome()"):
		push_error("Quick menu must call apply_condensed_chrome()")
		return 1
	return 0
