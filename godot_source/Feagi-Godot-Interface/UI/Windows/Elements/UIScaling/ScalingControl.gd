extends Control
class_name ScalingControl
## Keeps the control to scale with its initial custom_minimum_size

var _default_custom_minimum_size: Vector2i

func _ready() -> void:
	_default_custom_minimum_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func _update_size(multiplier: float) -> void:
	custom_minimum_size = Vector2i(_default_custom_minimum_size * multiplier)
	size = Vector2(0,0)
	
