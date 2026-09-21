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
	failures += _test_scene_keeps_object_combos_inside_menu()
	failures += _test_scene_keeps_inputs_outputs_on_strip()
	failures += _test_scene_menu_row_order()
	failures += _test_align_connectome_menu_add_buttons_right_justifies_plus()
	if failures == 0:
		print("BrainObjectsCombo connectome menu tests: PASS")
		quit(0)
	else:
		push_error("BrainObjectsCombo connectome menu tests: FAIL (%d)" % failures)
		quit(1)


func _test_menu_ids_are_circuit_interconnect_memory() -> int:
	var script: Script = load(COMBO_SCRIPT_PATH)
	var ids: PackedStringArray = script.connectome_menu_item_ids()
	var expected := PackedStringArray(["circuit", "interconnect", "memory"])
	if ids != expected:
		push_error("connectome_menu_item_ids must be circuit, interconnect, memory (got %s)" % [ids])
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
		"ConnectomeMenu/MarginContainer/MenuItems/BrainRegionsList",
		"ConnectomeMenu/MarginContainer/MenuItems/InterconnectAreasList",
		"ConnectomeMenu/MarginContainer/MenuItems/MemoryAreasList",
	]
	for required in required_in_menu:
		if not _has_path_containing(paths, required):
			push_error("Connectome menu must contain combo row path fragment: %s" % required)
			return 1
	if _has_direct_strip_child(paths, "InterconnectGroup") or _has_direct_strip_child(paths, "MemoryGroup"):
		push_error("Interconnect/Memory groups must not remain on the combo strip")
		return 1
	return 0


func _test_scene_keeps_inputs_outputs_on_strip() -> int:
	var paths := _collect_scene_node_paths()
	if not _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/InputsList"):
		push_error("Inputs combo must remain on the strip under MainGroup")
		return 1
	if not _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/OutputsList"):
		push_error("Outputs combo must remain on the strip under MainGroup")
		return 1
	if _has_path_containing(paths, "MainGroup/MarginContainer/ButtonsRow/BrainRegionsList"):
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
	var short_label: Label = short_row.get_node("HBoxContainer/Label")
	var long_label: Label = long_row.get_node("HBoxContainer/Label")
	var short_plus: TextureButton = short_row.get_node("HBoxContainer/Plus")
	var long_plus: TextureButton = long_row.get_node("HBoxContainer/Plus")
	var failed: int = 0
	if short_row.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("Connectome menu rows must expand to the menu width")
		failed = 1
	if short_label.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("Connectome menu labels must expand so + buttons right-justify")
		failed = 1
	if long_label.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("Long connectome menu labels must expand so + buttons right-justify")
		failed = 1
	if short_plus.size_flags_horizontal != Control.SIZE_SHRINK_END:
		push_error("Connectome + buttons must shrink-end (right justify)")
		failed = 1
	if long_plus.size_flags_horizontal != Control.SIZE_SHRINK_END:
		push_error("Long-row + buttons must shrink-end (right justify)")
		failed = 1
	menu.queue_free()
	return failed


func _make_combo_row(label_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	var plus := TextureButton.new()
	plus.name = "Plus"
	hbox.add_child(label)
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
