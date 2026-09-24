extends SceneTree
## Align and distribute planning, plus the Arrange dropdown on the multi-select quick menu.
## Run: godot --headless -s res://BrainVisualizer/UI/Windows/QuickMenu/test_selection_arrange.gd

const QUICK_MENU_SCENE := "res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.tscn"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_align_uses_lowest_axis_value()
	failures += _test_align_leaves_other_axes()
	failures += _test_align_short_selection_is_unchanged()
	failures += _test_distribute_spaces_between_endpoints()
	failures += _test_distribute_preserves_input_order_and_other_axes()
	failures += _test_distribute_ties_keep_earlier_index_first()
	failures += _test_distribute_zero_span_and_short_selection()
	failures += _test_negative_axis_values()
	failures += _test_quick_menu_scene_has_hidden_arrange_button()
	failures += _test_quick_menu_script_compiles()
	failures += _test_arrange_dropdown_actions()
	if failures == 0:
		print("Selection arrange tests: PASS")
		quit(0)
	else:
		push_error("Selection arrange tests: FAIL (%d)" % failures)
		quit(1)


func _test_align_uses_lowest_axis_value() -> int:
	var positions: Array[Vector3i] = [Vector3i(4, 9, 1), Vector3i(1, 3, 8), Vector3i(7, 3, 2)]
	var aligned_x: Array[Vector3i] = SelectionArrange.align_positions(positions, SelectionArrange.Axis.X)
	if aligned_x != [Vector3i(1, 9, 1), Vector3i(1, 3, 8), Vector3i(1, 3, 2)]:
		push_error("Align X must snap every area to the lowest X")
		return 1
	var aligned_y: Array[Vector3i] = SelectionArrange.align_positions(positions, SelectionArrange.Axis.Y)
	if aligned_y[0].y != 3 or aligned_y[1].y != 3 or aligned_y[2].y != 3:
		push_error("Align Y must snap every area to the lowest Y")
		return 1
	var aligned_z: Array[Vector3i] = SelectionArrange.plan_positions(SelectionArrange.ACTION_ALIGN, positions, SelectionArrange.Axis.Z)
	if aligned_z[0].z != 1 or aligned_z[1].z != 1 or aligned_z[2].z != 1:
		push_error("Align Z must snap every area to the lowest Z")
		return 1
	return 0


func _test_align_leaves_other_axes() -> int:
	var positions: Array[Vector3i] = [Vector3i(4, 9, 1), Vector3i(1, 3, 8)]
	var aligned: Array[Vector3i] = SelectionArrange.align_positions(positions, SelectionArrange.Axis.X)
	if aligned[0].y != 9 or aligned[0].z != 1 or aligned[1].y != 3 or aligned[1].z != 8:
		push_error("Align must leave the other axes unchanged")
		return 1
	return 0


func _test_align_short_selection_is_unchanged() -> int:
	var positions: Array[Vector3i] = [Vector3i(2, 2, 2)]
	var aligned: Array[Vector3i] = SelectionArrange.align_positions(positions, SelectionArrange.Axis.Y)
	if aligned != positions:
		push_error("Align of a single area must leave it in place")
		return 1
	return 0


func _test_distribute_spaces_between_endpoints() -> int:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(9, 0, 0)]
	var distributed: Array[Vector3i] = SelectionArrange.distribute_positions(positions, SelectionArrange.Axis.X)
	var expected: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(3, 0, 0), Vector3i(6, 0, 0), Vector3i(9, 0, 0)]
	if distributed != expected:
		push_error("Distribute X must keep endpoints and space the interior. Got %s" % [distributed])
		return 1
	return 0


func _test_distribute_preserves_input_order_and_other_axes() -> int:
	var positions: Array[Vector3i] = [Vector3i(100, 1, 4), Vector3i(0, 2, 5), Vector3i(40, 3, 6)]
	var distributed: Array[Vector3i] = SelectionArrange.plan_positions(SelectionArrange.ACTION_DISTRIBUTE, positions, SelectionArrange.Axis.X)
	var expected: Array[Vector3i] = [Vector3i(100, 1, 4), Vector3i(0, 2, 5), Vector3i(50, 3, 6)]
	if distributed != expected:
		push_error("Distribute must write results back in selection order. Got %s" % [distributed])
		return 1
	return 0


func _test_distribute_ties_keep_earlier_index_first() -> int:
	var positions: Array[Vector3i] = [Vector3i(5, 0, 0), Vector3i(5, 1, 0), Vector3i(1, 2, 0)]
	var distributed: Array[Vector3i] = SelectionArrange.distribute_positions(positions, SelectionArrange.Axis.X)
	var expected: Array[Vector3i] = [Vector3i(3, 0, 0), Vector3i(5, 1, 0), Vector3i(1, 2, 0)]
	if distributed != expected:
		push_error("Equal axis values must keep the earlier selection index first. Got %s" % [distributed])
		return 1
	return 0


