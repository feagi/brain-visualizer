extends SceneTree
## Episodic mappings are yellow in Circuit Builder and the 3D brain view.
## Run: godot --headless -s res://BrainVisualizer/UI/CircuitBuilder/CBLine/test_episodic_connection_color.gd

const CB_LINE := "res://BrainVisualizer/UI/CircuitBuilder/CBLine/CBLineInterTerminal.gd"
const MAPPING := "res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Mappings/SingleMappingDefinition.gd"
const MAPPING_SET := "res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Mappings/InterCorticalMappingSet.gd"
const PARTIAL_SET := "res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Mappings/PartialMappingSet.gd"
const MONITOR := "res://addons/UI_BrainMonitor/UI_BrainMonitor_CorticalArea.gd"


func _initialize() -> void:
	var failures := 0
	failures += _require(CB_LINE, "const LINE_COLOR_EPISODIC: Color = Color(0.95, 0.82, 0.08, 1)")
	failures += _require(CB_LINE, "is_every_mapping_episodic()")
	failures += _require(MAPPING, "func is_episodic_mapping()")
	failures += _require(MAPPING, "&\"episodic_memory\"")
	failures += _require(MAPPING, "&\"episodic_scan\"")
	failures += _require(MAPPING_SET, "func is_every_mapping_episodic()")
	failures += _require(PARTIAL_SET, "func is_every_mapping_episodic()")
	failures += _require(MONITOR, "mapping.is_episodic_mapping()")
	failures += _require(MONITOR, "Color(1.0, 0.92, 0.15, 0.9)")
	for script_path in [CB_LINE, MAPPING, MAPPING_SET, PARTIAL_SET, MONITOR]:
		if load(script_path) == null:
			push_error("failed to parse %s" % script_path)
			failures += 1
	failures += _test_recursive_loop_height_offsets()
	if failures > 0:
		push_error("episodic connection color: %d check(s) failed" % failures)
		quit(1)
		return
	quit(0)


func _test_recursive_loop_height_offsets() -> int:
	var monitor: GDScript = load(MONITOR)
	if monitor == null:
		return 1
	var two: Array[float] = monitor.recursive_loop_height_offsets(2)
	if two.size() != 2 or not is_equal_approx(two[0], 0.6) or not is_equal_approx(two[1], -0.6):
		push_error("two polarities should use two loop heights, got %s" % str(two))
		return 1
	var three: Array[float] = monitor.recursive_loop_height_offsets(3)
	if three.size() != 3 or not is_equal_approx(three[1], 0.0):
		push_error("three polarities should use three loop heights, got %s" % str(three))
		return 1
	return 0


func _require(path: String, needle: String) -> int:
	var source := FileAccess.get_file_as_string(path)
	if source.find(needle) < 0:
		push_error("%s must contain %s" % [path, needle])
		return 1
	return 0
