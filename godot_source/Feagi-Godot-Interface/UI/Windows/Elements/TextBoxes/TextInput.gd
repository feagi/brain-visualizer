extends LineEdit
class_name TextInput
## Text box that user can input Strings into

# useful properties inherited
# text (NOTE - changing this via code does not cause signal up!)
# editable
# max_length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal text_confirmed(new_text: String)

## If signaling up via 'text_confirmed' should be enabled. Does nothing after '_ready'
@export var enable_signaling_on_ready: bool = true
var _previous_text: String

func _ready():
	text = _previous_text
	toggle_signaling_up(enable_signaling_on_ready)

## Toggles signaling if the internal value changed, similar to setting 'editable' but without UI changes
func toggle_signaling_up(enable: bool) -> void:
	if enable:
		if is_connected("focus_exited", _emit_if_text_changed): return # do not connect twice!
		focus_exited.connect(_emit_if_text_changed)
		return
	if !is_connected("focus_exited", _emit_if_text_changed): return # do not disconnect twice!
	focus_exited.disconnect(_emit_if_text_changed)
	return
	
func _emit_if_text_changed() -> void:
	if text == _previous_text:
		return
	_previous_text = text
	text_confirmed.emit(text)
