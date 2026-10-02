extends SceneTree
## Quick Connect keeps mouse destination clicks after Cortical Area Explorer was added.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/QuickConnect/test_quick_connect_mouse_destination.gd

const Pick = preload("res://BrainVisualizer/UI/Windows/QuickConnect/QuickConnectDestinationPick.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_mouse_destination_states()
	failures += _test_plate_click_yields_to_cortical_volume()
	failures += _test_guide_follows_area_behind_region_shell()
	failures += _test_cancel_stops_region_scene_that_drew_the_line()
	if failures == 0:
		print("Quick Connect mouse destination tests: PASS")
		quit(0)
	else:
		push_error("Quick Connect mouse destination tests: FAIL (%d)" % failures)
		quit(1)


func _test_mouse_destination_states() -> int:
	var failures: int = 0
	var step = Pick.STEP
	if Pick.accepts_mouse_destination_click(step.SOURCE):
		push_error("source step must not treat a click as a destination")
		failures += 1
	if not Pick.accepts_mouse_destination_click(step.DESTINATION):
		push_error("destination step must accept a mouse click")
		failures += 1
	if not Pick.accepts_mouse_destination_click(step.MORPHOLOGY):
		push_error("rule step must still accept a destination click")
		failures += 1
	if not Pick.accepts_mouse_destination_click(step.IDLE):
		push_error("review step must still accept a destination click")
		failures += 1
	if Pick.accepts_mouse_destination_click(step.EDIT_MORPHOLOGY):
		push_error("morphology editor toggle must not retarget the destination")
		failures += 1
	return failures


func _test_plate_click_yields_to_cortical_volume() -> int:
	var failures: int = 0
	if not Pick.click_prefers_cortical_volume(true, false):
		push_error("area quick connect must click the cortical volume through a plate")
		failures += 1
	if not Pick.click_prefers_cortical_volume(false, true):
		push_error("neuron quick connect must click the cortical volume through a plate")
		failures += 1
	if Pick.click_prefers_cortical_volume(false, false):
		push_error("normal clicks must keep plate picking")
		failures += 1
	return failures


func _test_guide_follows_area_behind_region_shell() -> int:
	var failures: int = 0
	if not Pick.guide_follows_cortical_hit(true):
		push_error("guide must end on the area behind a region shell")
		failures += 1
	if Pick.guide_follows_cortical_hit(false):
		push_error("guide must not stick to a region shell when no area is under the pointer")
		failures += 1
	return failures


func _test_cancel_stops_region_scene_that_drew_the_line() -> int:
	var failures: int = 0
	if not Pick.must_stop_guide_on_scene(true, false, true):
		push_error("cancel must clear the region view that drew the line for an outside source")
		failures += 1
	if not Pick.must_stop_guide_on_scene(false, true, true):
		push_error("cancel must clear the monitor that owns the source area")
		failures += 1
	if Pick.must_stop_guide_on_scene(false, false, false):
		push_error("a hidden monitor that did not draw the line does not need a stop")
		failures += 1
	return failures
