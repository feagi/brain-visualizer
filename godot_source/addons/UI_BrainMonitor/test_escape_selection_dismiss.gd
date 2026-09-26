extends SceneTree
## Unit tests for Escape deselecting voxels and cortical areas.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_escape_selection_dismiss.gd


const Dismiss = preload("res://addons/UI_BrainMonitor/EscapeSelectionDismiss.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_escape_clears_cortical_area()
	failures += _test_escape_clears_voxels()
	failures += _test_escape_clears_when_both_are_selected()
	failures += _test_manipulation_wins_over_selection()
	failures += _test_box_select_wins_over_selection()
	failures += _test_idle_escape_does_nothing()
	failures += _test_non_escape_and_repeats_are_ignored()
	if failures == 0:
		print("EscapeSelectionDismiss tests: PASS")
		quit(0)
	else:
		push_error("EscapeSelectionDismiss tests: FAIL (%d)" % failures)
		quit(1)


func _test_escape_clears_cortical_area() -> int:
	var action: int = Dismiss.resolve(KEY_ESCAPE, KEY_NONE, true, false, false, false, true, false)
	if action != Dismiss.ACTION.CLEAR_SELECTION:
		push_error("Escape with a cortical area selected must clear the selection")
		return 1
	return 0


func _test_escape_clears_voxels() -> int:
	var action: int = Dismiss.resolve(KEY_NONE, KEY_ESCAPE, true, false, false, false, false, true)
	if action != Dismiss.ACTION.CLEAR_SELECTION:
		push_error("Escape with selected voxels must clear the selection")
		return 1
	return 0


func _test_escape_clears_when_both_are_selected() -> int:
	var action: int = Dismiss.resolve(KEY_ESCAPE, KEY_ESCAPE, true, false, false, false, true, true)
	if action != Dismiss.ACTION.CLEAR_SELECTION:
		push_error("Escape with both a cortical area and voxels selected must clear both")
		return 1
	return 0


func _test_manipulation_wins_over_selection() -> int:
	var action: int = Dismiss.resolve(KEY_ESCAPE, KEY_NONE, true, false, true, true, true, true)
	if action != Dismiss.ACTION.CANCEL_MANIPULATION:
		push_error("Escape during a move or resize must cancel that session before clearing selection")
		return 1
	return 0


func _test_box_select_wins_over_selection() -> int:
	var action: int = Dismiss.resolve(KEY_ESCAPE, KEY_NONE, true, false, false, true, true, true)
	if action != Dismiss.ACTION.CANCEL_BOX_SELECT:
		push_error("Escape during a box select must cancel the drag before clearing selection")
		return 1
	return 0


func _test_idle_escape_does_nothing() -> int:
	var action: int = Dismiss.resolve(KEY_ESCAPE, KEY_ESCAPE, true, false, false, false, false, false)
	if action != Dismiss.ACTION.NONE:
		push_error("Escape with nothing selected must leave the scene alone")
		return 1
	return 0


func _test_non_escape_and_repeats_are_ignored() -> int:
	if Dismiss.resolve(KEY_DELETE, KEY_DELETE, true, false, false, false, true, true) != Dismiss.ACTION.NONE:
		push_error("Delete must not be treated as Escape deselect")
		return 1
	if Dismiss.resolve(KEY_ESCAPE, KEY_ESCAPE, false, false, false, false, true, true) != Dismiss.ACTION.NONE:
		push_error("Escape key-up must not clear the selection")
		return 1
	if Dismiss.resolve(KEY_ESCAPE, KEY_ESCAPE, true, true, false, false, true, true) != Dismiss.ACTION.NONE:
		push_error("Escape key-repeat must not clear the selection again")
		return 1
	return 0
