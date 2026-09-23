extends SceneTree
## Press contract for BasePanelContainerButton.
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/Buttons/test_base_panel_container_button_press.gd

const BUTTON_SCRIPT_PATH := "res://BrainVisualizer/UI/GenericElements/Buttons/BasePanelContainerButton.gd"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_emits_press_when_hovered_left_down()
	failures += _test_rejects_press_when_not_hovered()
	failures += _test_rejects_press_when_disabled()
	failures += _test_rejects_non_left_or_release()
	failures += _test_list_hover_scales_label_not_plus_container()
	failures += _test_plus_hover_does_not_scale_list_text()
	failures += _test_label_hover_stays_on_text_bounds()
	failures += _test_label_click_counts_as_list_press_hover()
	failures += _test_label_left_clearance_matches_hover_growth()
	failures += _test_label_hover_pivot_is_text_center()
	failures += _test_list_label_hover_from_pointer_is_immediate()
	failures += _test_connectivity_rules_list_and_plus_are_siblings()
	if failures == 0:
		print("BasePanelContainerButton press tests: PASS")
		quit(0)
	else:
		push_error("BasePanelContainerButton press tests: FAIL (%d)" % failures)
		quit(1)


func _test_emits_press_when_hovered_left_down() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	var event := _left_click(true)
	if not bool(script.should_emit_press_for_gui_mouse_button(false, true, event)):
		push_error("Hovered left-down must emit press without a global-rect retest")
		return 1
	return 0


func _test_rejects_press_when_not_hovered() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if bool(script.should_emit_press_for_gui_mouse_button(false, false, _left_click(true))):
		push_error("Press must not emit when the button is not hovered")
		return 1
	return 0


func _test_rejects_press_when_disabled() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if bool(script.should_emit_press_for_gui_mouse_button(true, true, _left_click(true))):
		push_error("Press must not emit when the button is disabled")
		return 1
	return 0


func _test_rejects_non_left_or_release() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	var release := _left_click(false)
	if bool(script.should_emit_press_for_gui_mouse_button(false, true, release)):
		push_error("Mouse-up must not emit press")
		return 1
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	if bool(script.should_emit_press_for_gui_mouse_button(false, true, right)):
		push_error("Right-click must not emit press")
		return 1
	return 0


func _test_list_hover_scales_label_not_plus_container() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	var row := _make_combo_row()
	root.add_child(row)
	var target: Control = script.resolve_hover_scale_target(row)
	if target == null or target.name != "Label":
		push_error("Combo hover must scale the label, not the HBox that also holds +")
		row.queue_free()
		return 1
	if not bool(script.contains_ignore_parent_press(row.get_node("HBoxContainer"))):
		push_error("Combo HBox must be detected as owning a + button")
		row.queue_free()
		return 1
	if not is_equal_approx(float(script.content_hover_scale(true, true)), 1.1):
		push_error("List text hover scale must be an in-place pop")
		row.queue_free()
		return 1
	row.queue_free()
	return 0


func _test_plus_hover_does_not_scale_list_text() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if bool(script.should_scale_list_content_on_hover(true)):
		push_error("Hovering + must not enlarge the list text")
		return 1
	if not bool(script.should_scale_list_content_on_hover(false)):
		push_error("Hovering the list text must enlarge the label")
		return 1
	return 0


func _test_label_hover_stays_on_text_bounds() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if bool(script.should_scale_list_label_on_hover(false, false)):
		push_error("Hovering list chrome or the shared plate must not enlarge the text")
		return 1
	if not bool(script.should_scale_list_label_on_hover(true, false)):
		push_error("Hovering the label must enlarge the text")
		return 1
	if bool(script.should_scale_list_label_on_hover(true, true)):
		push_error("Hovering + must not enlarge the list text")
		return 1
	return 0


func _test_label_click_counts_as_list_press_hover() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if int(script.list_label_mouse_filter_for_parent_press()) != Control.MOUSE_FILTER_PASS:
		push_error("List label must PASS mouse so the parent button receives the click")
		return 1
	if not bool(script.is_list_button_press_hovered(false, true)):
		push_error("Clicking the list text must count as a hovered press")
		return 1
	if bool(script.is_list_button_press_hovered(false, false)):
		push_error("Press hover must stay false when neither the button nor the label is hovered")
		return 1
	return 0


