extends SpinBox
class_name IntSpinBox

var _default_min_size: Vector2

func _ready():
	
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_apply_theme(VisConfig.UI_manager.temp_spinbox_theme)
	VisConfig.UI_manager.UI_scale_changed_spinbox.connect(_apply_theme)

func _apply_theme(new_theme: Theme) -> void:
	set_theme(new_theme)
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * VisConfig.UI_manager.UI_scale
	size = Vector2(0,0)
