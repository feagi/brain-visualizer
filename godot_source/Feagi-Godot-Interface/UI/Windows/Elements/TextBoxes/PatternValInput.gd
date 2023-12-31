extends LineEdit
class_name PatternValInput
## Text Box that use can input [PatternVal] into

# useful properties inherited
# editable
# max_length
# TODO: Bounds - limit number length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal patternval_confirmed(new_patternval: PatternVal)
signal user_interacted()

## If signaling up via 'text_confirmed' should be enabled. Does nothing after '_ready'
@export var enable_signaling_on_ready: bool = true
@export var emit_when_enter_pressed: bool = true
## The float to start with
## due to godot limitations, can only use int here
@export var initial_value: int = 0
## what to add before the float
@export var prefix: String = ""
## what to add after the float
@export var suffix: String = ""

var current_patternval: PatternVal:
	get: return _previous_patternval.duplicate()
	set(v):
		external_update_float(v)

var _previous_patternval: PatternVal

func _ready():
	_previous_patternval = PatternVal.new(initial_value)
	_set_visible_text(_previous_patternval.as_StringName)
	toggle_signaling_up(enable_signaling_on_ready)
	focus_entered.connect(_on_focus)
	if emit_when_enter_pressed:
		text_submitted.connect(_enter_proxy)

## Used to update the float value externally programatically (IE not from the user)
func external_update_float(new_patternval: PatternVal) -> void:
	_previous_patternval = new_patternval
	_set_visible_text(new_patternval.as_StringName)

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
	text = _previous_patternval.as_StringName

func _emit_if_text_changed() -> void:
	if PatternVal.can_be_PatternVal(text):
		_set_visible_text(text)
		_previous_patternval = PatternVal.new(text)
		patternval_confirmed.emit(_previous_patternval.duplicate()) 
		return
	_set_visible_text(_previous_patternval.as_StringName)
	release_focus()

func _set_visible_text(new_patternval_str: StringName) -> void:
	text = prefix + new_patternval_str + suffix

func _enter_proxy(_text: String) -> void:
	_emit_if_text_changed()

func _on_interaction(_irrelevant_text: String) -> void:
	user_interacted.emit()
