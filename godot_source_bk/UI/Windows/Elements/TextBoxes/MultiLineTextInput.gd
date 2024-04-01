extends TextEdit
class_name MultiLineTextInput
## Text box that user can input Strings into

# useful properties inherited
# text (NOTE - changing this via code does not cause signal up!)
# editable
# max_length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal text_confirmed(new_text: String)
signal user_interacted()

## If signaling up via 'text_confirmed' should be enabled. Does nothing after '_ready'
@export var enable_signaling_on_ready: bool = true

var _previous_text: String
var _default_font_size: int
var _default_min_size: Vector2

func _ready():
	_previous_text = text
	toggle_signaling_up(enable_signaling_on_ready)
	text_changed.connect(_on_interaction)
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)
	

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

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)

func _on_interaction(_irrelevant_text: String) -> void:
	user_interacted.emit()
