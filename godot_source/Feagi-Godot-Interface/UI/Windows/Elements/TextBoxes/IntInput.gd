extends LineEdit
class_name IntInput
## Text Box that use can input ints into

# useful properties inherited
# editable

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal int_confirmed(new_int: int)

## If signaling up via 'text_confirmed' should be enabled. Does nothing after '_ready'
@export var enable_signaling_on_ready: bool = true
@export var emit_when_enter_pressed: bool = true
## The integer to start with
@export var initial_int: int = 0
## what to add before the int
@export var prefix: String = ""
## what to add after the int
@export var suffix: String = ""
@export var max_value: int = 9999999999
@export var min_value: int = -9999999999

var current_int: int:
	get: return _previous_int
	set(v):
		external_update_int(v)

var _previous_int: int

func _ready():
	_previous_int = initial_int
	_set_visible_text(initial_int)
	toggle_signaling_up(enable_signaling_on_ready)
	focus_entered.connect(_on_focus)
	if emit_when_enter_pressed:
		text_submitted.connect(_enter_proxy)

## Used to update the float value externally programatically (IE not from the user)
func external_update_int(new_int: int) -> void:
	_previous_int = new_int
	_set_visible_text(new_int)

## Toggles signaling if the internal value changed, similar to setting 'editable' but without UI changes
func toggle_signaling_up(enable: bool) -> void:
	if enable:
		if is_connected("focus_exited", _emit_if_text_changed): return # do not connect twice!
		focus_exited.connect(_emit_if_text_changed)
		return
	if !is_connected("focus_exited", _emit_if_text_changed): return # do not disconnect twice!
	focus_exited.disconnect(_emit_if_text_changed)
	return

## used so user doesnt have to get rid of prefix and suffix when typing
func _on_focus():
	text = str(_previous_int)

func _emit_if_text_changed() -> void:
	if !text.is_valid_int():
		_set_visible_text(_previous_int)
		return
	if text.to_float() == _previous_int:
		return
	_previous_int = FEAGIUtils.bounds_int(text.to_int(), min_value, max_value)
	int_confirmed.emit(_previous_int)
	_set_visible_text(_previous_int)
	release_focus()

func _set_visible_text(new_int: int) -> void:
	text = prefix + str(new_int) + suffix

func _enter_proxy(_text: String) -> void:
	_emit_if_text_changed()
