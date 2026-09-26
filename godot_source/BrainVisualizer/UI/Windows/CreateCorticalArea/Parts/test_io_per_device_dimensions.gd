extends SceneTree
## Unit tests for per-device dimension bounds used when adding an I/O area.

const Dimensions = preload("res://BrainVisualizer/UI/Windows/CreateCorticalArea/Parts/IoPerDeviceDimensions.gd")
## Run: godot --headless --path godot_source --script res://BrainVisualizer/UI/Windows/CreateCorticalArea/Parts/test_io_per_device_dimensions.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_simple_vision_allows_width_and_height()
	failures += _test_misc_volume_allows_width_height_and_depth()
	failures += _test_servo_allows_only_depth()
	failures += _test_fixed_axis_stays_locked()
	failures += _test_device_count_repeats_width()
	failures += _test_neuron_count_sums_subunits()
	failures += _test_api_payload_uses_subunit_index_strings()
	failures += _test_missing_bounds_are_rejected()
	failures += _test_default_outside_range_is_rejected()
	if failures == 0:
		print("IoPerDeviceDimensions tests: PASS")
		quit(0)
	else:
		push_error("IoPerDeviceDimensions tests: FAIL (%d)" % failures)
		quit(1)


func _test_simple_vision_allows_width_and_height() -> int:
	var bounds: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [128, 128, 3],
		"channel_dimensions_min": [1, 1, 1],
		"channel_dimensions_max": [4096, 4096, 3],
	})
	if not bounds["ok"]:
		push_error("simple vision bounds should parse")
		return 1
	var minimum: Vector3i = bounds["minimum"]
	var maximum: Vector3i = bounds["maximum"]
	if not Dimensions.axis_is_adjustable(minimum.x, maximum.x):
		push_error("simple vision width should be adjustable")
		return 1
	if not Dimensions.axis_is_adjustable(minimum.y, maximum.y):
		push_error("simple vision height should be adjustable")
		return 1
	if bounds["initial"] != Vector3i(128, 128, 3):
		push_error("simple vision should start at the template default")
		return 1
	return 0


func _test_misc_volume_allows_width_height_and_depth() -> int:
	var bounds: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [64.0, 64.0, 64.0],
		"channel_dimensions_min": [1, 1, 1],
		"channel_dimensions_max": [4096, 4096, 1024],
	})
	if not bounds["ok"]:
		push_error("misc volume bounds should accept JSON floats")
		return 1
	var minimum: Vector3i = bounds["minimum"]
	var maximum: Vector3i = bounds["maximum"]
	if not Dimensions.axis_is_adjustable(minimum.x, maximum.x):
		push_error("misc width should be adjustable")
		return 1
	if not Dimensions.axis_is_adjustable(minimum.y, maximum.y):
		push_error("misc height should be adjustable")
		return 1
	if not Dimensions.axis_is_adjustable(minimum.z, maximum.z):
		push_error("misc depth should be adjustable")
		return 1
	return 0


func _test_servo_allows_only_depth() -> int:
	var bounds: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [1, 1, 20],
		"channel_dimensions_min": [1, 1, 1],
		"channel_dimensions_max": [1, 1, 1024],
	})
	if not bounds["ok"]:
		push_error("servo bounds should parse")
		return 1
	var minimum: Vector3i = bounds["minimum"]
	var maximum: Vector3i = bounds["maximum"]
	if Dimensions.axis_is_adjustable(minimum.x, maximum.x):
		push_error("servo width should be fixed")
		return 1
	if Dimensions.axis_is_adjustable(minimum.y, maximum.y):
		push_error("servo height should be fixed")
		return 1
	if not Dimensions.axis_is_adjustable(minimum.z, maximum.z):
		push_error("servo depth should be adjustable")
		return 1
	return 0


func _test_fixed_axis_stays_locked() -> int:
	if Dimensions.axis_is_adjustable(1, 1):
		push_error("equal min and max should lock the axis")
		return 1
	if Dimensions.axis_is_adjustable(3, 1):
		push_error("inverted range should not be treated as adjustable")
		return 1
	return 0


func _test_device_count_repeats_width() -> int:
	var total: Vector3i = Dimensions.total_dimensions(Vector3i(1, 1, 20), 6)
	if total != Vector3i(6, 1, 20):
		push_error("device count should repeat width and leave depth as the decoding resolution, got %s" % total)
		return 1
	return 0


func _test_neuron_count_sums_subunits() -> int:
	var per_device_by_subunit: Dictionary = {
		0: Vector3i(128, 128, 3),
		1: Vector3i(32, 32, 1),
	}
	var count: int = Dimensions.neuron_count(per_device_by_subunit, 1, 1)
	var expected: int = 128 * 128 * 3 + 32 * 32 * 1
	if count != expected:
		push_error("neuron count expected %d, got %d" % [expected, count])
		return 1
	return 0


func _test_api_payload_uses_subunit_index_strings() -> int:
	var payload: Dictionary = Dimensions.to_api_payload({
		1: Vector3i(2, 1, 20),
		0: Vector3i(1, 1, 20),
	})
	if payload.keys() != ["0", "1"]:
		push_error("payload keys should be sorted subunit index strings, got %s" % str(payload.keys()))
		return 1
	if payload["0"] != [1, 1, 20] or payload["1"] != [2, 1, 20]:
		push_error("payload volumes mismatch: %s" % str(payload))
		return 1
	return 0


func _test_missing_bounds_are_rejected() -> int:
	var bounds: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [8, 8, 1],
	})
	if bounds["ok"]:
		push_error("missing min/max should be rejected")
		return 1
	return 0


func _test_default_outside_range_is_rejected() -> int:
	var outside: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [8, 8, 8],
		"channel_dimensions_min": [1, 1, 1],
		"channel_dimensions_max": [4, 4, 4],
	})
	if outside["ok"]:
		push_error("default outside min/max should be rejected")
		return 1
	var non_positive: Dictionary = Dimensions.bounds_from_subunit({
		"channel_dimensions_default": [1, 1, 0],
		"channel_dimensions_min": [1, 1, 1],
		"channel_dimensions_max": [1, 1, 10],
	})
	if non_positive["ok"]:
		push_error("non-positive default should be rejected")
		return 1
	return 0
