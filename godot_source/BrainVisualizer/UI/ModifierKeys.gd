extends RefCounted
class_name ModifierKeys
## Modifier state taken from the flags the OS puts on every input event.
## Polling Input.is_key_pressed goes stale when a key-up is swallowed (e.g. the macOS screenshot overlay);
## event flags are re-read from the OS on every event, so the next mouse move corrects the state.

static var _shift: bool = false
static var _ctrl: bool = false
static var _meta: bool = false
static var _alt: bool = false


## Call from one place that sees all window input. Does not consume the event.
static func update_from_event(event: InputEvent) -> void:
	var with_modifiers := event as InputEventWithModifiers
	if with_modifiers == null:
		return
	var before := [_shift, _ctrl, _meta, _alt]
	_shift = with_modifiers.shift_pressed
	_ctrl = with_modifiers.ctrl_pressed
	_meta = with_modifiers.meta_pressed
	_alt = with_modifiers.alt_pressed
	# A modifier key's own press/release does not carry its own flag; use the key's pressed state.
	var key := event as InputEventKey
	if key != null:
		match _modifier_keycode(key):
			KEY_SHIFT:
				_shift = key.pressed
			KEY_CTRL:
				_ctrl = key.pressed
			KEY_META:
				_meta = key.pressed
			KEY_ALT:
				_alt = key.pressed
	if before != [_shift, _ctrl, _meta, _alt]:
		print("[MODKEYS] shift=%s ctrl=%s meta=%s alt=%s via=%s" % [_shift, _ctrl, _meta, _alt, _describe(event)])


static func _modifier_keycode(key: InputEventKey) -> Key:
	var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	return code


static func _describe(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		return "%s %s" % [OS.get_keycode_string(_modifier_keycode(key)), "down" if key.pressed else "up"]
	return event.get_class()


static func shift_held() -> bool:
	return _shift


static func ctrl_held() -> bool:
	return _ctrl


static func meta_held() -> bool:
	return _meta


static func alt_held() -> bool:
	return _alt


## Ctrl or Cmd (platform "command" modifier for multi-select style shortcuts).
static func ctrl_or_meta_held() -> bool:
	return _ctrl or _meta


## For configurable keys: modifier keys use the event-derived state, any other key falls back to polling.
static func is_key_held(keycode: Key) -> bool:
	match keycode:
		KEY_SHIFT:
			return _shift
		KEY_CTRL:
			return _ctrl
		KEY_META:
			return _meta
		KEY_ALT:
			return _alt
	return Input.is_physical_key_pressed(keycode) or Input.is_key_pressed(keycode)


## Test helper.
static func reset() -> void:
	_shift = false
	_ctrl = false
	_meta = false
	_alt = false
