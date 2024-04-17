extends MarginContainer
class_name BooleanIndicator

@export var color_true: Color = Color.GREEN
@export var color_false: Color = Color.RED
@export var initial_state: bool = false


var boolean_state: bool:
	get: return _boolean_state
	set(v):
		_boolean_state = v
		if v:
			_color_rect.color = color_true
		else:
			_color_rect.color = color_false

var _boolean_state: bool
var _color_rect: ColorRect

func _ready() -> void:
	_color_rect = $ColorRect
	boolean_state = initial_state
	_theme_updated()
	BV.UI.theme_changed.connect(_theme_updated)
	
func _theme_updated(_new_theme: Theme = null) -> void:
	_color_rect.custom_minimum_size.x = BV.UI.get_minimum_size_from_loaded_theme("ColorRect_TopBarIndicator").x
