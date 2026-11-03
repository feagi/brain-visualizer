extends SceneTree
## Pure layout math for the modulator trigger row (ModulatorRowLayout.compute).

const Layout = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_ModulatorRowLayout.gd")
const STEP: int = 20
const FIRST_SLOT: int = 5  # slots from the power anchor to the first modulator


func _initialize() -> void:
	var failures: int = 0
	failures += _test_row_continues_core_row_from_power()
	failures += _test_no_power_anchors_at_first_modulator()
	failures += _test_order_is_by_id()
	if failures == 0:
		print("Modulator row layout tests: PASS")
		quit(0)
	else:
		push_error("Modulator row layout tests: FAIL (%d)" % failures)
		quit(1)


func _check(cond: bool, label: String) -> int:
	if not cond:
		push_error("FAIL: " + label)
		return 1
	return 0


func _test_row_continues_core_row_from_power() -> int:
	var step: int = STEP
	var power := Vector3i(10, 5, 2)
	var layout: Dictionary = Layout.compute({&"m_b": Vector3i.ZERO, &"m_a": Vector3i.ZERO, &"m_c": Vector3i.ZERO}, STEP, FIRST_SLOT, power)
	var first_x: int = power.x + FIRST_SLOT * step
	var f := 0
	f += _check(layout[&"m_a"] == Vector3i(first_x, 5, 2), "first modulator one slot past last core")
	f += _check(layout[&"m_b"] == Vector3i(first_x + step, 5, 2), "second modulator one step later")
	f += _check(layout[&"m_c"] == Vector3i(first_x + 2 * step, 5, 2), "third modulator two steps later")
	return f


func _test_no_power_anchors_at_first_modulator() -> int:
	var step: int = STEP
	var layout: Dictionary = Layout.compute({&"m_b": Vector3i(7, 8, 9), &"m_a": Vector3i(1, 2, 3)}, STEP, FIRST_SLOT)
	var f := 0
	f += _check(layout[&"m_a"] == Vector3i(1, 2, 3), "anchor keeps first modulator stored position")
	f += _check(layout[&"m_b"] == Vector3i(1 + step, 2, 3), "next modulator along X from anchor")
	f += _check(Layout.compute({}, STEP, FIRST_SLOT).is_empty(), "empty input gives empty layout")
	return f


func _test_order_is_by_id() -> int:
	var layout: Dictionary = Layout.compute({&"z": Vector3i.ZERO, &"a": Vector3i.ZERO, &"m": Vector3i.ZERO}, STEP, FIRST_SLOT)
	return _check(layout.keys() == [&"a", &"m", &"z"], "layout keys sorted by cortical ID")
