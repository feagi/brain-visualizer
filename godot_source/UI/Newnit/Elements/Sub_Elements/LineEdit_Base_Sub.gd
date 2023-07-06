extends LineEdit
class_name  LineEdit_Base_Sub
# Base script for all LineEdit based subcomponents, do not create directly

const MAX_CHARACTERS_SHOWN = 8
const LIMIT_MAX_CHARACTERS_LENGTH = false
const HORIZONTAL_ALIGNMENT = 1

signal value_edited(newString: String)

var minWidth: float:
	get: return get_theme_font("font").get_string_size(text).x

var prefix: String = ""
var suffix: String = ""
var rootText: String = ""
var _cachedRootText: String = ""

# Sets the text property of the line edit after proper filters
func SetText(input: String, backup: String) -> void:
	rootText = _FilterText(input, backup)
	_emitValChangedIfChanged(rootText)
	text = prefix + rootText + suffix

func _emitValChangedIfChanged(newRootText: String = rootText) -> void:
	release_focus()
	if _cachedRootText == newRootText: return
	_cachedRootText = newRootText
	_EmitNewValue(newRootText)

func _UIUpdateText(newText: String = text) -> void:
	SetText(newText, rootText)

# Function to filter inplausible text, override in child classes
func _FilterText(input: String, _replacementIncorrect: String) -> String:
	return input

# Function to emit values, override in child classes for different formats
func _EmitNewValue(output: String) -> void:
	value_edited.emit(output)

# TODO this camera focusing system is flawed, and should be replaced
func _ready():
	alignment = HORIZONTAL_ALIGNMENT
	focus_exited.connect(_UIUpdateText)
	text_submitted.connect(_UIUpdateText)
	focus_entered.connect(_toggleCamUsageOn)
	focus_exited.connect(_toggleCamUsageOff)

func _toggleCamUsageOn():
	Godot_list.Node_2D_control = true

func _toggleCamUsageOff():
	Godot_list.Node_2D_control = false
