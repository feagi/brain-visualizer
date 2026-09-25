extends SceneTree
## Quick Connect keeps mouse destination clicks after Cortical Area Explorer was added.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/QuickConnect/test_quick_connect_mouse_destination.gd

const Pick = preload("res://BrainVisualizer/UI/Windows/QuickConnect/QuickConnectDestinationPick.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_mouse_destination_states()
	failures += _test_plate_click_yields_to_cortical_volume()
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
