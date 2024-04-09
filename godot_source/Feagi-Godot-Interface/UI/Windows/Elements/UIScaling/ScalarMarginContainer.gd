extends MarginContainer
class_name ScalarMarginContainer

var _top: int
var _bottom: int
var _left: int
var _right: int

func _ready() -> void:
	_top = get_theme_constant(&"margin_top")
	_bottom = get_theme_constant(&"margin_bottom")
	_left = get_theme_constant(&"margin_left")
	_right = get_theme_constant(&"margin_right")


func _update_size(multiplier: float) -> void:
	add_theme_constant_override(&"margin_top", int(float(_top) * multiplier))
	add_theme_constant_override(&"margin_bottom", int(float(_bottom) * multiplier))
	add_theme_constant_override(&"margin_left", int(float(_left) * multiplier))
	add_theme_constant_override(&"margin_right", int(float(_right) * multiplier))
	size = Vector2(0,0)
