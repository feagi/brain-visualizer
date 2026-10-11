extends SceneTree
## A 3D mouse click chooses the area in Cortical Area Explorer while that window is open.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/SelectGenomeObject/test_cortical_explorer_scene_pick.gd

const Pick = preload("res://BrainVisualizer/UI/Windows/SelectGenomeObject/CorticalExplorerScenePick.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_mouse_contexts()
	failures += _test_quick_connect_yields_only_while_explorer_is_open()
	failures += _test_only_shown_enabled_areas_and_regions_can_be_chosen()
	failures += _test_single_select_replaces_and_multi_select_adds()
	if failures == 0:
		print("Cortical explorer scene pick tests: PASS")
		quit(0)
	else:
		push_error("Cortical explorer scene pick tests: FAIL (%d)" % failures)
		quit(1)


func _test_mouse_contexts() -> int:
	var failures: int = 0
	var context = SelectionSystem.SOURCE_CONTEXT
	if not Pick.accepts_mouse_context(context.FROM_3D_SCENE):
		push_error("a click in the 3D view must choose the area in the explorer")
		failures += 1
	if not Pick.accepts_mouse_context(context.FROM_3D_SCENE_ON_PLATE):
		push_error("a click on an area plate must choose the area in the explorer")
		failures += 1
	if not Pick.accepts_mouse_context(context.FROM_CIRCUIT_BUILDER_CLICK):
		push_error("a circuit graph click must choose the area in the explorer")
		failures += 1
	if not Pick.accepts_mouse_context(context.FROM_CIRCUIT_BUILDER_DRAG):
		push_error("a circuit graph drag selection must choose those areas in the explorer")
		failures += 1
	if Pick.accepts_mouse_context(context.FROM_OBJECT_SELECTION_WINDOW):
		push_error("clicks inside the explorer list must not be treated as a 3D pick")
		failures += 1
	return failures


func _test_quick_connect_yields_only_while_explorer_is_open() -> int:
	var failures: int = 0
	if not Pick.quick_connect_should_yield_to_explorer(true):
		push_error("quick connect must leave the click to the open explorer")
		failures += 1
	if Pick.quick_connect_should_yield_to_explorer(false):
		push_error("quick connect must keep destination clicks while the explorer is closed")
		failures += 1
	return failures


func _test_only_shown_enabled_areas_and_regions_can_be_chosen() -> int:
	var failures: int = 0
	if not Pick.is_chooser_eligible(true, false, true, false):
		push_error("a visible cortical area must be choosable")
		failures += 1
	if Pick.is_chooser_eligible(true, false, true, true):
		push_error("a disabled cortical area must stay unchecked")
		failures += 1
	if Pick.is_chooser_eligible(true, false, false, false):
		push_error("a hidden cortical area must stay unchecked")
		failures += 1
	if not Pick.is_chooser_eligible(false, true, true, false):
		push_error("a visible circuit must be choosable when the explorer allows circuits")
		failures += 1
	if Pick.is_chooser_eligible(false, false, true, false):
		push_error("classifiers and other objects must not be checked as areas")
		failures += 1
	return failures


func _test_single_select_replaces_and_multi_select_adds() -> int:
	var failures: int = 0
	if not Pick.replaces_existing_choices(false):
		push_error("a single-area explorer must replace the previous choice")
		failures += 1
	if Pick.replaces_existing_choices(true):
		push_error("a multi-area explorer must add the clicked area")
		failures += 1
	return failures
