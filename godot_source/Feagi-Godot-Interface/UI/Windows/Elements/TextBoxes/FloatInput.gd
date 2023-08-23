extends LineEdit
class_name FloatInput
## Text Box that use can input floats into

# useful properties inherited
# editable
# max_length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal float_confirmed(new_float: float)

## If signaling up via 'text_confirmed' should be enabled. Does nothing after '_ready'
@export var enable_signaling_on_ready: bool = true
## The float to start with
@export var initial_float: float = 0.0
## what to add before the float
@export var prefix: String = ""
## what to add after the float
@export var suffix: String = ""

var _previous_float: float

func _ready():
	_previous_float = initial_float
	_set_visible_text(initial_float)
	toggle_signaling_up(enable_signaling_on_ready)
	focus_entered.connect(_on_focus)

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
	text = str(_previous_float)

func _emit_if_text_changed() -> void:
	if !text.is_valid_float():
		_set_visible_text(_previous_float)
		return
	if text.to_float() == _previous_float:
		return
	_previous_float = text.to_float()
	float_confirmed.emit(_previous_float)
	_set_visible_text(_previous_float)

func _set_visible_text(new_float: float) -> void:
	text = prefix + str(new_float) + suffix