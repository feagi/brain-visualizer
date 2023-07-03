extends LineEdit
class_name  LineEdit_Base
# Base script for all LineEdit based subcomponents, do not create directly

const MAX_CHARACTERS_SHOWN = 8
const LIMIT_MAX_CHARACTERS_LENGTH = false

signal value_edited(newString: String)

var minWidth: float:
	get: return get_theme_font("font").get_string_size(text).x

var prefix: String = ""
var suffix: String = ""
var rootText: String = ""

# Sets the text property of the line edit after proper filters
func SetText(input: String, backup: String) -> void:
	rootText = _FilterText(input, backup)
	text = prefix + rootText + suffix


# Function to filter inplausible text, override in child classes
func _FilterText(input: String, _replacementIncorrect: String) -> String:
	return input

# TODO this camera focusing system is flawed, and should be replaced
func _ready():
	mouse_entered.connect(_toggleCamUsageOn)
	mouse_exited.connect(_toggleCamUsageOff)

func _toggleCamUsageOn():
	Godot_list.Node_2D_control = true

func _toggleCamUsageOff():
	Godot_list.Node_2D_control = false
