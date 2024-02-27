extends Label
class_name ScalingLabel

var _default_font_size: int

func _ready() -> void:
	_default_font_size = get_theme_font_size(&"font_size")
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	size = Vector2(0,0)
	
