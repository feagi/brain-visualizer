extends SpinBox
class_name IntSpinBox


func _ready():
	
	_apply_theme(VisConfig.UI_manager.temp_spinbox_theme)
	VisConfig.UI_manager.UI_scale_changed_spinbox.connect(_apply_theme)

func _apply_theme(new_theme: Theme) -> void:
	set_theme(new_theme)
	size = Vector2(0,0)
