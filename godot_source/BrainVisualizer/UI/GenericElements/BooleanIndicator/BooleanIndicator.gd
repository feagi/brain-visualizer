extends MarginContainer
class_name BooleanIndicator

@export var initial_state: bool = false


var boolean_state: bool:
	get: return _boolean_state
	set(v):
		_boolean_state = v
		_color_rect.color = _get_color_from_theme(v)

var _boolean_state: bool
var _color_rect: ColorRect

func _ready() -> void:
	_color_rect = $ColorRect
	boolean_state = initial_state
	_theme_updated()
	BV.UI.theme_changed.connect(_theme_updated)
	
func _theme_updated(_new_theme: Theme = null) -> void:
	_color_rect.custom_minimum_size.x = BV.UI.get_minimum_size_from_loaded_theme("TopBarIndicator").x
	_get_color_from_theme(boolean_state)

func _get_color_from_theme(state: bool) -> Color:
	var theme_variant: StringName = _color_rect.theme_type_variation
	var theme: Theme = BV.UI.loaded_theme
	var property: StringName
	if state:
		property = "on"
	else:
		property = "off"
	if theme.has_color(property, "TopBarIndicator"):
		return theme.get_color(property, "TopBarIndicator")
	push_error("UI: Unable to find color for indicator!")
	return Color.BLACK
