extends TextureRect
class_name Texture_Element

@export var scale_multiplier: float = 1.0

func _ready():
	VisConfig.UI_settings_changed.connect(_update_size)
	_update_size()

func _update_size() -> void:
	custom_minimum_size = VisConfig.minimum_button_size_pixel * scale_multiplier
