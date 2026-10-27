extends SceneTree
## Run: godot --headless --path godot_source --script res://BrainVisualizer/UI/test_modifier_keys.gd

const ModifierKeysScript = preload("res://BrainVisualizer/UI/ModifierKeys.gd")

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	ModifierKeysScript.reset()
	var move := InputEventMouseMotion.new()
	move.shift_pressed = true
	move.ctrl_pressed = true
	ModifierKeysScript.update_from_event(move)
	_check(ModifierKeysScript.shift_held(), "shift on")
	_check(ModifierKeysScript.ctrl_held(), "ctrl on")
	_check(not ModifierKeysScript.meta_held(), "meta off")
	_check(ModifierKeysScript.ctrl_or_meta_held(), "ctrl_or_meta via ctrl")
	_check(ModifierKeysScript.is_key_held(KEY_SHIFT), "is_key_held shift")

	var move_off := InputEventMouseMotion.new()
	ModifierKeysScript.update_from_event(move_off)
	_check(not ModifierKeysScript.shift_held(), "shift follows off")
	_check(not ModifierKeysScript.ctrl_held(), "ctrl follows off")

	var click := InputEventMouseButton.new()
	click.meta_pressed = true
	click.alt_pressed = true
	ModifierKeysScript.update_from_event(click)
	_check(ModifierKeysScript.meta_held() and ModifierKeysScript.alt_held(), "button event sets meta/alt")

	ModifierKeysScript.update_from_event(InputEventAction.new())
	_check(ModifierKeysScript.meta_held(), "non-modifier event ignored")

	# A modifier key's own press carries no flag for itself.
	ModifierKeysScript.reset()
	var ctrl_down := InputEventKey.new()
	ctrl_down.keycode = KEY_CTRL
	ctrl_down.pressed = true
	ModifierKeysScript.update_from_event(ctrl_down)
	_check(ModifierKeysScript.ctrl_held(), "ctrl key down sets ctrl")
	var ctrl_up := InputEventKey.new()
	ctrl_up.keycode = KEY_CTRL
	ctrl_up.ctrl_pressed = true
	ctrl_up.pressed = false
	ModifierKeysScript.update_from_event(ctrl_up)
	_check(not ModifierKeysScript.ctrl_held(), "ctrl key up clears ctrl")
	var meta_down := InputEventKey.new()
	meta_down.physical_keycode = KEY_META
	meta_down.pressed = true
	ModifierKeysScript.update_from_event(meta_down)
	_check(ModifierKeysScript.meta_held() and not ModifierKeysScript.ctrl_held(), "cmd alone sets only meta")

	print("test_modifier_keys: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
