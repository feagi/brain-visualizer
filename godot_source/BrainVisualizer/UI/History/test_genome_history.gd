extends SceneTree
## Position undo/redo stack. Does not call FEAGI.
## Run: godot --headless -s res://BrainVisualizer/UI/History/test_genome_history.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_equal_coordinates_are_not_stored()
	failures += _test_undo_redo_and_new_gesture_clears_redo()
	failures += _test_history_limit_drops_oldest()
	failures += _test_history_ignores_edits_until_accepting()
	failures += _test_shortcuts()
	failures += _test_text_focus_blocks_shortcut()
	failures += _test_parse_vector3i()
	failures += _test_2d_move_keeps_start_coordinate()
	failures += _test_position_writers_record_history()
	failures += _test_position_scripts_compile()
	if failures == 0:
		print("Genome history tests: PASS")
		quit(0)
	else:
		push_error("Genome history tests: FAIL (%d)" % failures)
		quit(1)


func _test_equal_coordinates_are_not_stored() -> int:
	var edit := PositionEdit.new()
	edit.add_cortical_3d(&"area", Vector3i(1, 2, 3), Vector3i(1, 2, 3))
	edit.add_region_3d(&"region", Vector3i(4, 5, 6), Vector3i(4, 0, 6))
	if edit.entry_count() != 1:
		push_error("Unchanged coordinates must not become a history step")
		return 1
	if edit.vector_at(0, false) != Vector3i(4, 5, 6) or edit.vector_at(0, true) != Vector3i(4, 0, 6):
		push_error("A stored step must keep the before and after coordinates")
		return 1
	return 0


func _test_undo_redo_and_new_gesture_clears_redo() -> int:
	var history := GenomeHistory.new()
	history.set_accepting(true)
	history.record(_move(&"a", Vector3i.ZERO, Vector3i(1, 0, 0)))
	history.record(_move(&"b", Vector3i.ZERO, Vector3i(0, 2, 0)))
	if history.peek_undo().entry_at(0)["id"] != &"b":
		push_error("Undo must return the latest gesture")
		return 1
	history.confirm_undo()
	if history.undo_count() != 1 or history.redo_count() != 1:
		push_error("Confirming undo must move that gesture onto the redo stack")
		return 1
	if history.peek_redo().vector_at(0, true) != Vector3i(0, 2, 0):
		push_error("Redo must restore the coordinate that was undone")
		return 1
	history.confirm_redo()
	if history.undo_count() != 2 or history.has_redo():
		push_error("Confirming redo must put the gesture back on the undo stack")
		return 1
	history.confirm_undo()
	history.record(_move(&"c", Vector3i.ZERO, Vector3i(0, 0, 3)))
	if history.has_redo():
		push_error("A new gesture must clear the redo stack")
		return 1
	history.clear()
	if history.has_undo() or history.has_redo():
		push_error("Clearing history must drop undo and redo")
		return 1
	return 0


func _test_history_limit_drops_oldest() -> int:
	var history := GenomeHistory.new()
	history.set_accepting(true)
	for index in GenomeHistory.HISTORY_LIMIT + 1:
		history.record(_move(StringName(str(index)), Vector3i.ZERO, Vector3i(index + 1, 0, 0)))
	if history.undo_count() != GenomeHistory.HISTORY_LIMIT:
		push_error("History must keep only HISTORY_LIMIT gestures")
		return 1
	history.confirm_undo()
	while history.has_undo():
		history.confirm_undo()
	if history.peek_redo() == null:
		push_error("Redo stack must contain the undone gestures")
		return 1
	var oldest_redo: PositionEdit = history.peek_redo()
	# The newest gesture is confirmed first, so the last peek after draining undo is the oldest remaining one.
	if oldest_redo.entry_at(0)["id"] == &"0":
		push_error("The oldest gesture must be dropped when the history limit is exceeded")
		return 1
	return 0


func _test_history_ignores_edits_until_accepting() -> int:
	var history := GenomeHistory.new()
	history.record(_move(&"a", Vector3i.ZERO, Vector3i.ONE))
	if history.has_undo():
		push_error("History must ignore gestures until the genome is ready")
		return 1
	history.set_accepting(true)
	history.record(PositionEdit.new())
	if history.has_undo():
		push_error("An empty gesture must not be recorded")
		return 1
	return 0


