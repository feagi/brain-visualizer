extends SceneTree
## Combo plates keep an inset so icons and plus buttons are not flush with the edge.
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/Buttons/test_combo_row_plate_padding.gd

const STYLER_PATH := "res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd"
const COMBO_SCENE_PATH := "res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/BrainObjectsCombo.tscn"
const TOP_BAR_SCENE_PATH := "res://BrainVisualizer/UI/Top_Bar/TopBar.tscn"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_apply_insets_the_plate()
	failures += _test_scene_row_plate("BrainRegionsRow", COMBO_SCENE_PATH)
	failures += _test_scene_row_plate("BrainAreasRow", TOP_BAR_SCENE_PATH)
	failures += _test_scene_row_plate("ModulatorsRow", TOP_BAR_SCENE_PATH)
	failures += _test_modulators_follows_connectivity_rules()
	failures += _test_combo_plate_gap_matches_icon_strip()
	failures += _test_hidden_plus_keeps_row_as_tall_as_icon_buttons()
	if failures == 0:
		print("Combo row plate padding tests: PASS")
		quit(0)
	else:
		push_error("Combo row plate padding tests: FAIL (%d)" % failures)
		quit(1)


func _test_hidden_plus_keeps_row_as_tall_as_icon_buttons() -> int:
	var styler: Script = load(STYLER_PATH)
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	var title := Label.new()
	title.name = "Title"
	title.visible = true
	var plus := TextureButton.new()
	plus.name = "Plus"
	plus.visible = false
	hbox.add_child(title)
	hbox.add_child(plus)
	row.add_child(hbox)
	root.add_child(row)
	styler.apply_combo_row_slot_height(row, 64.0)
	if not is_equal_approx(row.custom_minimum_size.y, 64.0):
		push_error("Category chip must keep the icon-button height after + is hidden")
		row.queue_free()
		return 1
	if row.size_flags_vertical != Control.SIZE_FILL:
		push_error("Category plate must fill the strip so it matches the square controls")
		row.queue_free()
		return 1
	if hbox.alignment != BoxContainer.ALIGNMENT_CENTER:
		push_error("Category chip content must stay vertically centered in the icon-button slot")
		row.queue_free()
		return 1
	if title.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		push_error("The visible title must fill the chip so hover covers the plate")
		row.queue_free()
		return 1
	if plus.size_flags_vertical == Control.SIZE_EXPAND_FILL:
		push_error("The hidden + must not be stretched back into the chip")
		row.queue_free()
		return 1
	row.queue_free()
	return 0


func _test_apply_insets_the_plate() -> int:
	var styler: Script = load(STYLER_PATH)
	var row := PanelContainer.new()
	root.add_child(row)
	var style := StyleBoxFlat.new()
	row.add_theme_stylebox_override("panel", style)
	styler.apply_combo_row_plate_padding(row)
	var applied := row.get_theme_stylebox("panel") as StyleBoxFlat
	if applied == null:
		push_error("Combo row plate padding must produce a StyleBoxFlat")
		row.queue_free()
		return 1
	if int(applied.content_margin_left) != int(styler.ROW_PAD_X):
		push_error("Combo row left inset must be %s" % [styler.ROW_PAD_X])
		row.queue_free()
		return 1
	if int(applied.content_margin_right) != int(styler.ROW_PAD_X):
		push_error("Combo row right inset must match the left inset")
		row.queue_free()
		return 1
	if int(applied.content_margin_top) != int(styler.ROW_PAD_Y):
		push_error("Combo row vertical inset must be %s" % [styler.ROW_PAD_Y])
		row.queue_free()
		return 1
	if int(applied.content_margin_bottom) != int(styler.ROW_PAD_Y):
		push_error("Combo row bottom inset must match the top inset")
		row.queue_free()
		return 1
	row.queue_free()
	return 0