func _test_label_left_clearance_matches_hover_growth() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if int(script.label_hover_left_clearance_px(200.0, 1.1)) != 10:
		push_error("Left clearance must be half of the 10 percent text pop")
		return 1
	if int(script.label_hover_left_clearance_px(100.0, 1.0)) != 0:
		push_error("No extra clearance when hover scale is 1")
		return 1
	if int(script.label_hover_left_clearance_px(0.0, 1.1)) != 0:
		push_error("Empty text must not invent clearance")
		return 1
	if int(script.label_hover_right_clearance_px(220.0, 1.1)) != 11:
		push_error("Right clearance must keep the last glyph off the + button")
		return 1
	if int(script.label_hover_right_clearance_px(220.0, 1.1)) != int(script.label_hover_left_clearance_px(220.0, 1.1)):
		push_error("Left and right clearance must match a center pivot")
		return 1
	return 0


func _test_label_hover_pivot_is_text_center() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	var label := Label.new()
	label.text = "Circuits"
	label.size = Vector2(240, 40)
	root.add_child(label)
	var text_width: float = float(script.label_text_width_px(label))
	var pivot: Vector2 = script.hover_pivot_offset(label)
	if text_width <= 0.0:
		push_error("Label text width must be measured from glyphs")
		label.queue_free()
		return 1
	if not is_equal_approx(pivot.x, text_width * 0.5):
		push_error("Label hover pivot must be the text center, not the expand-fill box")
		label.queue_free()
		return 1
	if is_equal_approx(pivot.x, label.size.x * 0.5):
		push_error("Label hover pivot must not use the full expanded width")
		label.queue_free()
		return 1
	label.queue_free()
	return 0


func _test_list_label_hover_from_pointer_is_immediate() -> int:
	var script: Script = load(BUTTON_SCRIPT_PATH)
	if not bool(script.list_label_hover_from_pointer(true, false)):
		push_error("Label pointer must show the text pop without polling gui hover")
		return 1
	if bool(script.list_label_hover_from_pointer(false, false)):
		push_error("Icon or shared plate must not show the text pop")
		return 1
	if bool(script.list_label_hover_from_pointer(true, true)):
		push_error("Plus pointer must suppress the text pop")
		return 1
	return 0


func _test_connectivity_rules_list_and_plus_are_siblings() -> int:
	var packed: PackedScene = load("res://BrainVisualizer/UI/Top_Bar/TopBar.tscn")
	var state: SceneState = packed.get_state()
	var list_parent := ""
	var plus_parent := ""
	var row_has_plate := false
	var list_is_flat := false
	var label_is_hover_target := false
	for i in range(state.get_node_count()):
		var node_name := str(state.get_node_name(i))
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("HBoxContainer3") < 0:
			continue
		if node_name == "BrainAreasList":
			list_parent = path_str.get_base_dir()
			for p in range(state.get_node_property_count(i)):
				if str(state.get_node_property_name(i, p)) != "metadata/flat_on_backdrop":
					continue
				list_is_flat = bool(state.get_node_property_value(i, p))
		elif node_name == "TextureButton" and path_str.find("BrainAreasRow") >= 0:
			plus_parent = path_str.get_base_dir()
			if path_str.find("BrainAreasList") >= 0:
				push_error("Connectivity rules + must be a sibling of the text button")
				return 1
		elif node_name == "BrainAreasRow":
			for p in range(state.get_node_property_count(i)):
				if str(state.get_node_property_name(i, p)) == "theme_override_styles/panel":
					row_has_plate = true
		elif node_name == "Label" and path_str.find("BrainAreasList") >= 0:
			for p in range(state.get_node_property_count(i)):
				if str(state.get_node_property_name(i, p)) == "metadata/hover_scale_target":
					label_is_hover_target = bool(state.get_node_property_value(i, p))
	if list_parent == "" or plus_parent == "":
		push_error("Connectivity rules list and + must exist on the top bar")
		return 1
	if list_parent != plus_parent:
		push_error("Connectivity rules list and + must share the row plate")
		return 1
	if not row_has_plate:
		push_error("Connectivity rules row must paint the same plate as Inputs and Outputs")
		return 1
	if not list_is_flat:
		push_error("Connectivity rules text button must be flat on the shared row plate")
		return 1
	if not label_is_hover_target:
		push_error("Connectivity rules hover must target the label, not the row")
		return 1
	return 0


func _make_combo_row() -> PanelContainer:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.set_meta("hover_scale_target", true)
	var label := Label.new()
	label.name = "Label"
	label.text = "Circuits"
	var plus := TextureButton.new()
	plus.name = "Plus"
	plus.set_meta("ignore_parent_press", true)
	hbox.add_child(label)
	hbox.add_child(plus)
	row.add_child(hbox)
	return row


func _left_click(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(8, 8)
	return event