func _test_shortcuts() -> int:
	if GenomeHistory.history_shortcut(KEY_Z, true, false, false, true, false) != &"undo":
		push_error("Ctrl+Z or Cmd+Z must undo")
		return 1
	if GenomeHistory.history_shortcut(KEY_Z, true, true, false, true, false) != &"redo":
		push_error("Shift+Ctrl+Z or Shift+Cmd+Z must redo")
		return 1
	if GenomeHistory.history_shortcut(KEY_Z, true, false, true, true, false) != &"":
		push_error("Alt+Ctrl+Z must not change position history")
		return 1
	if GenomeHistory.history_shortcut(KEY_Z, false, false, false, true, false) != &"":
		push_error("Z without Ctrl or Cmd must not change position history")
		return 1
	if GenomeHistory.history_shortcut(KEY_Z, true, false, false, true, true) != &"":
		push_error("Key repeat must not change position history")
		return 1
	return 0


func _test_text_focus_blocks_shortcut() -> int:
	var line := LineEdit.new()
	var text := TextEdit.new()
	var button := Button.new()
	var blocked := GenomeHistory.focus_blocks_history_shortcut(line) and GenomeHistory.focus_blocks_history_shortcut(text)
	var button_blocked := GenomeHistory.focus_blocks_history_shortcut(button)
	var empty_blocked := GenomeHistory.focus_blocks_history_shortcut(null)
	line.free()
	text.free()
	button.free()
	if not blocked or button_blocked or empty_blocked:
		push_error("Position history shortcuts must stay out of text fields")
		return 1
	return 0


func _test_parse_vector3i() -> int:
	var from_array: Dictionary = PositionEdit.parse_vector3i([8, 9, 10])
	var from_dict: Dictionary = PositionEdit.parse_vector3i({"x": 1, "y": 2, "z": 3})
	var missing: Dictionary = PositionEdit.parse_vector3i(null)
	if not bool(from_array.get("ok", false)) or from_array["value"] != Vector3i(8, 9, 10):
		push_error("Coordinate arrays from FEAGI must parse")
		return 1
	if not bool(from_dict.get("ok", false)) or from_dict["value"] != Vector3i(1, 2, 3):
		push_error("Coordinate dictionaries from the properties panel must parse")
		return 1
	if bool(missing.get("ok", false)):
		push_error("A missing coordinate must not parse as a position")
		return 1
	return 0


func _test_2d_move_keeps_start_coordinate() -> int:
	var edit := PositionEdit.new()
	edit.label = "Move"
	edit.add_change(&"area-2d", PositionEdit.KIND_CORTICAL_AREA, PositionEdit.SPACE_2D, Vector2i(3, 4), Vector2i(9, 4))
	if edit.entry_count() != 1:
		push_error("A 2D move must store one entry")
		return 1
	if edit.entry_at(0)["kind"] != PositionEdit.KIND_CORTICAL_AREA or edit.entry_at(0)["space"] != PositionEdit.SPACE_2D:
		push_error("A cortical 2D move must be marked as a cortical area on the 2D plane")
		return 1
	if edit.vector_at(0, false) != Vector2i(3, 4) or edit.vector_at(0, true) != Vector2i(9, 4):
		push_error("A 2D move must keep the coordinate from the start of the gesture")
		return 1
	return 0


func _test_position_writers_record_history() -> int:
	var sources: PackedStringArray = PackedStringArray([
		"res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd",
		"res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd",
		"res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.gd",
		"res://BrainVisualizer/UI/Windows/EditRegion/WindowEditRegion.gd",
		"res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/AdvancedCorticalProperties.gd",
		"res://BrainVisualizer/UI/UIManager.gd",
	])
	for path in sources:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("record_position_edit"):
			push_error("Position changes in %s must record history" % path)
			return 1
	var ui_text := FileAccess.get_file_as_string("res://BrainVisualizer/UI/UIManager.gd")
	if not ui_text.contains("GenomePositionApplier.apply"):
		push_error("Ctrl+Z must apply position history through GenomePositionApplier")
		return 1
	return 0


func _test_position_scripts_compile() -> int:
	var sources: PackedStringArray = PackedStringArray([
		"res://BrainVisualizer/UI/History/GenomePositionApplier.gd",
		"res://BrainVisualizer/UI/UIManager.gd",
		"res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd",
		"res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd",
		"res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.gd",
		"res://BrainVisualizer/UI/Windows/EditRegion/WindowEditRegion.gd",
		"res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/AdvancedCorticalProperties.gd",
	])
	for path in sources:
		var compiled: Script = load(path)
		if compiled == null:
			push_error("Position history script failed to compile: %s" % path)
			return 1
	return 0


func _move(cortical_id: StringName, before: Vector3i, after: Vector3i) -> PositionEdit:
	var ids: Array[StringName] = [cortical_id]
	var befores: Array[Vector3i] = [before]
	var afters: Array[Vector3i] = [after]
	return PositionEdit.cortical_3d_moves("Move", ids, befores, afters)
