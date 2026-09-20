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
## True while applying prefix/suffix or programmatic text so cache refresh does not mark Apply dirty.
var _suppress_user_interacted: bool = false

func _ready():
	previous_text = text
	focus_entered.connect(_on_focus_enter)
	text_submitted.connect(_on_exiting_typing_mode)
	text_changed.connect(_on_text_changed_maybe_user)
	if confirm_when_focus_lost:
		focus_exited.connect(_on_exiting_typing_mode)


## Apply-button dirty signal: user typing only. Programmatic writes set [_suppress_user_interacted].
func _on_text_changed_maybe_user(_irrelevant: String) -> void:
	if _suppress_user_interacted:
		return
	user_interacted.emit()
	

func set_text_as_invalid() -> void:
	previous_text = string_representing_invalid
	_suppress_user_interacted = true
	text = string_representing_invalid
	_suppress_user_interacted = false

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
	var body: String = text
	if suffix != "" and body.ends_with(suffix):
		body = body.substr(0, body.length() - suffix.length())
	if prefix != "" and body.begins_with(prefix):
		body = body.substr(prefix.length())
	return body

func _enter_typing_mode() -> void:
	_suppress_user_interacted = true
	text = _get_current_text()
	_suppress_user_interacted = false

func _accept_text_change(new_text: String) -> void:
	previous_text = new_text
	_suppress_user_interacted = true
	text = prefix + new_text + suffix
	_suppress_user_interacted = false

func _reject_text_change(replacing_text: String = previous_text) -> void:
	_suppress_user_interacted = true
	text = prefix + replacing_text + suffix
	_suppress_user_interacted = false

func _on_focus_enter() -> void:
	_enter_typing_mode()

func _on_exiting_typing_mode(_irrelevant = null) -> void:
	var user_text: String = _set_input_text_valid(_get_current_text())
	if user_text != "":
		_accept_text_change(user_text)
		user_update_accepted.emit()
		_proxy_emit_confirmed_value(user_text)
	else:
		_reject_text_change()
	
