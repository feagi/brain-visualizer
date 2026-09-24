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
	failures += _test_delete_shares_the_history_stack()
	failures += _test_delete_snapshot_keeps_properties_and_mappings()
	failures += _test_memory_replay_edge_is_not_restored()
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
	var latest: PositionEdit = history.peek_undo() as PositionEdit
	if latest.entry_at(0)["id"] != &"b":
		push_error("Undo must return the latest gesture")
		return 1
	history.confirm_undo()
	if history.undo_count() != 1 or history.redo_count() != 1:
		push_error("Confirming undo must move that gesture onto the redo stack")
		return 1
	var redone: PositionEdit = history.peek_redo() as PositionEdit
	if redone.vector_at(0, true) != Vector3i(0, 2, 0):
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
	var oldest_redo: PositionEdit = history.peek_redo() as PositionEdit
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
	if not ui_text.contains("GenomeEditApplier.apply"):
		push_error("Ctrl+Z must apply history through GenomeEditApplier")
		return 1
	var dispatch_text := FileAccess.get_file_as_string("res://BrainVisualizer/UI/History/GenomeEditApplier.gd")
	if not dispatch_text.contains("GenomePositionApplier.apply"):
		push_error("Position steps must still apply through GenomePositionApplier")
		return 1
	var confirm_text := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Windows/ConfirmDeletion/WindowConfirmDeletion.gd")
	if not confirm_text.contains("DeleteAreaApplier.capture") or not confirm_text.contains("record_genome_edit"):
		push_error("Area delete must snapshot the area and record one history step")
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


func _test_delete_shares_the_history_stack() -> int:
	var history := GenomeHistory.new()
	history.set_accepting(true)
	history.record(_move(&"moved", Vector3i.ZERO, Vector3i.ONE))
	var deleted := _delete_edit("A", "A2")
	history.record(deleted)
	history.confirm_undo()
	if not (history.peek_redo() is DeleteAreaEdit):
		push_error("Undo must reverse the delete before the earlier move")
		return 1
	history.record(_move(&"later", Vector3i.ZERO, Vector3i(2, 0, 0)))
	if history.has_redo():
		push_error("A new gesture must clear a delete that was undone")
		return 1
	history.record(DeleteAreaEdit.new())
	if history.peek_undo() is DeleteAreaEdit:
		push_error("An empty delete must not be recorded")
		return 1
	return 0


func _test_delete_snapshot_keeps_properties_and_mappings() -> int:
	var edit := _delete_edit("A", "A2")
	edit.add_area(_area_snapshot("B", "B2", {}))
	var payload: Dictionary = DeleteAreaEdit.update_payload(edit.snapshot_at(0)["properties"])
	if not payload.has("neuron_fire_threshold") or payload["neuron_fire_threshold"] != 1.5:
		push_error("Undo must keep the firing threshold from the property record")
		return 1
	if not payload.has("neuron_leak_coefficient") or payload["neuron_leak_coefficient"] != 0.2:
		push_error("Undo must keep property-bag fields that are not duplicated at the top level")
		return 1
	if payload.has("neuron_count") or payload.has("cortical_mapping_dst") or payload.has("cortical_id"):
		push_error("Undo must not send synapse counts, mappings, or the old id as area properties")
		return 1
	if not DeleteAreaEdit.can_recreate("CUSTOM") or DeleteAreaEdit.can_recreate("CORE"):
		push_error("Only groups FEAGI can create again belong in delete undo")
		return 1
	var writes: Array[Dictionary] = edit.mapping_writes()
	if writes.size() != 3:
		push_error("An edge between two deleted areas must be restored once, plus each incoming edge from an area that stayed")
		return 1
	var restored_internal := false
	var restored_incoming := false
	for write in writes:
		var rules: Array = write["rules"]
		if write["source_id"] == "A2" and write["destination_id"] == "B2":
			restored_internal = rules.size() == 1 and rules[0]["gate_source_area"] == "A2"
		if write["source_id"] == "C" and write["destination_id"] == "A2":
			restored_incoming = true
	if not restored_internal or not restored_incoming:
		push_error("Restored mappings must use the new ids, including ids stored inside a rule")
		return 1
	return 0


func _test_memory_replay_edge_is_not_restored() -> int:
	var edit := DeleteAreaEdit.new()
	var snapshot := _area_snapshot("M", "M2", {
		"twin-old": [{"morphology_id": "memory_replay"}],
		"other": [{"morphology_id": "associative_memory"}],
	})
	snapshot["properties"]["memory_twin_areas"] = {"field": "twin-old"}
	snapshot["properties"]["cortical_group"] = "MEMORY"
	snapshot["incoming"] = [{"source_id": "sensor", "rules": [{"morphology_id": "episodic_memory"}]}]
	edit.add_area(snapshot)
	var payload: Dictionary = DeleteAreaEdit.update_payload(snapshot["properties"])
	if payload.has("memory_twin_areas"):
		push_error("Undo must let FEAGI recreate the memory twin instead of sending the old twin id")
		return 1
	var writes: Array[Dictionary] = edit.mapping_writes()
	if writes.size() != 2:
		push_error("Undo must restore the inbound memory mapping and real outbound mappings")
		return 1
	if writes[0]["source_id"] != "sensor" or writes[0]["destination_id"] != "M2":
		push_error("The inbound memory mapping must be restored before outbound mappings")
		return 1
	if writes[1]["destination_id"] != "other":
		push_error("A real outbound mapping must still be restored")
		return 1
	for write in writes:
		if write["destination_id"] == "twin-old":
			push_error("The generated memory replay edge must not be written back to the old twin")
			return 1
	return 0


func _delete_edit(original_id: String, restored_id: String) -> DeleteAreaEdit:
	var edit := DeleteAreaEdit.new()
	edit.add_area(_area_snapshot(original_id, restored_id, {
		"B": [{"morphology_id": "block_to_block", "gate_source_area": original_id}],
	}))
	return edit


func _area_snapshot(original_id: String, restored_id: String, outgoing: Dictionary) -> Dictionary:
	return {
		"original_id": original_id,
		"restored_id": restored_id,
		"parent_region_id": "root",
		"coordinates_2d": Vector2i(1, 2),
		"coordinates_2d_defined": true,
		"properties": {
			"cortical_name": "Vision",
			"cortical_group": "CUSTOM",
			"cortical_id": original_id,
			"neuron_fire_threshold": 1.5,
			"neuron_count": 10,
			"properties": {
				"cortical_mapping_dst": outgoing,
				"neuron_leak_coefficient": 0.2,
			},
		},
		"incoming": [{"source_id": "C", "rules": [{"morphology_id": "projector"}]}],
	}


func _move(cortical_id: StringName, before: Vector3i, after: Vector3i) -> PositionEdit:
	var ids: Array[StringName] = [cortical_id]
	var befores: Array[Vector3i] = [before]
	var afters: Array[Vector3i] = [after]
	return PositionEdit.cortical_3d_moves("Move", ids, befores, afters)
