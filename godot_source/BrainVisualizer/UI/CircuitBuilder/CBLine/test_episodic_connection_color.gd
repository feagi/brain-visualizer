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
	if failures > 0:
		push_error("episodic connection color: %d check(s) failed" % failures)
		quit(1)
		return
	quit(0)


func _require(path: String, needle: String) -> int:
	var source := FileAccess.get_file_as_string(path)
	if source.find(needle) < 0:
		push_error("%s must contain %s" % [path, needle])
		return 1
	return 0
