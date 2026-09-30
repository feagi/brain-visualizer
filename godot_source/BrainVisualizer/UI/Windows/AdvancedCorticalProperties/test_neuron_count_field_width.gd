extends SceneTree
## Neuron-count field width for cortical area details.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/test_neuron_count_field_width.gd

const Layout = preload("res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/CorticalCountFieldLayout.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_short_count_stays_at_floor()
	failures += _test_memory_readout_uses_wider_floor()
	failures += _test_measured_text_can_exceed_memory_floor()
	failures += _test_memory_suffix_selects_wider_floor()
	if failures == 0:
		print("Neuron count field width tests: PASS")
		quit(0)
	else:
		push_error("Neuron count field width tests: FAIL (%d)" % failures)
		quit(1)


func _test_short_count_stays_at_floor() -> int:
	var width: float = Layout.count_field_width_px(40.0, 8.0, Layout.MIN_COUNT_FIELD_WIDTH_PX)
	if width != Layout.MIN_COUNT_FIELD_WIDTH_PX:
		push_error("short count must stay at the standard field width, got %s" % width)
		return 1
	return 0


func _test_memory_readout_uses_wider_floor() -> int:
	if Layout.MEMORY_COUNT_FIELD_WIDTH_PX <= Layout.MIN_COUNT_FIELD_WIDTH_PX:
		push_error("memory neuron readout floor must be wider than the standard count field")
		return 1
	var width: float = Layout.count_field_width_px(80.0, 8.0, Layout.MEMORY_COUNT_FIELD_WIDTH_PX)
	if width != Layout.MEMORY_COUNT_FIELD_WIDTH_PX:
		push_error("memory readout must use the wider floor when text is still narrower, got %s" % width)
		return 1
	return 0


func _test_measured_text_can_exceed_memory_floor() -> int:
	var width: float = Layout.count_field_width_px(500.0, 20.0, Layout.MEMORY_COUNT_FIELD_WIDTH_PX)
	var expected: float = ceil(500.0 + 20.0 + Layout.COUNT_FIELD_TEXT_PADDING_PX)
	if width != expected:
		push_error("wide memory text must expand past the floor, got %s expected %s" % [width, expected])
		return 1
	return 0


func _test_memory_suffix_selects_wider_floor() -> int:
	var memory_floor: float = Layout.floor_width_for_display("1.5K (ST: 1K | LT: 500)")
	var plain_floor: float = Layout.floor_width_for_display("1.5K")
	if memory_floor != Layout.MEMORY_COUNT_FIELD_WIDTH_PX:
		push_error("memory suffix must select the wider floor, got %s" % memory_floor)
		return 1
	if plain_floor != Layout.MIN_COUNT_FIELD_WIDTH_PX:
		push_error("plain neuron count must keep the standard floor, got %s" % plain_floor)
		return 1
	return 0