func _test_scene_row_plate(row_name: String, scene_path: String) -> int:
	var styler: Script = load(STYLER_PATH)
	var packed: PackedScene = load(scene_path)
	var state: SceneState = packed.get_state()
	for i in range(state.get_node_count()):
		if str(state.get_node_name(i)) != row_name:
			continue
		for p in range(state.get_node_property_count(i)):
			if str(state.get_node_property_name(i, p)) != "theme_override_styles/panel":
				continue
			var plate := state.get_node_property_value(i, p) as StyleBoxFlat
			if plate == null:
				push_error("%s plate must be a StyleBoxFlat" % row_name)
				return 1
			if int(plate.content_margin_left) != int(styler.ROW_PAD_X):
				push_error("%s scene plate must use the shared horizontal inset" % row_name)
				return 1
			if int(plate.content_margin_top) != int(styler.ROW_PAD_Y):
				push_error("%s scene plate must use the shared vertical inset" % row_name)
				return 1
			return 0
		push_error("%s is missing a panel style override" % row_name)
		return 1
	push_error("%s missing from %s" % [row_name, scene_path])
	return 1


func _test_modulators_follows_connectivity_rules() -> int:
	var scene := FileAccess.get_file_as_string(TOP_BAR_SCENE_PATH)
	if scene.find("text = \"Modulators\"") < 0:
		push_error("Modulators combo must label the plate Modulators")
		return 1
	if scene.find("modulators.png") < 0:
		push_error("Modulators combo must use modulators.png")
		return 1
	var rules_header := "[node name=\"HBoxContainer3\" type=\"HBoxContainer\" parent=\"Buttons/MarginContainer/HBoxContainer\"]"
	var modulators_header := "[node name=\"ModulatorsHost\" type=\"HBoxContainer\" parent=\"Buttons/MarginContainer/HBoxContainer\"]"
	var rules_at := scene.find(rules_header)
	var modulators_at := scene.find(modulators_header)
	if rules_at < 0 or modulators_at < rules_at:
		push_error("Modulators must sit to the right of Connectivity Rules")
		return 1
	var packed: PackedScene = load(TOP_BAR_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var icon_is_category := false
	for i in range(state.get_node_count()):
		var path_str := str(state.get_node_path(i, false))
		if path_str.find("ModulatorsList") < 0 or str(state.get_node_name(i)) != "TextureRect":
			continue
		for p in range(state.get_node_property_count(i)):
			if str(state.get_node_property_name(i, p)) == "metadata/category_icon" and bool(state.get_node_property_value(i, p)):
				icon_is_category = true
	if not icon_is_category:
		push_error("Modulators icon must use the shared category icon size")
		return 1
	return 0


func _test_combo_plate_gap_matches_icon_strip() -> int:
	var styler: Script = load(STYLER_PATH)
	if int(styler.COMBO_PLATE_GAP) != 2:
		push_error("Combo plate gap must match the seam between icon-strip buttons")
		return 1
	var packed: PackedScene = load(TOP_BAR_SCENE_PATH)
	var state: SceneState = packed.get_state()
	var combo_gap := -1
	var icon_gap := -1
	for i in range(state.get_node_count()):
		var path_str := str(state.get_node_path(i, false))
		if path_str.ends_with("Buttons/MarginContainer/HBoxContainer") and path_str.find("HBoxContainer3") < 0 and path_str.count("/") <= 3:
			combo_gap = _separation_override(state, i)
		if path_str.ends_with("TopBarControlsPanel/MarginContainer/HBoxContainer"):
			icon_gap = _separation_override(state, i)
	if combo_gap < 0:
		push_error("Root combo strip is missing a separation override")
		return 1
	if icon_gap != 0:
		push_error("Icon strip separation changed; combo gap is measured against it")
		return 1
	if combo_gap != int(styler.COMBO_PLATE_GAP):
		push_error("Root combo strip gap must be the shared plate gap")
		return 1
	return 0


func _separation_override(state: SceneState, node_index: int) -> int:
	for p in range(state.get_node_property_count(node_index)):
		if str(state.get_node_property_name(node_index, p)) != "theme_override_constants/separation":
			continue
		return int(state.get_node_property_value(node_index, p))
	return -1
