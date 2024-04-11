extends LineEdit
class_name PatternValInput
## Text Box that use can input [PatternVal] into

# useful properties inherited
# editable
# max_length
# TODO: Bounds - limit number length

const ACCEPTABLE_CHARACTERS_WHILE_TYPING: PackedStringArray = ["", "-"]

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal patternval_confirmed(new_patternval: PatternVal)
signal patternval_changed(new_patternval: PatternVal)
signal user_interacted()

@export var confirm_when_focus_lost: bool = true

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
		_previous_patternval = v
		if has_focus():
			text = v.as_StringName
		else:
			_set_value_UI(v)

var _previous_patternval: PatternVal
var _prefix_length: int
var _suffix_length: int
var _default_font_size: int

func _ready():
	
	_previous_patternval = PatternVal.new(initial_value)
	_prefix_length = len(prefix)
	_suffix_length = len(suffix)
	_set_value_UI(_previous_patternval)
	focus_entered.connect(_focus_entered)
	focus_exited.connect(_focus_lost)
	text_changed .connect(_user_attempt_change_value)
	text_submitted.connect(_user_attempt_change_value)
	_default_font_size = get_theme_font_size(&"font_size")

func _focus_entered() -> void:
	text = _previous_patternval.as_StringName

func _focus_lost() -> void:
	_set_value_UI(_previous_patternval)
	if confirm_when_focus_lost:
		_user_attempt_change_value(text)

func _user_attempt_change_value(input_text: String) -> void:
	if input_text in ACCEPTABLE_CHARACTERS_WHILE_TYPING:
		return
	if !PatternVal.can_be_PatternVal(input_text):
		text = _previous_patternval.as_StringName
		return
	_previous_patternval = PatternVal.new(input_text)
	patternval_changed.emit(_previous_patternval)
	user_interacted.emit()

func _set_value_UI(new_value: PatternVal) -> void:
	text = prefix + new_value.as_StringName + suffix

