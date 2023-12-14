extends LineEdit
class_name IntInput
## Text Box that use can input ints into

# useful properties inherited
# editable

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal int_confirmed(new_int: int)
signal int_changed(new_int: int)
signal user_interacted()

@export var confirm_when_focus_lost: bool = true

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
		_previous_int = v
		if has_focus():
			text = str(v)
		else:
			_set_value_UI(v)

var _previous_int: int
var _prefix_length: int
var _suffix_length: int

func _ready():
	_previous_int = initial_int
	_prefix_length = len(prefix)
	_set_value_UI(_previous_int)
	focus_entered.connect(_focus_entered)
	focus_exited.connect(_focus_lost)
	text_changed .connect(_user_attempt_change_value)
	text_submitted.connect(_user_attempt_confirm_value)

func _focus_entered() -> void:
	text = str(_previous_int)

func _focus_lost() -> void:
	_set_value_UI(_previous_int)
	if confirm_when_focus_lost:
		_user_attempt_confirm_value(text)

func _user_attempt_change_value(input_text: String) -> void:
	if !input_text.is_valid_int():
		text = str(_previous_int)
		return
	_previous_int = input_text.to_int()
	int_changed.emit(_previous_int)
	user_interacted.emit()

func _user_attempt_confirm_value(input_text: String) -> void:
	if !input_text.is_valid_int():
		text = str(_previous_int)
		return
	_previous_int = input_text.to_int()
	int_confirmed.emit(_previous_int)

func _set_value_UI(new_int: int) -> void:
	text = prefix + str(clampi(new_int, min_value, max_value)) + suffix
