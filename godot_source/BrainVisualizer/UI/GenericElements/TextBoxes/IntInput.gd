extends AbstractLineInput
class_name IntInput
## Text Box that use can input ints into

# useful properties inherited
# editable

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal int_confirmed(new_int: int)

@export var initial_int: int = 0  ## The integer to start with
@export var max_value: int = 9999999999
@export var min_value: int = -9999999999

var current_int: int:
	get: return previous_text.to_int()
	set(v):
		set_value_from_text(str(v))



func _ready():
	super()
	set_value_from_text(str(initial_int))

func set_int(val: int) -> void: # used for signals
	current_int = val

## OVERRIDDEN: Formats the input to something acceptable for the use, or returns an empty string if this isn't possible
func _set_input_text_valid(input_text: String) -> String:
	if input_text.is_valid_int():
		var full_int: int = input_text.to_int()
		full_int = clamp(full_int, min_value, max_value)
		return str(full_int)
	return ""
