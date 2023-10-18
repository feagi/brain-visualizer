extends Button
class_name GenericScrollItemText

signal selected(ID: Variant, child_index: int)

var ID: Variant

var _default: StyleBoxFlat
var _selected: StyleBoxFlat


func setup(set_ID: Variant, button_text: StringName, default_look: StyleBoxFlat, selected_look: StyleBoxFlat) -> void:
	ID = set_ID
	text = button_text
	_default = default_look
	_selected = selected_look
	pressed.connect(user_selected)
	add_theme_stylebox_override("normal", _default)

func user_selected():
	add_theme_stylebox_override("normal", _selected)
	selected.emit(ID, get_index())

func user_deselected():
	add_theme_stylebox_override("normal", _default)



