extends SceneTree
## Unit tests for ContinuousSelectedNeuronFiring Space / Shift+Space resolution.

const ContinuousSelectedNeuronFiringScript = preload("res://addons/UI_BrainMonitor/ContinuousSelectedNeuronFiring.gd")
const ClickEventScript = preload("res://addons/UI_BrainMonitor/InputEvents/UI_BrainMonitor_InputEvent_Click.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_space_without_shift_is_one_shot_when_idle()
	failures += _test_shift_space_starts_continuous_when_idle()
	failures += _test_space_stops_continuous_without_shift()
	failures += _test_shift_space_stops_continuous_when_already_running()
	failures += _test_positive_timestep_is_valid_interval()
	failures += _test_non_positive_timestep_is_invalid_interval()
	failures += _test_idle_start_stop_one_shot_session()
	failures += _test_fire_click_event_preserves_shift()
	if failures == 0:
		print("ContinuousSelectedNeuronFiring tests: PASS")
		quit(0)
	else:
		push_error("ContinuousSelectedNeuronFiring tests: FAIL (%d)" % failures)
		quit(1)


func _test_space_without_shift_is_one_shot_when_idle() -> int:
	var action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(false, false)
	if action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.ONE_SHOT:
		push_error("idle Space should one-shot fire selected voxels")
		return 1
	return 0


func _test_shift_space_starts_continuous_when_idle() -> int:
	var action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(true, false)
	if action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.START_CONTINUOUS:
		push_error("idle Shift+Space should start continuous voxel activation")
		return 1
	return 0


func _test_space_stops_continuous_without_shift() -> int:
	var action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(false, true)
	if action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.STOP_CONTINUOUS:
		push_error("Space during continuous activation should stop it")
		return 1
	return 0


func _test_shift_space_stops_continuous_when_already_running() -> int:
	var action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(true, true)
	if action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.STOP_CONTINUOUS:
		push_error("Shift+Space during continuous activation should stop it")
		return 1
	return 0


func _test_positive_timestep_is_valid_interval() -> int:
	if not ContinuousSelectedNeuronFiringScript.is_valid_interval_seconds(0.05):
		push_error("positive simulation_timestep must be a valid continuous-fire interval")
		return 1
	return 0


func _test_non_positive_timestep_is_invalid_interval() -> int:
	if ContinuousSelectedNeuronFiringScript.is_valid_interval_seconds(0.0):
		push_error("zero simulation_timestep must not be treated as a valid interval")
		return 1
	if ContinuousSelectedNeuronFiringScript.is_valid_interval_seconds(-1.0):
		push_error("negative simulation_timestep must not be treated as a valid interval")
		return 1
	return 0


func _test_idle_start_stop_one_shot_session() -> int:
	var continuous_active: bool = false
	var start_action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(true, continuous_active)
	if start_action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.START_CONTINUOUS:
		push_error("session: Shift+Space should start continuous activation")
		return 1
	continuous_active = true
	var stop_action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(false, continuous_active)
	if stop_action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.STOP_CONTINUOUS:
		push_error("session: Space should stop continuous activation")
		return 1
	continuous_active = false
	var one_shot_action: int = ContinuousSelectedNeuronFiringScript.resolve_space_press(false, continuous_active)
	if one_shot_action != ContinuousSelectedNeuronFiringScript.SPACE_PRESS_ACTION.ONE_SHOT:
		push_error("session: Space after stop should one-shot fire")
		return 1
	return 0


func _test_fire_click_event_preserves_shift() -> int:
	var held: Array[ClickEventScript.CLICK_BUTTON] = []
	var fire_event: RefCounted = ClickEventScript.new(
		held,
		Vector3.ZERO,
		Vector3.ONE,
		true,
		false,
		ClickEventScript.CLICK_BUTTON.FIRE_SELECTED_NEURONS,
		false,
		false,
		true,
		false
	)
	if fire_event.button != ClickEventScript.CLICK_BUTTON.FIRE_SELECTED_NEURONS:
		push_error("fire click event button should be FIRE_SELECTED_NEURONS")
		return 1
	if fire_event.shift_pressed != true:
		push_error("fire click event must preserve shift_pressed from Shift+Space")
		return 1
	if fire_event.button_pressed != true:
		push_error("fire click event must be a keydown")
		return 1
	return 0
