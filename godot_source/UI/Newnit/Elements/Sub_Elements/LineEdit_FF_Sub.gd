extends LineEdit_Base_Sub
class_name LineEdit_ff_Sub


var value: float:
	get: return float(rootText)
	set(v): SetText( str(v), str(rootText))

# Function to filter inplausible text, override in child classes
func _FilterText(input: String, replacementIncorrect: String) -> String:
	if !input.is_valid_float(): return replacementIncorrect
	var val: float = float(input)
	val = HelperFuncs.clampToRange(val, min_value, max_value)
	return str(val)

# Function to emit values, override in child classes for different formats
func _EmitNewValue(output: String) -> void:
	value_edited.emit(output.to_float())

var min_value: float = -99999999.0
var max_value: float = 99999999.0

func _ready() -> void:
	super._ready()
	rootText = "0"


# built in vars
# text: String
# size: Vector2
# editable: bool
# expand_to_text_length: bool
# max_length: int
# text_changed: Signal
# text_submitted: Signal
# placeholder_text: String
