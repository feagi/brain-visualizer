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
	failures += _test_combo_plate_gap_matches_icon_strip()
	if failures == 0:
		print("Combo row plate padding tests: PASS")
		quit(0)
	else:
		push_error("Combo row plate padding tests: FAIL (%d)" % failures)
		quit(1)


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
