extends SceneTree
## Connectome hamburger contract for BrainObjectsCombo.
## Does not instantiate the combo (BV autoload is unavailable under `godot -s`).
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/test_brain_objects_combo_connectome_menu.gd

const COMBO_SCENE_PATH := "res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/BrainObjectsCombo.tscn"
const COMBO_SCRIPT_PATH := "res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/BrainObjectsCombo.gd"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_menu_ids_are_circuit_interconnect_memory()
	failures += _test_menu_ids_match_row_node_names()
	failures += _test_scene_has_connectome_trigger()
	failures += _test_connectome_button_uses_panel_plate()
	failures += _test_connectome_inner_hbox_ignores_mouse()
	failures += _test_scene_keeps_object_combos_inside_menu()
	failures += _test_classifier_row_uses_carbon_icon()
	failures += _test_combo_rows_scale_label_not_hbox()
	failures += _test_combo_list_labels_pass_mouse_to_parent()
	failures += _test_scene_keeps_inputs_outputs_on_strip()
	failures += _test_scene_menu_row_order()
	failures += _test_align_connectome_menu_add_buttons_right_justifies_plus()
	failures += _test_list_and_plus_are_siblings_on_shared_plate()
	failures += _test_keep_menu_open_when_pointer_still_on_trigger()
	failures += _test_tab_overlay_z_index_matches_circuit_builder()
	if failures == 0:
		print("BrainObjectsCombo connectome menu tests: PASS")
		quit(0)
	else:
		push_error("BrainObjectsCombo connectome menu tests: FAIL (%d)" % failures)
		quit(1)


func _test_menu_ids_are_circuit_interconnect_memory() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	var ids: PackedStringArray = script.connectome_menu_item_ids()
	var expected := PackedStringArray(["circuit", "interconnect", "memory", "classifier"])
	if ids != expected:
		push_error("connectome_menu_item_ids must be circuit, interconnect, memory, classifier (got %s)" % [ids])
		return 1
	return 0


func _test_menu_ids_match_row_node_names() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	var ids: PackedStringArray = script.connectome_menu_item_ids()
	var names: PackedStringArray = script.connectome_menu_row_node_names()
	if ids.size() != names.size():
		push_error("connectome menu ids and row node names must stay the same length")
		return 1
	return 0


func _test_connectome_button_uses_panel_plate() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var connectome_index: int = _find_node_index_by_name(state, "ConnectomeButton")
	if connectome_index < 0:
		push_error("ConnectomeButton missing from BrainObjectsCombo scene")
		return 1
	var has_button_script: bool = false
	var has_panel_variation: bool = false
	for i in range(state.get_node_property_count(connectome_index)):
		var prop_name: String = str(state.get_node_property_name(connectome_index, i))
		var prop_value: Variant = state.get_node_property_value(connectome_index, i)
		if prop_name == "script":
			has_button_script = str(prop_value).find("BasePanelContainerButton.gd") >= 0
		if prop_name == "theme_type_variation" and str(prop_value) == "BasePanelContainerButton":
			has_panel_variation = true
	if not has_button_script:
		push_error("ConnectomeButton must use BasePanelContainerButton so it has a button plate")
		return 1
	if not has_panel_variation:
		push_error("ConnectomeButton must use the BasePanelContainerButton theme plate")
		return 1
	var script: Script = load(COMBO_SCRIPT_PATH)
	if script.ICON_BUTTON_PLATE_COLOR != Color8(67, 67, 67):
		push_error("Connectome plate must match inspector/camera icon fill #434343")
		return 1
	if int(script.CONNECTOME_PLATE_PAD_X) != 12:
		push_error("Connectome plate must keep horizontal padding")
		return 1
	if not is_equal_approx(float(script.CONNECTOME_HOVER_SCALE), 1.1):
		push_error("Connectome hover must use the reduced in-place pop")
		return 1
	if not is_equal_approx(float(script.connectome_hover_scale(true)), 1.1):
		push_error("hover scale must be the fixed pop factor")
		return 1
	if not is_equal_approx(float(script.connectome_hover_scale(false)), 1.0):
		push_error("off-hover must return scale 1")
		return 1
	return 0


