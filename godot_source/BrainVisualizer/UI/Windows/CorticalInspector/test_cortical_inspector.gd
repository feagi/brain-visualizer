extends SceneTree
## Cortical inspector payload, slider span, and live-send coalescing.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/CorticalInspector/test_cortical_inspector.gd

const Model = preload("res://BrainVisualizer/UI/Windows/CorticalInspector/CorticalInspectorModel.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_scripts_compile()
	failures += _test_wire_values()
	failures += _test_default_spans()
	failures += _test_span_and_bounds()
	failures += _test_visibility_and_locks()
	failures += _test_menu_labels()
	failures += _test_focus_pick()
	failures += _test_live_send_coalesce()
	failures += _test_dropdown_scene_has_entry()
	if failures == 0:
		print("Cortical inspector tests: PASS")
		quit(0)
	else:
		push_error("Cortical inspector tests: FAIL (%d)" % failures)
		quit(1)


func _test_scripts_compile() -> int:
	if load("res://BrainVisualizer/UI/Windows/CorticalInspector/WindowCorticalInspector.gd") == null:
		push_error("WindowCorticalInspector.gd failed to compile")
		return 1
	if load("res://BrainVisualizer/UI/Windows/CorticalInspector/CorticalInspectorRow.gd") == null:
		push_error("CorticalInspectorRow.gd failed to compile")
		return 1
	if load("res://BrainVisualizer/UI/Top_Bar/ActivityVisualizationDropDown/ActivityVisualizationDropDown.gd") == null:
		push_error("ActivityVisualizationDropDown.gd failed to compile")
		return 1
	return 0


func _test_wire_values() -> int:
	if not is_equal_approx(float(Model.ui_to_wire("neuron_leak_coefficient", 50)), 0.5):
		push_error("leak percent must be sent as 0-1")
		return 1
	if not is_equal_approx(float(Model.ui_to_wire("neuron_excitability", 100)), 1.0):
		push_error("excitability percent must be sent as 0-1")
		return 1
	if not is_equal_approx(float(Model.ui_to_wire("neuron_fire_threshold", 1.25)), 1.25):
		push_error("fire threshold must stay a float")
		return 1
	if int(Model.ui_to_wire("neuron_refractory_period", 4.2)) != 4:
		push_error("refractory period must be an int")
		return 1
	var increment: Array = Model.ui_to_wire("neuron_fire_threshold_increment", Vector3(0.1, 0.2, 0.3))
	if increment.size() != 3 or not is_equal_approx(float(increment[1]), 0.2):
		push_error("threshold increment must be [x, y, z]")
		return 1
	if bool(Model.ui_to_wire("neuron_mp_driven_psp", true)) != true:
		push_error("MP-driven PSP must stay a bool")
		return 1
	return 0


func _test_default_spans() -> int:
	var expected := {
		"neuron_fire_threshold": Vector2(0, 20),
		"neuron_firing_threshold_limit": Vector2(0, 100),
		"neuron_fire_threshold_increment_x": Vector2(-1, 1),
		"neuron_refractory_period": Vector2(0, 64),
		"neuron_consecutive_fire_count": Vector2(0, 64),
		"neuron_snooze_period": Vector2(0, 64),
		"neuron_post_synaptic_potential": Vector2(-5, 5),
		"neuron_post_synaptic_potential_max": Vector2(0, 5),
	}
	for row_id in expected.keys():
		var spec: Dictionary = Model.spec_by_id(str(row_id))
		var span: Vector2 = expected[row_id]
		if spec.is_empty():
			push_error("missing spec %s" % row_id)
			return 1
		if not is_equal_approx(float(spec["default_min"]), span.x) or not is_equal_approx(float(spec["default_max"]), span.y):
			push_error("span mismatch for %s" % row_id)
			return 1
	var leak: Dictionary = Model.spec_by_id("neuron_leak_coefficient")
	if bool(leak["editable_bounds"]):
		push_error("percent leak must not grow min/max boxes")
		return 1
	return 0


func _test_span_and_bounds() -> int:
	var widened := Model.span_including_value(0.0, 20.0, 40.0)
	if not is_equal_approx(widened.x, 0.0) or not is_equal_approx(widened.y, 40.0):
		push_error("span must widen to the stored value")
		return 1
	var lowered := Model.span_including_value(-5.0, 5.0, -8.0)
	if not is_equal_approx(lowered.x, -8.0):
		push_error("span must widen below the default min")
		return 1
	var max_edit := Model.edit_bound(0.0, 20.0, 5.0, false, -10.0)
	if not is_equal_approx(max_edit.y, 5.0):
		push_error("max below the live value must snap to that value")
		return 1
	var min_edit := Model.edit_bound(0.0, 20.0, 5.0, true, 100.0)
	if not is_equal_approx(min_edit.x, 5.0):
		push_error("min above the live value must snap to that value")
		return 1
	var valid := Model.edit_bound(0.0, 20.0, 5.0, true, 2.0)
	if not is_equal_approx(valid.x, 2.0) or not is_equal_approx(valid.y, 20.0):
		push_error("a min inside the live value must stick")
		return 1
	return 0


func _test_visibility_and_locks() -> int:
	var leak: Dictionary = Model.spec_by_id("neuron_leak_coefficient")
	if Model.row_visible(leak, true, true):
		push_error("memory areas must hide leak")
		return 1
	var threshold: Dictionary = Model.spec_by_id("neuron_fire_threshold")
	if not Model.row_visible(threshold, true, true):
		push_error("memory areas keep fire threshold")
		return 1
	if Model.row_visible(threshold, false, false):
		push_error("areas without firing parameters hide firing rows")
		return 1
	if not Model.is_read_only(Model.CORTICAL_TYPE_CORE):
		push_error("core areas are read-only")
		return 1
	if Model.is_read_only(Model.CORTICAL_TYPE_CUSTOM):
		push_error("custom areas stay editable")
		return 1
	if not Model.value_entry_locked("neuron_post_synaptic_potential", true, false):
		push_error("MP-driven PSP locks the PSP slider")
		return 1
	if Model.value_entry_locked("neuron_post_synaptic_potential_max", true, false):
		push_error("MP-driven PSP leaves PSP max editable")
		return 1
	return 0


func _test_menu_labels() -> int:
	var entries: Array[Dictionary] = Model.build_area_menu_entries([
		{"id": "b", "name": "Vision"},
		{"id": "a", "name": "Alpha"},
		{"id": "c", "name": "Vision"},
	])
	if entries.size() != 3:
		push_error("menu entry count")
		return 1
	if str(entries[0]["label"]) != "Alpha":
		push_error("menu must sort by name")
		return 1
	if str(entries[1]["label"]) != "Vision (b)" or str(entries[2]["label"]) != "Vision (c)":
		push_error("duplicate names must keep the cortical id: %s" % entries)
		return 1
	return 0


func _test_focus_pick() -> int:
	if Model.pick_focus_id("", [], ["area-a"]) != "area-a":
		push_error("a single click focuses that area")
		return 1
	if Model.pick_focus_id("area-a", ["area-a"], ["area-a", "area-b"]) != "area-b":
		push_error("an added area becomes the focus")
		return 1
	if Model.pick_focus_id("area-b", ["area-a", "area-b"], ["area-a"]) != "area-a":
		push_error("a selection of one area focuses that area")
		return 1
	if Model.pick_focus_id("area-a", ["area-a", "area-b"], ["area-a", "area-b"]) != "area-a":
		push_error("an unchanged multi-selection keeps the current focus")
		return 1
	if Model.pick_focus_id("area-a", ["area-a"], []) != "":
		push_error("an empty selection does not invent a focus")
		return 1
	return 0


func _test_live_send_coalesce() -> int:
	var state := Model.new_send_state()
	if not Model.offer_value(state, 1.0):
		push_error("the first sample must send")
		return 1
	if Model.offer_value(state, 2.0):
		push_error("a second sample must wait")
		return 1
	if Model.offer_value(state, 3.0):
		push_error("a third sample must replace the pending value")
		return 1
	var nxt: Dictionary = Model.finish_success(state, 1.0)
	if not bool(nxt["has_next"]) or not is_equal_approx(float(nxt["value"]), 3.0):
		push_error("finish must return the latest pending sample")
		return 1
	if not Model.offer_value(state, nxt["value"]):
		push_error("the pending sample must send once the first call returns")
		return 1
	var done: Dictionary = Model.finish_success(state, 3.0)
	if bool(done["has_next"]):
		push_error("no further sample should be queued")
		return 1
	if Model.offer_value(state, 3.0):
		push_error("an equal value must not send again")
		return 1
	var failed := Model.new_send_state()
	Model.offer_value(failed, 4.0)
	Model.finish_success(failed, 4.0)
	Model.offer_value(failed, 9.0)
	var restore: Dictionary = Model.finish_failure(failed)
	if not bool(restore["has_restore"]) or not is_equal_approx(float(restore["value"]), 4.0):
		push_error("failure must restore the last accepted value")
		return 1
	var first_fail := Model.new_send_state()
	Model.offer_value(first_fail, 2.0)
	var no_restore: Dictionary = Model.finish_failure(first_fail)
	if bool(no_restore["has_restore"]):
		push_error("the first failure has no accepted value to restore")
		return 1
	return 0


func _test_dropdown_scene_has_entry() -> int:
	var path := "res://BrainVisualizer/UI/Top_Bar/ActivityVisualizationDropDown/ActivityVisualizationDropDown.tscn"
	var text := FileAccess.get_file_as_string(path)
	if text.find("CorticalInspector") < 0 or text.find("Cortical inspector") < 0:
		push_error("Inspectors menu is missing the cortical inspector entry")
		return 1
	var dropdown: Script = load("res://BrainVisualizer/UI/Top_Bar/ActivityVisualizationDropDown/ActivityVisualizationDropDown.gd")
	if str(dropdown.ACTION_CORTICAL_INSPECTOR) != "cortical_inspector":
		push_error("cortical inspector action id mismatch")
		return 1
	return 0