func _test_distribute_zero_span_and_short_selection() -> int:
	var stacked: Array[Vector3i] = [Vector3i(4, 0, 0), Vector3i(4, 1, 0), Vector3i(4, 2, 0)]
	if SelectionArrange.distribute_positions(stacked, SelectionArrange.Axis.X) != stacked:
		push_error("Distribute with no span must leave positions unchanged")
		return 1
	var pair: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(8, 0, 0)]
	if SelectionArrange.distribute_positions(pair, SelectionArrange.Axis.Z) != pair:
		push_error("Distribute needs at least 3 areas")
		return 1
	return 0


func _test_negative_axis_values() -> int:
	var positions: Array[Vector3i] = [Vector3i(0, -10, 0), Vector3i(0, 0, 0), Vector3i(0, 10, 0)]
	var distributed: Array[Vector3i] = SelectionArrange.distribute_positions(positions, SelectionArrange.Axis.Y)
	if distributed != positions:
		push_error("Already even negative span must stay put. Got %s" % [distributed])
		return 1
	var aligned: Array[Vector3i] = SelectionArrange.align_positions(positions, SelectionArrange.Axis.Y)
	if aligned[0].y != -10 or aligned[1].y != -10 or aligned[2].y != -10:
		push_error("Align must use the lowest value when coordinates are negative")
		return 1
	return 0


func _test_quick_menu_scene_has_hidden_arrange_button() -> int:
	var packed: PackedScene = load(QUICK_MENU_SCENE)
	var state: SceneState = packed.get_state()
	for index in range(state.get_node_count()):
		if str(state.get_node_name(index)) != "Arrange":
			continue
		var visible_hidden := false
		var has_arrange_script := false
		var tooltip_ok := false
		for property_index in range(state.get_node_property_count(index)):
			var property_name := str(state.get_node_property_name(index, property_index))
			var property_value: Variant = state.get_node_property_value(index, property_index)
			if property_name == "visible" and bool(property_value) == false:
				visible_hidden = true
			if property_name == "tooltip_text" and str(property_value) == "Arrange":
				tooltip_ok = true
			if property_name == "script":
				var script_path := ""
				if property_value is Script:
					script_path = (property_value as Script).resource_path
				elif property_value is Resource:
					script_path = (property_value as Resource).resource_path
				has_arrange_script = script_path.ends_with("ArrangeDropDown.gd")
		if not visible_hidden or not has_arrange_script or not tooltip_ok:
			push_error("Quick menu Arrange button must be hidden, scripted, and labeled Arrange")
			return 1
		return 0
	push_error("Quick menu is missing the Arrange button")
	return 1


func _test_quick_menu_script_compiles() -> int:
	var menu_script: Script = load("res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd")
	if menu_script == null or not menu_script.can_instantiate():
		push_error("Quick menu script must compile with the Arrange action")
		return 1
	return 0


func _test_arrange_dropdown_actions() -> int:
	var dropdown_script: Script = load("res://BrainVisualizer/UI/Windows/QuickMenu/ArrangeDropDown.gd")
	if dropdown_script == null or not dropdown_script.can_instantiate():
		push_error("Arrange dropdown script must compile")
		return 1
	var dropdown: ArrangeDropDown = dropdown_script.new() as ArrangeDropDown
	root.add_child(dropdown)
	var received: Array[String] = []
	dropdown.arrange_requested.connect(func(action: StringName, axis: int) -> void:
		received.append("%s:%d" % [String(action), axis])
	)
	var align_x: Button = dropdown.get_axis_button(SelectionArrange.ACTION_ALIGN, SelectionArrange.Axis.X)
	var distribute_z: Button = dropdown.get_axis_button(SelectionArrange.ACTION_DISTRIBUTE, SelectionArrange.Axis.Z)
	if align_x == null or align_x.text != "X" or distribute_z == null or distribute_z.text != "Z":
		push_error("Arrange menu must offer Align and Distribute on X, Y, and Z")
		dropdown.queue_free()
		return 1
	if align_x.tooltip_text != "Align to the lowest X":
		push_error("Align X must describe snapping to the lowest X")
		dropdown.queue_free()
		return 1
	if distribute_z.tooltip_text != "Distribute evenly on Z":
		push_error("Distribute Z must describe even spacing on Z")
		dropdown.queue_free()
		return 1
	dropdown.set_action_availability(true, false)
	if not distribute_z.disabled or distribute_z.tooltip_text != "Select at least 3 areas to distribute them":
		push_error("Distribute must stay disabled until 3 areas are selected")
		dropdown.queue_free()
		return 1
	dropdown.disabled = true
	dropdown._open_menu_from_pointer()
	if dropdown.is_menu_open():
		push_error("A disabled Arrange button must not open its menu")
		dropdown.queue_free()
		return 1
	dropdown.disabled = false
	align_x.pressed.emit()
	if received.size() != 1 or received[0] != "align:0":
		push_error("Align X must emit the align action on axis 0")
		dropdown.queue_free()
		return 1
	dropdown.queue_free()
	return 0
