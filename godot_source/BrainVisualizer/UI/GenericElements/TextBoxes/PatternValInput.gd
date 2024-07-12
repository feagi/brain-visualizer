extends AbstractLineInput
class_name PatternValInput
## Text Box that use can input [PatternVal] into

# useful properties inherited
# editable
# max_length
# TODO: Bounds - limit number length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal patternval_confirmed(new_patternval: PatternVal)

## due to godot limitations, can only use int here
@export var intial_patternval: int

var current_patternval: PatternVal:
	get: return PatternVal.new(previous_text)
	set(v):
		set_value_from_text(v.as_StringName)



func _ready():
	super()
	set_value_from_text(str(intial_patternval))

func set_pattern_val(val: PatternVal) -> void:
	current_patternval = val

## OVERRIDDEN: Formats the input to something acceptable for the use, or returns an empty string if this isn't possible
func _set_input_text_valid(input_text: String) -> String:
	if PatternVal.can_be_PatternVal(input_text):
		return input_text
	return ""

func _proxy_emit_confirmed_value(value_as_string: String) -> void:
	patternval_confirmed.emit(PatternVal.new(value_as_string))