func _test_connectome_inner_hbox_ignores_mouse() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var hbox_index: int = -1
	for i in range(state.get_node_count()):
		if state.get_node_name(i) != "HBoxContainer":
			continue
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("ConnectomeButton") >= 0 and path_str.find("ConnectomeMenu") < 0:
			hbox_index = i
			break
	if hbox_index < 0:
		push_error("ConnectomeButton HBoxContainer missing from BrainObjectsCombo scene")
		return 1
	for i in range(state.get_node_property_count(hbox_index)):
		if str(state.get_node_property_name(hbox_index, i)) == "mouse_filter":
			if int(state.get_node_property_value(hbox_index, i)) != 2:
				push_error("Connectome inner HBox must IGNORE mouse so the plate owns the click")
				return 1
			return 0
	push_error("Connectome inner HBox must set mouse_filter=IGNORE")
	return 1


func _test_scene_has_connectome_trigger() -> int:
	var paths := _collect_scene_node_paths()
	if not _has_path_suffix(paths, "ConnectomeButton"):
		push_error("BrainObjectsCombo scene must include ConnectomeButton")
		return 1
	if not _has_path_suffix(paths, "ConnectomeMenu"):
		push_error("BrainObjectsCombo scene must include ConnectomeMenu")
		return 1
	return 0


func _test_scene_keeps_object_combos_inside_menu() -> int:
	var paths := _collect_scene_node_paths()
	var required_in_menu := [
		"ConnectomeMenu/MarginContainer/MenuItems/BrainRegionsRow",
		"ConnectomeMenu/MarginContainer/MenuItems/InterconnectAreasRow",
		"ConnectomeMenu/MarginContainer/MenuItems/MemoryAreasRow",
		"ConnectomeMenu/MarginContainer/MenuItems/ClassifierRow",
	]
	for required in required_in_menu:
		if not _has_path_containing(paths, required):
			push_error("Connectome menu must contain combo row path fragment: %s" % required)
			return 1
	if _has_direct_strip_child(paths, "InterconnectGroup") or _has_direct_strip_child(paths, "MemoryGroup"):
		push_error("Interconnect/Memory groups must not remain on the combo strip")
		return 1
	return 0


func _test_classifier_row_uses_carbon_icon() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var tex_index: int = -1
	for i in range(state.get_node_count()):
		if state.get_node_name(i) != "TextureRect":
			continue
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("ClassifierList") >= 0:
			tex_index = i
			break
	if tex_index < 0:
		push_error("ClassifierList TextureRect missing from BrainObjectsCombo scene")
		return 1
	for i in range(state.get_node_property_count(tex_index)):
		if str(state.get_node_property_name(tex_index, i)) != "texture":
			continue
		var tex_value := str(state.get_node_property_value(tex_index, i))
		if tex_value.find("carbon.png") < 0:
			push_error("Classifier icon must be carbon.png (got %s)" % tex_value)
			return 1
		return 0
	push_error("Classifier TextureRect must set the carbon.png texture")
	return 1


func _test_combo_rows_scale_label_not_hbox() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var label_targets: int = 0
	for i in range(state.get_node_count()):
		var node_name := str(state.get_node_name(i))
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("ConnectomeButton") >= 0:
			continue
		var has_scale_meta := false
		for p in range(state.get_node_property_count(i)):
			if str(state.get_node_property_name(i, p)) != "metadata/hover_scale_target":
				continue
			has_scale_meta = bool(state.get_node_property_value(i, p))
		if not has_scale_meta:
			continue
		if node_name == "HBoxContainer":
			push_error("Combo row HBox must not be the hover scale target (that also enlarges +): %s" % path_str)
			return 1
		if node_name == "Label":
			label_targets += 1
	if label_targets < 6:
		push_error("Each combo list label must be the hover scale target (found %d)" % label_targets)
		return 1
	return 0


