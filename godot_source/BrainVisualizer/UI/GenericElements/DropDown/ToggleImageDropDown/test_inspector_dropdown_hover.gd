extends SceneTree
## Inspectors and Split view open on hover. Both sit on the root scene top bar.
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/DropDown/ToggleImageDropDown/test_inspector_dropdown_hover.gd

const DROPDOWN_SCRIPT_PATH := "res://BrainVisualizer/UI/GenericElements/DropDown/ToggleImageDropDown/ToggleImageDropDown.gd"
const INSPECTORS_SCENE_PATH := "res://BrainVisualizer/UI/Top_Bar/ActivityVisualizationDropDown/ActivityVisualizationDropDown.tscn"
const SPLIT_VIEW_SCENE_PATH := "res://BrainVisualizer/UI/Top_Bar/SplitViewDropDown/SplitViewDropDown.tscn"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_hover_open_rules()
	failures += _test_pointer_keeps_menu_open()
	failures += _test_inspectors_scene_opens_on_hover()
	failures += _test_split_view_scene_opens_on_hover()
	if failures == 0:
		print("Inspectors dropdown hover tests: PASS")
		quit(0)
	else:
		push_error("Inspectors dropdown hover tests: FAIL (%d)" % failures)
		quit(1)


func _test_hover_open_rules() -> int:
	var script: Script = load(DROPDOWN_SCRIPT_PATH)
	if not bool(script.should_open_menu_on_hover(true, false)):
		push_error("Inspectors menu must open on hover when hover-open is enabled")
		return 1
	if bool(script.should_open_menu_on_hover(false, false)):
		push_error("Menus without hover-open must stay closed until click")
		return 1
	if bool(script.should_open_menu_on_hover(true, true)):
		push_error("A disabled Inspectors button must not open on hover")
		return 1
	if int(script.MENU_ANCHOR_OVERLAP_PX) <= 0:
		push_error("Inspectors menu must overlap the button so the pointer can move into it")
		return 1
	if float(script.MENU_HOVER_CLOSE_DELAY_SEC) <= 0.0:
		push_error("Inspectors menu hover close delay must be positive")
		return 1
	return 0


func _test_pointer_keeps_menu_open() -> int:
	var script: Script = load(DROPDOWN_SCRIPT_PATH)
	if not bool(script.should_keep_menu_open_while_pointer_inside(false, true)):
		push_error("Inspectors menu must stay open while the pointer is on the button")
		return 1
	if not bool(script.should_keep_menu_open_while_pointer_inside(true, false)):
		push_error("Inspectors menu must stay open while the pointer is over the menu")
		return 1
	if bool(script.should_keep_menu_open_while_pointer_inside(false, false)):
		push_error("Inspectors menu must close when the pointer is on neither the menu nor the button")
		return 1
	return 0


func _test_inspectors_scene_opens_on_hover() -> int:
	if not _scene_sets_open_on_hover(INSPECTORS_SCENE_PATH, true):
		push_error("ActivityVisualizationDropDown must set open_on_hover on its ToggleImageDropDown")
		return 1
	return 0


func _test_split_view_scene_opens_on_hover() -> int:
	if not _scene_sets_open_on_hover(SPLIT_VIEW_SCENE_PATH, true):
		push_error("Split view on the root top bar must open on hover")
		return 1
	return 0


func _scene_sets_open_on_hover(scene_path: String, expected: bool) -> bool:
	var packed: PackedScene = load(scene_path)
	var state: SceneState = packed.get_state()
	for i in range(state.get_node_count()):
		if str(state.get_node_name(i)) != "ToggleImageDropDown":
			continue
		for p in range(state.get_node_property_count(i)):
			if str(state.get_node_property_name(i, p)) != "open_on_hover":
				continue
			return bool(state.get_node_property_value(i, p)) == expected
		return false == expected
	return false
