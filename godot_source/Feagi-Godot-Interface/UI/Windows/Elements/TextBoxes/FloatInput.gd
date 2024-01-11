extends LineEdit
class_name FloatInput
## Text Box that use can input floats into

# useful properties inherited
# editable

const ACCEPTABLE_CHARACTERS_WHILE_TYPING: PackedStringArray = ["", "-"]

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal float_confirmed(new_float: float)
signal float_changed(new_float: float)
signal user_interacted()

@export var confirm_when_focus_lost: bool = true

## The float to start with
@export var initial_float: float = 0
## what to add before the float
@export var prefix: String = ""
## what to add after the float
@export var suffix: String = ""
@export var max_value: float = 9999999999.0
@export var min_value: float = -9999999999.0

var current_float: float:
	get: return _previous_float
	set(v):
		_previous_float = v
		if has_focus():
			text = str(v)
		else:
			_set_value_UI(v)

var _previous_float: float
var _prefix_length: int
var _suffix_length: int

func _ready():
	_previous_float = initial_float
	_prefix_length = len(prefix)
	_suffix_length = len(suffix)
	_set_value_UI(_previous_float)
	focus_entered.connect(_focus_entered)
	focus_exited.connect(_focus_lost)
	text_changed .connect(_user_attempt_change_value)
	text_submitted.connect(_user_attempt_confirm_value)

func _focus_entered() -> void:
	text = str(_previous_float)

func _focus_lost() -> void:
	_set_value_UI(_previous_float)
	if confirm_when_focus_lost:
		_user_attempt_confirm_value(text)

func _user_attempt_change_value(input_text: String) -> void:
	if input_text in ACCEPTABLE_CHARACTERS_WHILE_TYPING:
		return
	if !input_text.is_valid_float():
		_set_value_UI(_previous_float)
		return
	_previous_float = input_text.to_float()
	float_changed.emit(_previous_float)
	user_interacted.emit()

func _user_attempt_confirm_value(input_text: String) -> void:
	if !input_text.is_valid_float():
		_set_value_UI(_previous_float)
		return
	_previous_float = input_text.to_float()
	float_confirmed.emit(_previous_float)
	release_focus()
	

func _set_value_UI(new_float: float) -> void:
	text = prefix + str(clamp(new_float, min_value, max_value)) + suffix
