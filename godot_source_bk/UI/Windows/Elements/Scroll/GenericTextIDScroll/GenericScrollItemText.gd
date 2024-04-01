extends Button
class_name GenericScrollItemText

signal selected(ID: Variant, child_index: int)

var ID: Variant

var _default: StyleBoxFlat
var _selected: StyleBoxFlat
var _min_height: int
var _default_font_size: int


func setup(set_ID: Variant, button_text: StringName, default_look: StyleBoxFlat, selected_look: StyleBoxFlat, min_height: int = 0) -> void:
	ID = set_ID
	text = button_text
	_default = default_look
	_selected = selected_look
	pressed.connect(user_selected)
	add_theme_stylebox_override("normal", _default)
	_default_font_size = get_theme_font_size(&"font_size")
	_min_height = min_height
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)
	

func user_selected():
	add_theme_stylebox_override("normal", _selected)
	selected.emit(ID, get_index())

func user_deselected():
	add_theme_stylebox_override("normal", _default)
	
func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_font_size != 0:
		custom_minimum_size.y = int(float(_default_font_size) * multiplier)
	size = Vector2(0,0)



