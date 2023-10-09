extends MarginContainer
class_name BooleanIndicator

@export var initial_left_top_right_bottom: Vector4i = Vector4i(3,1,3,1)
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
	set_left_top_right_center(initial_left_top_right_bottom)
	boolean_state = initial_state
	
func set_left_top_right_center(left_top_right_bottom: Vector4i) -> void:
	add_theme_constant_override("margin_top", left_top_right_bottom.y)
	add_theme_constant_override("margin_left", left_top_right_bottom.x)
	add_theme_constant_override("margin_bottom", left_top_right_bottom.w)
	add_theme_constant_override("margin_right", left_top_right_bottom.z)
