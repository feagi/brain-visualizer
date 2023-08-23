extends TextureButton
class_name TextureButton_Element


func _ready():
	VisConfig.UI_settings_changed.connect(_update_size)

func _update_size() -> void:
	custom_minimum_size = VisConfig.minimum_button_size_pixel