func _test_combo_list_labels_pass_mouse_to_parent() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var passed: int = 0
	for i in range(state.get_node_count()):
		if str(state.get_node_name(i)) != "Label":
			continue
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("ConnectomeButton") >= 0:
			continue
		if path_str.find("List") < 0:
			continue
		var mouse_filter := 2
		for p in range(state.get_node_property_count(i)):
			if str(state.get_node_property_name(i, p)) == "mouse_filter":
				mouse_filter = int(state.get_node_property_value(i, p))
		if mouse_filter != 1:
			push_error("Combo list label must PASS mouse so the list button receives the click: %s" % path_str)
			return 1
		passed += 1
	if passed < 6:
		push_error("Each combo list label must PASS mouse (found %d)" % passed)
		return 1
	return 0


func _test_scene_keeps_inputs_outputs_on_strip() -> int:
	var paths := _collect_scene_node_paths()
	if not _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/InputsRow"):
		push_error("Inputs combo must remain on the strip under MainGroup")
		return 1
	if not _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/OutputsRow"):
		push_error("Outputs combo must remain on the strip under MainGroup")
		return 1
	if _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/BrainRegionsRow"):
		push_error("Circuits combo must not remain on the MainGroup strip")
		return 1
	return 0


func _test_scene_menu_row_order() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	var expected_names: PackedStringArray = script.connectome_menu_row_node_names()
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	if _find_node_index_by_name(state, "MenuItems") < 0:
		push_error("Connectome MenuItems node missing from scene")
		return 1
	var child_names: PackedStringArray = PackedStringArray()
	for i in range(state.get_node_count()):
		var path_str := str(state.get_node_path(i, false))
		if path_str.ends_with("/MenuItems/" + state.get_node_name(i)) or path_str.ends_with("MenuItems/" + state.get_node_name(i)):
			if state.get_node_name(i) != "MenuItems":
				child_names.append(state.get_node_name(i))
	if child_names != expected_names:
		push_error("Connectome menu row order must be %s (got %s)" % [expected_names, child_names])
		return 1
	return 0


func _test_align_connectome_menu_add_buttons_right_justifies_plus() -> int:
	var menu := VBoxContainer.new()
	root.add_child(menu)
	var short_row := _make_combo_row("Circuits")
	var long_row := _make_combo_row("Interconnect Areas")
	menu.add_child(short_row)
	menu.add_child(long_row)
	var script: Script = load(COMBO_SCRIPT_PATH)
	script.align_connectome_menu_add_buttons(menu)
	var short_list: Control = short_row.get_node("HBoxContainer/List")
	var short_gap: Control = short_row.get_node("HBoxContainer/RowGap")
	var short_label: Label = short_row.get_node("HBoxContainer/List/HBoxContainer/Label")
	var long_label: Label = long_row.get_node("HBoxContainer/List/HBoxContainer/Label")
	var short_plus: TextureButton = short_row.get_node("HBoxContainer/Plus")
	var long_plus: TextureButton = long_row.get_node("HBoxContainer/Plus")
	var failed: int = 0
	if short_row.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("Connectome menu rows must expand to the menu width")
		failed = 1
	if short_list.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		push_error("Connectome list buttons must shrink to icon+text")
		failed = 1
	if short_gap.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("Connectome row gap must expand so + buttons right-justify")
		failed = 1
	if short_gap.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("Connectome row gap must ignore mouse so it is not a text hit box")
		failed = 1
	if short_label.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		push_error("Connectome menu labels must shrink to the text bounds")
		failed = 1
	if long_label.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		push_error("Long connectome menu labels must shrink to the text bounds")
		failed = 1
	if short_plus.size_flags_horizontal != Control.SIZE_SHRINK_END:
		push_error("Connectome + buttons must shrink-end (right justify)")
		failed = 1
	if long_plus.size_flags_horizontal != Control.SIZE_SHRINK_END:
		push_error("Long-row + buttons must shrink-end (right justify)")
		failed = 1
	menu.queue_free()
	return failed


