extends SceneTree
## Live inspector text matches the voxel inspector summary metrics.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/VoxelInspector/test_voxel_inspector_live_summary.gd

const SummaryScript = preload("res://BrainVisualizer/UI/Windows/VoxelInspector/VoxelInspectorSummary.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_window_script_compiles()
	failures += _test_empty_voxel_uses_placeholders()
	failures += _test_single_neuron_membrane_potential()
	failures += _test_multiple_neurons_are_averaged()
	failures += _test_status_line_keeps_area_and_coordinate()
	failures += _test_firing_sample_replaces_reset_membrane()
	failures += _test_firing_membrane_lookup_averages_same_voxel()
	failures += _test_live_hover_policy()
	failures += _test_inspector_labels()
	if failures == 0:
		print("Voxel inspector live summary tests: PASS")
		quit(0)
	else:
		push_error("Voxel inspector live summary tests: FAIL (%d)" % failures)
		quit(1)


func _test_window_script_compiles() -> int:
	var window_script: GDScript = load("res://BrainVisualizer/UI/Windows/VoxelInspector/WindowVoxelInspector.gd") as GDScript
	if window_script == null:
		push_error("WindowVoxelInspector.gd failed to compile")
		return 1
	var overlay_script: GDScript = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_Overlay.gd") as GDScript
	if overlay_script == null:
		push_error("UI_BrainMonitor_Overlay.gd failed to compile")
		return 1
	return 0


func _test_empty_voxel_uses_placeholders() -> int:
	var summary: Dictionary = SummaryScript.summarize_voxel_neurons({
		"neuron_count": 0,
		"neurons": [],
	})
	if str(summary["neuron_count"]) != "0":
		push_error("empty voxel neuron_count")
		return 1
	if str(summary["membrane"]) != SummaryScript.EMPTY_METRIC:
		push_error("empty voxel membrane placeholder")
		return 1
	if str(summary["membrane_label"]) != "Membrane Potential":
		push_error("empty voxel membrane label")
		return 1
	var text: String = SummaryScript.format_live_inspector_text("vision", Vector3i(1, 2, 3), {
		"neuron_count": 0,
		"neurons": [],
	})
	if not text.begins_with("vision (1, 2, 3)"):
		push_error("empty voxel hover header: %s" % text)
		return 1
	if text.find("Membrane Potential: " + SummaryScript.EMPTY_METRIC) < 0:
		push_error("empty voxel hover membrane line")
		return 1
	return 0


func _test_single_neuron_membrane_potential() -> int:
	var payload := {
		"neuron_count": 1,
		"neurons": [{
			"membrane_potential": 0.42,
			"incoming_synapse_count": 3,
			"outgoing_synapse_count": 8,
			"threshold": 1.0,
			"refractory_countdown": 2,
			"consecutive_fire_count": 4,
		}],
	}
	var summary: Dictionary = SummaryScript.summarize_voxel_neurons(payload)
	var expected_mp: String = String.num(0.42, 4)
	if str(summary["membrane"]) != expected_mp:
		push_error("single neuron membrane got %s expected %s" % [summary["membrane"], expected_mp])
		return 1
	if str(summary["incoming"]) != "3" or str(summary["outgoing"]) != "8":
		push_error("single neuron synapse counts")
		return 1
	if str(summary["firing"]) != String.num(1.0, 4):
		push_error("single neuron threshold")
		return 1
	if str(summary["refractory"]) != "2" or str(summary["consecutive"]) != "4":
		push_error("single neuron refractory or consecutive")
		return 1
	var text: String = SummaryScript.format_live_inspector_text("motor", Vector3i(0, 0, 5), payload)
	if text.find("Membrane Potential: " + expected_mp) < 0:
		push_error("single neuron hover membrane line: %s" % text)
		return 1
	return 0


func _test_multiple_neurons_are_averaged() -> int:
	var payload := {
		"neuron_count": 2,
		"neurons": [
			{"membrane_potential": 1.0, "incoming_synapse_count": 1, "outgoing_synapse_count": 1, "threshold": 1.0, "refractory_countdown": 0, "consecutive_fire_count": 0},
			{"membrane_potential": 3.0, "incoming_synapse_count": 3, "outgoing_synapse_count": 5, "threshold": 3.0, "refractory_countdown": 2, "consecutive_fire_count": 4},
		],
	}
	var summary: Dictionary = SummaryScript.summarize_voxel_neurons(payload)
	if str(summary["membrane_label"]) != "Average Membrane Potential":
		push_error("multi neuron membrane label")
		return 1
	if str(summary["membrane"]) != String.num(2.0, 4):
		push_error("multi neuron average membrane got %s" % summary["membrane"])
		return 1
	if str(summary["incoming"]) != "2" or str(summary["outgoing"]) != "3":
		push_error("multi neuron average synapse counts")
		return 1
	if str(summary["refractory"]) != "1" or str(summary["consecutive"]) != "2":
		push_error("multi neuron average integer metrics")
		return 1
	return 0


func _test_firing_sample_replaces_reset_membrane() -> int:
	var payload := {
		"neuron_count": 1,
		"neurons": [{"membrane_potential": 0.0, "threshold": 1.0}],
	}
	var sample := {"found": true, "value": 1.5, "count": 1}
	var text: String = SummaryScript.format_live_inspector_text("vision", Vector3i(2, 3, 4), payload, sample)
	var expected_mp: String = String.num(1.5, 4)
	if text.find("Membrane Potential: " + expected_mp) < 0:
		push_error("firing sample did not replace reset membrane: %s" % text)
		return 1
	if text.find("Membrane Potential: 0") >= 0 and text.find(expected_mp) < 0:
		push_error("reset membrane still shown")
		return 1
	return 0


func _test_firing_membrane_lookup_averages_same_voxel() -> int:
	var x := PackedInt32Array([0, 1, 1])
	var y := PackedInt32Array([0, 2, 2])
	var z := PackedInt32Array([0, 3, 3])
	var p := PackedFloat32Array([9.0, 1.0, 3.0])
	var miss: Dictionary = SummaryScript.firing_membrane_at_coordinate(x, y, z, p, Vector3i(4, 4, 4))
	if bool(miss.get("found", true)):
		push_error("missing voxel reported as firing")
		return 1
	var hit: Dictionary = SummaryScript.firing_membrane_at_coordinate(x, y, z, p, Vector3i(1, 2, 3))
	if not bool(hit.get("found", false)):
		push_error("firing voxel not found")
		return 1
	if int(hit.get("count", 0)) != 2:
		push_error("firing voxel count")
		return 1
	if not is_equal_approx(float(hit.get("value", 0.0)), 2.0):
		push_error("firing voxel average")
		return 1
	return 0


func _test_status_line_keeps_area_and_coordinate() -> int:
	var text: String = SummaryScript.format_live_inspector_status("vision", Vector3i(4, 5, 6), "Loading…")
	if text != "vision (4, 5, 6)\nLoading…":
		push_error("status text: %s" % text)
		return 1
	return 0


func _test_live_hover_policy() -> int:
	if not SummaryScript.live_hover_should_fetch(false, true):
		push_error("synapse-only hover should fetch")
		return 1
	if SummaryScript.live_hover_should_fetch(false, false):
		push_error("both off should not fetch")
		return 1
	if not SummaryScript.live_hover_shows_summary(true) or SummaryScript.live_hover_shows_summary(false):
		push_error("summary follows neuron toggle")
		return 1
	if not SummaryScript.live_hover_shows_synapses(true) or SummaryScript.live_hover_shows_synapses(false):
		push_error("synapses follow synapse toggle")
		return 1
	if SummaryScript.live_stop_tooltip(true, false, true) != "Turn off live neuron inspector":
		push_error("neuron stop tooltip")
		return 1
	if SummaryScript.live_stop_tooltip(false, true, true) != "Turn off live synapse inspector":
		push_error("synapse stop tooltip")
		return 1
	if SummaryScript.live_stop_tooltip(true, true, true) != "Turn off live inspectors":
		push_error("both stop tooltip")
		return 1
	if SummaryScript.live_stop_tooltip(true, true, false) != "Turn off connection inspector":
		push_error("connection stop tooltip")
		return 1
	if not SummaryScript.suppress_cortical_mapping(true) or SummaryScript.suppress_cortical_mapping(false):
		push_error("cortical mapping suppression follows live synapse inspector")
		return 1
	if not SummaryScript.plate_hover_defers_to_neuron(true) or SummaryScript.plate_hover_defers_to_neuron(false):
		push_error("plate hover must defer when a neuron is under the cursor")
		return 1
	if not SummaryScript.prefer_hovered_monitor_for_synapses(true) or SummaryScript.prefer_hovered_monitor_for_synapses(false):
		push_error("synapse arcs must use the hovered view when it hosts the area")
		return 1
	return 0


func _test_inspector_labels() -> int:
	var scene_text: String = FileAccess.get_file_as_string("res://BrainVisualizer/UI/Windows/VoxelInspector/WindowVoxelInspector.tscn")
	if scene_text.is_empty():
		push_error("voxel inspector scene missing")
		return 1
	if not scene_text.contains("text = \"Live neuron inspector\""):
		push_error("live neuron inspector label missing")
		return 1
	if not scene_text.contains("text = \"Live synapse inspector\""):
		push_error("live synapse inspector label missing")
		return 1
	if scene_text.contains("text = \"Live inspector\""):
		push_error("old live inspector label still present")
		return 1
	return 0
