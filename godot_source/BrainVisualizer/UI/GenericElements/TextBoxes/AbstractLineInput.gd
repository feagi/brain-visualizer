extends LineEdit
class_name AbstractLineInput
## Base Abstract class for other specific types of user inputs (floats, ints, etc)

signal user_update_accepted() ## text update form user accepted
signal user_interacted()

@export var prefix: String = "" ## What to add before the value
@export var suffix: String = "" ## What to add after the value
@export var string_representing_invalid: String = "*"
@export var confirm_when_focus_lost: bool = true ## If thew user clicks off the line edit, should we take that as an enter attempt?

var previous_text: String

func _ready():
	previous_text = text
	focus_entered.connect(_on_focus_enter)
	text_submitted.connect(_on_exiting_typing_mode)
	text_changed.connect(func(_irrelevant) : user_interacted.emit())
	if confirm_when_focus_lost:
		focus_exited.connect(_on_exiting_typing_mode)
	

func set_text_as_invalid() -> void:
	previous_text = string_representing_invalid
	text = string_representing_invalid

func set_value_from_text(input: String) -> void:
	_accept_text_change(_set_input_text_valid(input))

## Formats the input to something acceptable for the use, or returns an empty string if this isn't possible
func _set_input_text_valid(_input_text: String) -> String:
	# OVERRIDE with specific function here
	return ""

func _proxy_emit_confirmed_value(value_as_string: String) -> void:
	# OVERRIDE with specific signal to emit here
	pass

func _get_current_text() -> String:
	var left_text: String = text.left(len(text) - len(suffix))
	return left_text.right(len(text) - len(prefix))

func _enter_typing_mode() -> void:
	text = _get_current_text()

func _accept_text_change(new_text: String) -> void:
	previous_text = new_text
	text = prefix + new_text + suffix

func _reject_text_change(replacing_text: String = previous_text) -> void:
	text = prefix + replacing_text + suffix

func _on_focus_enter() -> void:
	_enter_typing_mode()

func _on_exiting_typing_mode(_irrelevant = null) -> void:
	var user_text: String = _set_input_text_valid(text)
	if user_text != "":
		_accept_text_change(user_text)
		user_update_accepted.emit()
		_proxy_emit_confirmed_value(user_text)
	else:
		_reject_text_change()
	
