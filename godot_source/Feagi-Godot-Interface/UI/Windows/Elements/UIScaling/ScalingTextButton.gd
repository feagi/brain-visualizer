extends Control
class_name ScalingTextButton
## Keeps the Button to scale with its initial custom_minimum_size

var _default_font_size: int
var _default_min_size: Vector2

func _ready() -> void:
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
	
