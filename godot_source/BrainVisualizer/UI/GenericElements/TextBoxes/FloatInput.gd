extends AbstractLineInput
class_name FloatInput
## Text Box that use can input floats into

# useful properties inherited
# editable

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal float_confirmed(new_float: float)

## The float to start with
@export var initial_float: float = 0
@export var max_value: float = 9999999999.0
@export var min_value: float = -9999999999.0
@export var number_decimal_places: int = 2

var current_float: float:
	get: return previous_text.to_float()
	set(v):
		set_value_from_text(str(v))

func _ready():
	super()
	set_value_from_text(str(initial_float))

func set_float(val: float) -> void: # used for signals
	current_float = val

## OVERRIDDEN: Formats the input to something acceptable for the use, or returns an empty string if this isn't possible
func _set_input_text_valid(input_text: String) -> String:
	if input_text.is_valid_float():
		var full_float: float = input_text.to_float()
		full_float = clampf(full_float, min_value, max_value)
		return str(full_float).pad_decimals(number_decimal_places)
	return ""

