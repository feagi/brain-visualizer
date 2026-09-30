extends SceneTree
## Memory MP encoding contract: one dropdown choice <-> FEAGI `mp_learning_enabled` + `mp_change_mode`.
## Run: godot --headless --path godot_source -s res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/CorticalAreas/CorticalProperties/test_memory_mp_encoding.gd

const MEMORY_PARAMS_SCRIPT: String = "res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/CorticalAreas/CorticalProperties/CorticalPropertyMemoryParameters.gd"
const ADVANCED_SCENE: String = "res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/AdvancedCorticalProperties.tscn"
const CREATE_SCENE: String = "res://BrainVisualizer/UI/Windows/CreateCorticalArea/Parts/PartSpawnCorticalAreaMemory.tscn"


## Loaded at run time: the cache script depends on the FeagiCore autoload, which is not
## registered yet when a preload in this -s script is compiled.
var MemoryParams: GDScript


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	MemoryParams = load(MEMORY_PARAMS_SCRIPT)
	var failures: int = 0
	failures += _test_every_option_round_trips()
	failures += _test_keys_are_mutually_exclusive()
	failures += _test_change_mode_wins_over_stale_learning_flag()
	failures += _test_cache_parses_change_fields()
	failures += _test_cache_defaults_before_feagi_reports()
	failures += _test_scenes_replace_toggle_with_dropdown(ADVANCED_SCENE)
	failures += _test_scenes_replace_toggle_with_dropdown(CREATE_SCENE)
	if failures == 0:
		print("Memory MP encoding tests: PASS")
		quit(0)
	else:
		push_error("Memory MP encoding tests: FAIL (%d)" % failures)
		quit(1)


func _test_every_option_round_trips() -> int:
	for encoding in MemoryParams.MP_ENCODING_OPTIONS:
		var keys: Dictionary = MemoryParams.mp_encoding_to_keys(encoding)
		var back: StringName = MemoryParams.mp_encoding_from_keys(keys["mp_learning_enabled"], StringName(keys["mp_change_mode"]))
		if back != encoding:
			push_error("encoding %s round-tripped to %s" % [encoding, back])
			return 1
	return 0


func _test_keys_are_mutually_exclusive() -> int:
	var expected: Dictionary = {
		MemoryParams.MP_ENCODING_NONE: [false, "none"],
		MemoryParams.MP_ENCODING_LEARNING: [true, "none"],
		MemoryParams.MP_ENCODING_DIFFERENTIAL: [false, "mp_differential"],
		MemoryParams.MP_ENCODING_RATIO: [false, "mp_ratio"],
	}
	for encoding in expected:
		var keys: Dictionary = MemoryParams.mp_encoding_to_keys(encoding)
		if keys.size() != 2:
			push_error("encoding %s must always send both keys" % encoding)
			return 1
		if keys["mp_learning_enabled"] != expected[encoding][0] or keys["mp_change_mode"] != expected[encoding][1]:
			push_error("encoding %s produced %s" % [encoding, keys])
			return 1
	return 0


func _test_change_mode_wins_over_stale_learning_flag() -> int:
	# FEAGI rejects this pair; the display must still show the change mode rather than MP Learning.
	if MemoryParams.mp_encoding_from_keys(true, &"mp_ratio") != MemoryParams.MP_ENCODING_RATIO:
		push_error("change mode must take precedence when displaying a conflicting pair")
		return 1
	return 0


func _test_cache_parses_change_fields() -> int:
	var params = MemoryParams.new(null)
	params.FEAGI_apply_detail_dictionary({
		"mp_learning_enabled": false,
		"mp_change_mode": "mp_differential",
		"mp_delta_quantization": 0.5,
		"mp_ratio_quantization": 10,
	})
	if params.mp_change_mode != &"mp_differential" or params.mp_encoding != MemoryParams.MP_ENCODING_DIFFERENTIAL:
		push_error("cache must parse mp_change_mode into the differential encoding")
		return 1
	if not is_equal_approx(params.mp_delta_quantization, 0.5) or not is_equal_approx(params.mp_ratio_quantization, 10.0):
		push_error("cache must parse quantization values as floats")
		return 1
	if params.get("mp_encoding") != MemoryParams.MP_ENCODING_DIFFERENTIAL:
		push_error("mp_encoding must be readable via get() for multi-area refresh")
		return 1
	return 0


func _test_cache_defaults_before_feagi_reports() -> int:
	var params = MemoryParams.new(null)
	if params.mp_encoding != MemoryParams.MP_ENCODING_NONE:
		push_error("default encoding must be None")
		return 1
	if not is_equal_approx(params.mp_delta_quantization, MemoryParams.DEFAULT_MP_DELTA_QUANTIZATION):
		push_error("default delta quantization mismatch")
		return 1
	if not is_equal_approx(params.mp_ratio_quantization, MemoryParams.DEFAULT_MP_RATIO_QUANTIZATION):
		push_error("default ratio quantization mismatch")
		return 1
	return 0


func _test_scenes_replace_toggle_with_dropdown(scene_path: String) -> int:
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		push_error("could not read %s" % scene_path)
		return 1
	for node_name in ["mp_encoding", "mp_delta_quantization", "mp_ratio_quantization"]:
		if not text.contains('[node name="%s"' % node_name):
			push_error("%s missing node %s" % [scene_path, node_name])
			return 1
	if text.contains('[node name="mp_learning_enabled"'):
		push_error("%s still has the MP Learning toggle; the dropdown replaces it" % scene_path)
		return 1
	var packed: PackedScene = load(scene_path)
	if packed == null or not packed.can_instantiate():
		push_error("%s failed to load" % scene_path)
		return 1
	return 0