func _test_list_and_plus_are_siblings_on_shared_plate() -> int:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var list_parent := ""
	var plus_parent := ""
	var row_has_plate := false
	for i in range(state.get_node_count()):
		var node_name := str(state.get_node_name(i))
		var path_str := str(state.get_node_path(i, false))
		if node_name == "BrainRegionsList":
			list_parent = path_str.get_base_dir()
		if node_name == "TextureButton_BrainRegions":
			plus_parent = path_str.get_base_dir()
			if path_str.find("BrainRegionsList") >= 0:
				push_error("Add button must not be nested under the list button")
				return 1
		if node_name == "BrainRegionsRow":
			for p in range(state.get_node_property_count(i)):
				if str(state.get_node_property_name(i, p)) == "theme_override_styles/panel":
					row_has_plate = true
	if list_parent == "" or plus_parent == "":
		push_error("Circuits list and + must exist in BrainObjectsCombo")
		return 1
	if list_parent != plus_parent:
		push_error("Circuits list and + must be siblings on the shared row (list parent %s, plus parent %s)" % [list_parent, plus_parent])
		return 1
	if not row_has_plate:
		push_error("Combo row must paint a shared neutral backdrop")
		return 1
	return 0


func _test_keep_menu_open_when_pointer_still_on_trigger() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	if not bool(script.should_keep_connectome_menu_open_after_focus_lost(false, true)):
		push_error("Connectome menu must stay open when the popup steals focus but the pointer is still on the button")
		return 1
	if not bool(script.should_keep_connectome_menu_open_after_focus_lost(true, false)):
		push_error("Connectome menu must stay open when the pointer is over the menu")
		return 1
	if bool(script.should_keep_connectome_menu_open_after_focus_lost(false, false)):
		push_error("Connectome menu must close when the pointer is on neither the menu nor the button")
		return 1
	return 0


func _test_tab_overlay_z_index_matches_circuit_builder() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	if int(script.TAB_OVERLAY_Z_INDEX) != 10:
		push_error("Brain Monitor combo overlay z_index must match Circuit Builder (10)")
		return 1
	return 0


func _make_combo_row(label_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	var list := PanelContainer.new()
	list.name = "List"
	var inner := HBoxContainer.new()
	inner.name = "HBoxContainer"
	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	inner.add_child(label)
	list.add_child(inner)
	var gap := Control.new()
	gap.name = "RowGap"
	var plus := TextureButton.new()
	plus.name = "Plus"
	hbox.add_child(list)
	hbox.add_child(gap)
	hbox.add_child(plus)
	row.add_child(hbox)
	return row


func _collect_scene_node_paths() -> PackedStringArray:
	var packed: PackedScene = load(COMBO_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var paths: PackedStringArray = PackedStringArray()
	for i in range(state.get_node_count()):
		paths.append(str(state.get_node_path(i, false)))
	return paths


func _has_path_suffix(paths: PackedStringArray, node_name: String) -> bool:
	for path in paths:
		if String(path).ends_with(node_name) or String(path) == node_name:
			return true
	return false


func _has_path_containing(paths: PackedStringArray, fragment: String) -> bool:
	for path in paths:
		if String(path).find(fragment) >= 0:
			return true
	return false


func _has_direct_strip_child(paths: PackedStringArray, child_name: String) -> bool:
	for path in paths:
		var text := String(path)
		if text == child_name or text == "./" + child_name or text.ends_with("/" + child_name) and text.find("ConnectomeMenu") < 0 and text.count("/") <= 1:
			if text.find("ConnectomeMenu") < 0 and (text == child_name or text == "./" + child_name):
				return true
	return false


func _find_node_index_by_name(state: SceneState, node_name: String) -> int:
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == node_name:
			return i
	return -1
