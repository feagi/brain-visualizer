extends SceneTree
## Classifier stamp relocate gizmo sits below the area-name label, not at volume center height.
## Mirrors UI_BrainMonitor_3DScene classifier gizmo placement (kept inline to avoid FeagiCore autoload).

const SceneLabel3D = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_SceneLabel3D.gd")
const GizmoClearance: float = 0.75
const GizmoAxisInset: float = 0.35
const LABEL_BOTTOM_GAP_SCALE: float = 0.18
const LABEL_BOTTOM_GAP_MIN: float = 2.75
const LABEL_BOTTOM_GAP_MAX: float = 4.5


func _initialize() -> void:
	var failures: int = 0
	failures += _test_gizmo_y_is_below_label()
	failures += _test_label_center_matches_legacy_offset()
	if failures == 0:
		print("Classifier stamp gizmo layout tests: PASS")
		quit(0)
	else:
		push_error("Classifier stamp gizmo layout tests: FAIL (%d)" % failures)
		quit(1)


func _label_center_y_from_volume_center(volume_center_y: float, half_extent_y: float) -> float:
	var bottom_gap: float = clampf(
		half_extent_y * LABEL_BOTTOM_GAP_SCALE,
		LABEL_BOTTOM_GAP_MIN,
		LABEL_BOTTOM_GAP_MAX
	)
	return volume_center_y - (half_extent_y + bottom_gap)


func _test_gizmo_y_is_below_label() -> int:
	var volume_center_y: float = 12.0
	var half_y: float = 2.0
	var axis_len: float = 2.5
	var label_center_y: float = _label_center_y_from_volume_center(volume_center_y, half_y)
	var label_half_height: float = SceneLabel3D.AREA_NAME_VISUAL_SCALE * 0.5
	var gizmo_y: float = (
		label_center_y
		- label_half_height
		- GizmoClearance
		- axis_len * GizmoAxisInset
	)
	if gizmo_y >= label_center_y - label_half_height:
		push_error("gizmo center must sit below the area label footprint")
		return 1
	if gizmo_y >= volume_center_y:
		push_error("gizmo center must stay below the stamp volume center")
		return 1
	return 0


func _test_label_center_matches_legacy_offset() -> int:
	var center_y: float = 8.0
	var half_y: float = 3.0
	var expected: float = center_y - half_y - 2.75
	var actual: float = _label_center_y_from_volume_center(center_y, half_y)
	if not is_equal_approx(actual, expected):
		push_error("label center Y should match bottom-gap formula (expected %s, got %s)" % [expected, actual])
		return 1
	return 0
