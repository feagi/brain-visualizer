extends Button
class_name TextButton_Element

func _ready():
	VisConfig.UI_manager.UI_settings_changed.connect(_update_size)

func _update_size() -> void:
	custom_minimum_size = VisConfig.UI_manager.minimum_button_size_pixel
