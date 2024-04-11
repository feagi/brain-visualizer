extends TextureButton
class_name ScalingTextureButton
## Keeps the [TextureButton] to scale with its initial custom_minimum_size

var _default_custom_minimum_size: Vector2i

func _ready() -> void:
	_default_custom_minimum_size = custom_minimum_size

func _update_size(multiplier: float) -> void:
	custom_minimum_size = Vector2i(_default_custom_minimum_size * multiplier)
	size = Vector2(0,0)
